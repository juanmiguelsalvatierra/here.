import SwiftUI

@main
struct HereApp: App {
    @StateObject private var authVM          = AuthViewModel()
    @StateObject private var locationService = LocationService()
    @StateObject private var feedVM          = FeedViewModel()
    @StateObject private var friendVM        = FriendViewModel()

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
                    Task {
                        await feedVM.fetchPosts()
                        await friendVM.refresh(userID: authVM.currentUser.id)
                    }
                }
            }
        }
    }
}
