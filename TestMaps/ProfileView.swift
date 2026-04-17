import SwiftUI

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @State private var showLogoutAlert = false

    private var myPosts: [LocationPost] {
        feedVM.posts.filter { $0.authorID == authVM.currentUser.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Here.Spacing.lg) {

                    // Header
                    Text("ich")
                        .font(Here.Font.display(28, weight: .bold))
                        .foregroundColor(Here.Color.ink)
                        .padding(.top, 56)

                    // Profile card
                    HStack(spacing: Here.Spacing.md) {
                        AvatarView(user: authVM.currentUser, size: 64)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authVM.currentUser.displayName)
                                .font(Here.Font.display(20, weight: .semibold))
                                .foregroundColor(Here.Color.ink)
                            Text("@\(authVM.currentUser.username)")
                                .font(Here.Font.mono(13))
                                .foregroundColor(Here.Color.stone)
                            Text(authVM.currentUser.bio)
                                .font(Here.Font.body(13))
                                .foregroundColor(Here.Color.stone)
                        }
                        Spacer()
                    }

                    // Stats row
                    HStack(spacing: 0) {
                        StatCell(value: "\(myPosts.count)", label: "posts")
                        Divider().frame(height: 28)
                        StatCell(value: "\(authVM.currentUser.friendIDs.count)", label: "freunde")
                        Divider().frame(height: 28)
                        StatCell(value: "\(myPosts.flatMap { $0.joinedUserIDs }.count)", label: "joins")
                    }
                    .padding(.vertical, Here.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                            .fill(Here.Color.cloud)
                    )

                    // My Posts header
                    if !myPosts.isEmpty {
                        Text("meine posts")
                            .font(Here.Font.body(13, weight: .medium))
                            .foregroundColor(Here.Color.stone)

                        ForEach(myPosts) { post in
                            MyPostRow(post: post)
                        }
                    } else {
                        EmptyStateView(icon: "mappin.circle", text: "noch nichts geteilt.\njetzt losgehen!")
                    }

                    Divider().padding(.vertical, Here.Spacing.sm)

                    // Settings
                    VStack(spacing: 0) {
                        SettingsRow(icon: "person.2", label: "freunde finden")
                        SettingsRow(icon: "bell", label: "benachrichtigungen")
                        SettingsRow(icon: "lock", label: "datenschutz")
                        SettingsRow(icon: "questionmark.circle", label: "hilfe")

                        Button {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(Here.Color.danger)
                                Text("abmelden")
                                    .font(Here.Font.body(15))
                                    .foregroundColor(Here.Color.danger)
                                Spacer()
                            }
                            .padding(.vertical, Here.Spacing.md)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, Here.Spacing.lg)
            }
            .background(Here.Color.white)
        }
        .alert("abmelden?", isPresented: $showLogoutAlert) {
            Button("abmelden", role: .destructive) { authVM.logout() }
            Button("abbrechen", role: .cancel) {}
        }
    }
}

struct StatCell: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Here.Font.display(20, weight: .bold))
                .foregroundColor(Here.Color.ink)
            Text(label)
                .font(Here.Font.body(11))
                .foregroundColor(Here.Color.stone)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MyPostRow: View {
    let post: LocationPost
    var body: some View {
        HStack(spacing: Here.Spacing.sm) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Here.Color.cloud)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "camera")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Here.Color.stone)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(post.caption)
                    .font(Here.Font.body(14))
                    .foregroundColor(Here.Color.ink)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(post.locationName)
                        .font(Here.Font.mono(11))
                        .foregroundColor(Here.Color.stone)
                    Text("·")
                        .foregroundColor(Here.Color.stone)
                    Text(post.timeAgo)
                        .font(Here.Font.body(11))
                        .foregroundColor(Here.Color.stone)
                }
            }
            Spacer()
            if !post.reactions.isEmpty {
                Text(post.reactions.prefix(2).map { $0.emoji }.joined())
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, Here.Spacing.sm)
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Here.Color.ink)
                .frame(width: 24)
            Text(label)
                .font(Here.Font.body(15))
                .foregroundColor(Here.Color.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Here.Color.stone)
        }
        .padding(.vertical, Here.Spacing.md)
        .overlay(
            Divider().frame(maxWidth: .infinity), alignment: .bottom
        )
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(feedVM.notifications) { notif in
                        NotificationRow(notification: notif)
                        Divider().padding(.leading, Here.Spacing.lg + 44 + Here.Spacing.sm)
                    }
                }
                .padding(.top, Here.Spacing.sm)
            }
            .background(Here.Color.white)
            .navigationTitle("benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("fertig") { dismiss() }
                        .font(Here.Font.body(15))
                        .foregroundColor(Here.Color.ink)
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: HereNotification

    private var icon: String {
        switch notification.type {
        case .friendPosted: return "location.fill"
        case .friendJoined: return "person.fill.badge.plus"
        case .reaction:     return "heart.fill"
        case .newFriend:    return "person.2.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Here.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(notification.isRead ? Here.Color.cloud : Here.Color.ink)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(notification.isRead ? Here.Color.stone : .white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(Here.Font.body(14, weight: notification.isRead ? .regular : .semibold))
                    .foregroundColor(Here.Color.ink)
                Text(notification.timestamp, style: .relative)
                    .font(Here.Font.body(12))
                    .foregroundColor(Here.Color.stone)
            }
            Spacer()
        }
        .padding(.horizontal, Here.Spacing.lg)
        .padding(.vertical, Here.Spacing.md)
        .background(notification.isRead ? Color.clear : Here.Color.cloud.opacity(0.5))
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(FeedViewModel())
}
