import UIKit
import Combine
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {

    func requestPermission() async {
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        guard granted == true else { return }
        await UIApplication.shared.registerForRemoteNotifications()
    }

    // Called by AppDelegate once APNs hands us a token
    func register(tokenData: Data, userID: String) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        try? await SupabaseClient.upsert("/rest/v1/push_tokens", body: [
            "user_id":  userID,
            "token":    token,
            "platform": "apns"
        ])
    }
}
