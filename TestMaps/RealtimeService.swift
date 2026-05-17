import Foundation
import Combine

// MARK: - Supabase Realtime WebSocket service
// Connects once after login, stays alive with heartbeats,
// and delivers INSERT/DELETE events to FeedViewModel.

final class RealtimeService: ObservableObject {

    // Callbacks wired up by FeedViewModel
    var onInsert: ((_ table: String, _ record: [String: Any]) -> Void)?
    var onDelete: ((_ table: String, _ record: [String: Any]) -> Void)?

    private var wsTask:         URLSessionWebSocketTask?
    private var heartbeatTimer: Timer?
    private var msgRef          = 0
    private var savedToken      = ""

    // MARK: - Public API

    func connect(token: String) {
        disconnect()
        savedToken = token

        let wsBase = SupabaseClient.baseURL.replacingOccurrences(of: "https://", with: "wss://")
        let urlStr = "\(wsBase)/realtime/v1/websocket"
                   + "?apikey=\(SupabaseClient.apiKey)&vsn=1.0.0"
        guard let url = URL(string: urlStr) else { return }

        wsTask = URLSession.shared.webSocketTask(with: url)
        wsTask?.resume()

        scheduleHeartbeat()
        receive()
        joinChannel(token: token)
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
    }

    // MARK: - Private

    private func joinChannel(token: String) {
        send([
            "topic": "realtime:db-changes",
            "event": "phx_join",
            "payload": [
                "config": [
                    "broadcast":        ["self": false],
                    "presence":         ["key": ""],
                    "postgres_changes": [
                        ["event": "INSERT", "schema": "public", "table": "posts"],
                        ["event": "INSERT", "schema": "public", "table": "reactions"],
                        ["event": "DELETE", "schema": "public", "table": "reactions"],
                        ["event": "INSERT", "schema": "public", "table": "post_joins"],
                        ["event": "DELETE", "schema": "public", "table": "post_joins"],
                        ["event": "INSERT", "schema": "public", "table": "comments"]
                    ]
                ],
                "access_token": token
            ],
            "ref": nextRef()
        ])
    }

    private func scheduleHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.send(["topic": "phoenix", "event": "heartbeat", "payload": [:], "ref": self?.nextRef() ?? "0"])
        }
    }

    private func send(_ msg: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: msg),
            let str  = String(data: data, encoding: .utf8)
        else { return }
        wsTask?.send(.string(str)) { _ in }
    }

    private func nextRef() -> String {
        msgRef += 1
        return "\(msgRef)"
    }

    // Recursive receive loop — keeps the connection alive
    private func receive() {
        wsTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let str) = message { self.handle(str) }
                self.receive()   // queue next receive immediately

            case .failure:
                // Auto-reconnect after 5 s
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self, !self.savedToken.isEmpty else { return }
                    self.connect(token: self.savedToken)
                }
            }
        }
    }

    private func handle(_ raw: String) {
        guard
            let data      = raw.data(using: .utf8),
            let json      = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let event     = json["event"] as? String,
            event         == "postgres_changes",
            let payload   = json["payload"] as? [String: Any],
            let change    = payload["data"] as? [String: Any],
            let table     = change["table"] as? String,
            let eventType = change["eventType"] as? String
        else { return }

        let newRec = change["new"] as? [String: Any] ?? [:]
        let oldRec = change["old"] as? [String: Any] ?? [:]

        DispatchQueue.main.async { [weak self] in
            switch eventType {
            case "INSERT": self?.onInsert?(table, newRec)
            case "DELETE": self?.onDelete?(table, oldRec)
            default: break
            }
        }
    }
}
