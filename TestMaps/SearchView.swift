import SwiftUI

// MARK: - Search Tab

struct SearchView: View {
    @EnvironmentObject var authVM:   AuthViewModel
    @EnvironmentObject var feedVM:   FeedViewModel
    @EnvironmentObject var friendVM: FriendViewModel

    @State private var segment:  SearchSegment = .erkunden
    @State private var query                   = ""
    @State private var appeared                = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────
                VStack(alignment: .leading, spacing: Here.Spacing.md) {
                    Text("suchen")
                        .font(Here.Font.display(28, weight: .bold))
                        .foregroundColor(Here.Color.ink)
                        .padding(.top, 56)

                    // Segment picker
                    HStack(spacing: Here.Spacing.sm) {
                        ForEach(SearchSegment.allCases) { seg in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    segment = seg
                                    query   = ""
                                    friendVM.searchResults = []
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: seg.icon)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(seg.label)
                                        .font(Here.Font.body(13, weight: .medium))
                                }
                                .padding(.horizontal, Here.Spacing.md)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(segment == seg ? Here.Color.ink : Here.Color.cloud)
                                )
                                .foregroundColor(segment == seg ? .white : Here.Color.stone)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // Search bar — only for Freunde segment
                    if segment == .freunde {
                        HStack(spacing: Here.Spacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Here.Color.stone)
                            TextField("benutzername suchen…", text: $query)
                                .font(Here.Font.body(16))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: query) { _, q in
                                    Task { await friendVM.search(query: q, myID: authVM.currentUser.id) }
                                }
                            if !query.isEmpty {
                                Button { query = ""; friendVM.searchResults = [] } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Here.Color.stone)
                                }
                            }
                        }
                        .padding(Here.Spacing.md)
                        .background(Here.Color.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, Here.Spacing.lg)
                .padding(.bottom, Here.Spacing.md)
                .background(Here.Color.white)

                Divider()

                // ── Content ───────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        switch segment {
                        case .erkunden: ErkundenSection()
                        case .freunde:  FreundeSection(query: query)
                        case .events:   EventsSection()
                        }
                    }
                    .padding(.top, Here.Spacing.md)
                    .padding(.bottom, 100)
                }
            }
            .background(Here.Color.white)
        }
        .task {
            await friendVM.refresh(userID: authVM.currentUser.id)
        }
    }
}

// MARK: - Segments

enum SearchSegment: String, CaseIterable, Identifiable {
    case erkunden, freunde, events
    var id: String { rawValue }
    var label: String {
        switch self {
        case .erkunden: return "erkunden"
        case .freunde:  return "freunde"
        case .events:   return "events"
        }
    }
    var icon: String {
        switch self {
        case .erkunden: return "sparkles"
        case .freunde:  return "person.2"
        case .events:   return "calendar"
        }
    }
}

// MARK: - Erkunden (public city posts)

private struct ErkundenSection: View {
    @EnvironmentObject var feedVM:  FeedViewModel
    @EnvironmentObject var authVM:  AuthViewModel

    private var publicPosts: [LocationPost] {
        feedVM.posts.filter { $0.visibility == .city }
    }

    var body: some View {
        if publicPosts.isEmpty {
            EmptyStateView(
                icon: "sparkles",
                text: "noch keine öffentlichen posts.\nsei der erste in deiner stadt!"
            )
            .padding(.top, 60)
        } else {
            ForEach(publicPosts) { post in
                ExplorePostCard(post: post)
                    .padding(.horizontal, Here.Spacing.lg)
                    .padding(.bottom, Here.Spacing.md)
            }
        }
    }
}

private struct ExplorePostCard: View {
    let post: LocationPost
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Here.Spacing.sm) {
            // Author row
            HStack(spacing: Here.Spacing.sm) {
                AvatarView(user: post.author ?? .preview, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author?.displayName ?? "")
                        .font(Here.Font.body(14, weight: .semibold))
                        .foregroundColor(Here.Color.ink)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Here.Color.stone)
                        Text(post.locationName)
                            .font(Here.Font.mono(11))
                            .foregroundColor(Here.Color.stone)
                    }
                }
                Spacer()
                Text(post.timeAgo)
                    .font(Here.Font.body(11))
                    .foregroundColor(Here.Color.stone)
            }

            // Caption
            Text(post.caption)
                .font(Here.Font.body(15))
                .foregroundColor(Here.Color.ink)

            // Reactions & joins
            if !post.reactions.isEmpty || !post.joinedUserIDs.isEmpty {
                HStack(spacing: Here.Spacing.md) {
                    if !post.reactions.isEmpty {
                        HStack(spacing: 4) {
                            Text(post.reactions.prefix(3).map { $0.emoji }.joined())
                                .font(.system(size: 13))
                            Text("\(post.reactions.count)")
                                .font(Here.Font.body(12))
                                .foregroundColor(Here.Color.stone)
                        }
                    }
                    if !post.joinedUserIDs.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Here.Color.stone)
                            Text("\(post.joinedUserIDs.count) dabei")
                                .font(Here.Font.body(12))
                                .foregroundColor(Here.Color.stone)
                        }
                    }
                }
            }
        }
        .padding(Here.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                .fill(Here.Color.cloud)
        )
    }
}

// MARK: - Freunde (search + requests + list)

private struct FreundeSection: View {
    @EnvironmentObject var authVM:   AuthViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Search results
            if !friendVM.searchResults.isEmpty {
                SectionHeader("ergebnisse")
                    .padding(.horizontal, Here.Spacing.lg)
                ForEach(friendVM.searchResults) { user in
                    UserRow(
                        user: user,
                        status: friendVM.statusCache[user.id],
                        myID: authVM.currentUser.id
                    )
                    .padding(.horizontal, Here.Spacing.lg)
                    Divider().padding(.leading, Here.Spacing.lg + 44 + Here.Spacing.sm)
                }
            } else if friendVM.isSearching {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if !query.isEmpty {
                Text("keine ergebnisse für \"\(query)\"")
                    .font(Here.Font.body(14))
                    .foregroundColor(Here.Color.stone)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }

            // Incoming requests
            if !friendVM.incoming.isEmpty {
                SectionHeader("anfragen (\(friendVM.incoming.count))")
                    .padding(.horizontal, Here.Spacing.lg)
                    .padding(.top, Here.Spacing.lg)
                ForEach(friendVM.incoming) { req in
                    IncomingRow(friendship: req)
                        .padding(.horizontal, Here.Spacing.lg)
                    Divider().padding(.leading, Here.Spacing.lg + 44 + Here.Spacing.sm)
                }
            }

            // Friends list
            if !friendVM.friends.isEmpty {
                SectionHeader("\(friendVM.friends.count) freunde")
                    .padding(.horizontal, Here.Spacing.lg)
                    .padding(.top, query.isEmpty ? 0 : Here.Spacing.lg)
                ForEach(friendVM.friends) { user in
                    FriendRow(user: user)
                        .padding(.horizontal, Here.Spacing.lg)
                    Divider().padding(.leading, Here.Spacing.lg + 44 + Here.Spacing.sm)
                }
            } else if query.isEmpty && friendVM.incoming.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    text: "noch keine freunde.\nsuch nach benutzernamen!"
                )
                .padding(.top, 40)
            }
        }
    }
}

struct FriendRow: View {
    @EnvironmentObject var authVM:   AuthViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    let user: User

    var body: some View {
        HStack(spacing: Here.Spacing.sm) {
            AvatarView(user: user, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(Here.Font.body(15, weight: .medium))
                    .foregroundColor(Here.Color.ink)
                Text("@\(user.username)")
                    .font(Here.Font.body(13))
                    .foregroundColor(Here.Color.stone)
            }
            Spacer()
            Button {
                Task { await friendVM.removeFriend(friendID: user.id, myID: authVM.currentUser.id) }
            } label: {
                Text("entfernen")
                    .font(Here.Font.body(12))
                    .foregroundColor(Here.Color.stone)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().stroke(Here.Color.stone.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Here.Spacing.sm)
    }
}

// MARK: - Events (public event-style posts)

private struct EventsSection: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel

    private var eventPosts: [LocationPost] {
        feedVM.posts.filter { $0.visibility == .city }
    }

    var body: some View {
        if eventPosts.isEmpty {
            EmptyStateView(
                icon: "calendar",
                text: "keine events in deiner nähe.\nhalt ausschau!"
            )
            .padding(.top, 60)
        } else {
            VStack(spacing: Here.Spacing.md) {
                ForEach(eventPosts) { post in
                    EventCard(post: post)
                        .padding(.horizontal, Here.Spacing.lg)
                }
            }
        }
    }
}

private struct EventCard: View {
    let post: LocationPost
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel

    private var isJoined: Bool {
        post.joinedUserIDs.contains(authVM.currentUser.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top colour band
            RoundedRectangle(cornerRadius: 0)
                .fill(avatarColor(post.author?.avatarColor ?? "#1A1A1A").opacity(0.15))
                .frame(height: 6)

            VStack(alignment: .leading, spacing: Here.Spacing.sm) {
                // Organiser
                HStack(spacing: Here.Spacing.sm) {
                    AvatarView(user: post.author ?? .preview, size: 32)
                    Text(post.author?.displayName ?? "")
                        .font(Here.Font.body(13, weight: .medium))
                        .foregroundColor(Here.Color.stone)
                    Spacer()
                    Image(systemName: "mappin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Here.Color.stone)
                    Text(post.locationName)
                        .font(Here.Font.mono(11))
                        .foregroundColor(Here.Color.stone)
                }

                // Caption
                Text(post.caption)
                    .font(Here.Font.body(16, weight: .semibold))
                    .foregroundColor(Here.Color.ink)

                // Footer
                HStack {
                    // Attendees
                    HStack(spacing: -8) {
                        ForEach(Array((post.joinedUsers ?? []).prefix(3).enumerated()), id: \.offset) { _, u in
                            AvatarView(user: u, size: 22)
                                .overlay(Circle().stroke(Here.Color.white, lineWidth: 1.5))
                        }
                    }
                    if !post.joinedUserIDs.isEmpty {
                        Text("\(post.joinedUserIDs.count) dabei")
                            .font(Here.Font.body(12))
                            .foregroundColor(Here.Color.stone)
                            .padding(.leading, post.joinedUserIDs.count > 0 ? 12 : 0)
                    }
                    Spacer()
                    // Join button
                    Button {
                        feedVM.toggleJoin(postID: post.id, userID: authVM.currentUser.id)
                    } label: {
                        Text(isJoined ? "dabei ✓" : "mitmachen")
                            .font(Here.Font.body(13, weight: .medium))
                            .foregroundColor(isJoined ? Here.Color.stone : .white)
                            .padding(.horizontal, Here.Spacing.md)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isJoined ? Here.Color.cloud : Here.Color.ink)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Here.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                .fill(Here.Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
    }

    private func avatarColor(_ hex: String) -> Color {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return .black }
        return Color(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}

// MARK: - Shared sub-views (used across segments)

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(Here.Font.body(12, weight: .semibold))
            .foregroundColor(Here.Color.stone)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.bottom, Here.Spacing.xs)
    }
}

struct UserRow: View {
    @EnvironmentObject var authVM:   AuthViewModel
    @EnvironmentObject var friendVM: FriendViewModel

    let user:   User
    let status: String?
    let myID:   String

    var body: some View {
        HStack(spacing: Here.Spacing.sm) {
            AvatarView(user: user, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(Here.Font.body(15, weight: .medium))
                    .foregroundColor(Here.Color.ink)
                Text("@\(user.username)")
                    .font(Here.Font.body(13))
                    .foregroundColor(Here.Color.stone)
            }
            Spacer()
            actionButton
        }
        .padding(.vertical, Here.Spacing.sm)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case nil:
            Button {
                Task { await friendVM.sendRequest(to: user.id, myID: myID) }
            } label: {
                Text("hinzufügen")
                    .font(Here.Font.body(13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, Here.Spacing.md)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Here.Color.ink))
            }
            .buttonStyle(.plain)

        case "pending":
            Text("ausstehend")
                .font(Here.Font.body(13))
                .foregroundColor(Here.Color.stone)
                .padding(.horizontal, Here.Spacing.md)
                .padding(.vertical, 7)
                .background(Capsule().stroke(Here.Color.stone.opacity(0.4), lineWidth: 1))

        case "accepted":
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                Text("befreundet")
                    .font(Here.Font.body(13))
            }
            .foregroundColor(Here.Color.stone)

        default:
            EmptyView()
        }
    }
}

struct IncomingRow: View {
    @EnvironmentObject var authVM:   AuthViewModel
    @EnvironmentObject var friendVM: FriendViewModel

    let friendship: Friendship

    var body: some View {
        HStack(spacing: Here.Spacing.sm) {
            Circle()
                .fill(Here.Color.cloud)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(Here.Color.stone)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("freundschaftsanfrage")
                    .font(Here.Font.body(14, weight: .medium))
                    .foregroundColor(Here.Color.ink)
                Text(friendship.requesterID)
                    .font(Here.Font.mono(11))
                    .foregroundColor(Here.Color.stone)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: Here.Spacing.sm) {
                Button {
                    Task { await friendVM.accept(friendshipID: friendship.id, requesterID: friendship.requesterID) }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Here.Color.ink))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await friendVM.remove(friendshipID: friendship.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Here.Color.stone)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Here.Color.cloud))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Here.Spacing.sm)
    }
}
