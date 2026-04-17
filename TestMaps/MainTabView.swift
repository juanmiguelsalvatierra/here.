import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @State private var selectedTab: Int = 0
    @StateObject private var favVM = FavoritesViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                MapFeedView()
                    .tag(0)
                FeedView()
                    .tag(1)
                FavoritesView()
                    .environmentObject(favVM)
                    .tag(2)
                ProfileView()
                    .tag(3)
            }

            // Custom tab bar
            HereTabBar(selectedTab: $selectedTab, unreadCount: feedVM.unreadCount)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct HereTabBar: View {
    @Binding var selectedTab: Int
    var unreadCount: Int

    private let items: [(icon: String, label: String)] = [
        ("map",              "karte"),
        ("list.bullet",      "feed"),
        ("heart",            "saved"),
        ("person",           "ich"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = idx
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: selectedTab == idx ? item.icon + ".fill" : item.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(selectedTab == idx ? Here.Color.ink : Here.Color.stone)

                            // Notification badge on feed tab
                            if idx == 1 && unreadCount > 0 {
                                Circle()
                                    .fill(Here.Color.ink)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -3)
                            }
                        }
                        Text(item.label)
                            .font(Here.Font.body(10, weight: selectedTab == idx ? .semibold : .regular))
                            .foregroundColor(selectedTab == idx ? Here.Color.ink : Here.Color.stone)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Here.Spacing.sm)
        .background(
            Rectangle()
                .fill(Here.Color.white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(LocationService())
        .environmentObject(FeedViewModel())
}
