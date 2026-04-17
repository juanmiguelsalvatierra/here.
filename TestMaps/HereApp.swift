import SwiftUI

@main
struct HereApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var locationService = LocationService()
    @StateObject private var feedVM = FeedViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoggedIn {
                    MainTabView()
                        .environmentObject(authVM)
                        .environmentObject(locationService)
                        .environmentObject(feedVM)
                } else {
                    OnboardingView()
                        .environmentObject(authVM)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
