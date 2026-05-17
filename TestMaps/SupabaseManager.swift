import Foundation

// MARK: - Supabase REST client

enum SupabaseClient {
    static let baseURL = "https://memkvlwdfhgpexyieirc.supabase.co"
    static let apiKey  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1lbWt2bHdkZmhncGV4eWllaXJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5OTY0MjQsImV4cCI6MjA5NDU3MjQyNH0.3h6CUmTcwWVOph9gXgQfK99Yuy4UM51RDf6j_Y4xXO4"

    static var token: String? { KeychainStore.read("access_token") }

    // MARK: GET
    static func get(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        var comps = URLComponents(string: "\(baseURL)\(path)")!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.setValue(apiKey,             forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    // MARK: POST  (Prefer: return=representation → returns inserted row)
    static func post(_ path: String, body: [String: Any]) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        req.httpMethod = "POST"
        req.setValue(apiKey,                 forHTTPHeaderField: "apikey")
        req.setValue("application/json",     forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",     forHTTPHeaderField: "Accept")
        req.setValue("return=representation",forHTTPHeaderField: "Prefer")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 && status != 201 {
            // Surface the real Supabase error message
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg  = body["message"] as? String {
                throw NSError(domain: "Supabase", code: status,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: UPSERT  (insert or update on conflict)
    static func upsert(_ path: String, body: [String: Any]) async throws {
        var req = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        req.httpMethod = "POST"
        req.setValue(apiKey,                       forHTTPHeaderField: "apikey")
        req.setValue("application/json",           forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates",forHTTPHeaderField: "Prefer")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 201 else { throw URLError(.badServerResponse) }
    }

    // MARK: PATCH
    static func patch(_ path: String, query: [URLQueryItem], body: [String: Any]) async throws {
        var comps = URLComponents(string: "\(baseURL)\(path)")!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PATCH"
        req.setValue(apiKey,             forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 204 else { throw URLError(.badServerResponse) }
    }


    // MARK: Storage upload — returns public URL
    static func upload(bucket: String, path: String, data: Data, mimeType: String = "image/jpeg") async throws -> String {
        let url = URL(string: "\(baseURL)/storage/v1/object/\(bucket)/\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey,   forHTTPHeaderField: "apikey")
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        req.setValue("true",   forHTTPHeaderField: "x-upsert")   // overwrite existing
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = data
        let (_, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 201 else { throw URLError(.badServerResponse) }
        return "\(baseURL)/storage/v1/object/public/\(bucket)/\(path)"
    }
    // MARK: DELETE
    static func delete(_ path: String, query: [URLQueryItem]) async throws {
        var comps = URLComponents(string: "\(baseURL)\(path)")!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (_, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 204 else { throw URLError(.badServerResponse) }
    }
}

// MARK: - Keychain  (shared with AuthViewModel)

enum KeychainStore {
    private static let service = "com.here.app"

    static func write(_ key: String, _ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service, kSecAttrAccount: key, kSecValueData: data
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service, kSecAttrAccount: key,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne
        ]
        var out: AnyObject?
        SecItemCopyMatching(q as CFDictionary, &out)
        guard let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service, kSecAttrAccount: key
        ]
        SecItemDelete(q as CFDictionary)
    }
}
