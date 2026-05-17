import SwiftUI
import UIKit

// MARK: - AppDelegate (needed only for APNs token callback)

class AppDelegate: NSObject, UIApplicationDelegate {
    var onToken: ((Data) -> Void)?

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        onToken?(deviceToken)
    }
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[here.] APNs registration failed: \(error)")
    }
}

// MARK: - App

@main
struct HereApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authVM          = AuthViewModel()
    @StateObject private var locationService = LocationService()
    @StateObject private var feedVM          = FeedViewModel()
    @StateObject private var friendVM        = FriendViewModel()
    @StateObject private var realtimeService = RealtimeService()
    @StateObject private var notifService    = NotificationService()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoggedIn {
                    MainTabView()
                        .environmentObject(authVM)
                        .environmentObject(locationService)
                        .environmentObject(feedVM)
                        .environmentObject(friendVM)
                } else {
                    OnboardingView()
                        .environmentObject(authVM)
                }
            }
            .preferredColorScheme(.light)
            .task { await authVM.restoreSession() }
            .onChange(of: authVM.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    let userID = authVM.currentUser.id
                    Task {
                        await feedVM.fetchPosts()
                        await friendVM.refresh(userID: userID)
                        await notifService.requestPermission()
                    }
                    // Push token → Supabase once APNs responds
                    appDelegate.onToken = { tokenData in
                        Task { await notifService.register(tokenData: tokenData, userID: userID) }
                    }
                    // Realtime WebSocket
                    if let token = KeychainStore.read("access_token") {
                        realtimeService.connect(token: token)
                        feedVM.connectRealtime(realtimeService)
                    }
                } else {
                    realtimeService.disconnect()
                    appDelegate.onToken = nil
                }
            }
        }
    }
}

// MARK: - UIImage compression helper

extension UIImage {
    /// JPEG-compress and downsample in one step. Safe to call from any context.
    func jpegCompressed(maxDimension: CGFloat = 1200, quality: CGFloat = 0.75) -> Data? {
        let scale    = min(maxDimension / max(size.width, size.height), 1)
        let newSize  = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.jpegData(withCompressionQuality: quality) { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
