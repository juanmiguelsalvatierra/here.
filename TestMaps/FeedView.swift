import SwiftUI

struct FeedView: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showNotifications: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("feed")
                            .font(Here.Font.display(28, weight: .bold))
                            .foregroundColor(Here.Color.ink)
                        Spacer()
                        Button {
                            feedVM.markAllRead()
                            showNotifications = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(Here.Color.ink)
                                if feedVM.unreadCount > 0 {
                                    Circle()
                                        .fill(Here.Color.ink)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 3, y: -3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Here.Spacing.lg)
                    .padding(.top, 56)
                    .padding(.bottom, Here.Spacing.md)

                    // Active friends strip
                    ActiveFriendsStrip()
                        .padding(.bottom, Here.Spacing.md)

                    // Posts
                    ForEach(Array(feedVM.posts.enumerated()), id: \.element.id) { idx, post in
                        PostCard(post: post)
                            .padding(.horizontal, Here.Spacing.lg)
                            .padding(.bottom, Here.Spacing.md)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.8)
                                    .delay(Double(idx) * 0.07),
                                value: appeared
                            )
                    }

                    // Bottom padding for tab bar
                    Spacer().frame(height: 80)
                }
            }
            .background(Here.Color.white)
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
                    .environmentObject(feedVM)
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Active Friends Strip
struct ActiveFriendsStrip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Here.Spacing.sm) {
            Text("gerade aktiv")
                .font(Here.Font.body(12, weight: .medium))
                .foregroundColor(Here.Color.stone)
                .padding(.leading, Here.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Here.Spacing.sm) {
                    Spacer().frame(width: Here.Spacing.sm)
                    ForEach(MockData.users.dropFirst()) { user in
                        VStack(spacing: 4) {
                            ZStack(alignment: .bottomTrailing) {
                                AvatarView(user: user, size: 46)
                                Circle()
                                    .fill(Here.Color.success)
                                    .frame(width: 11, height: 11)
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                            }
                            Text(user.displayName)
                                .font(Here.Font.body(11))
                                .foregroundColor(Here.Color.stone)
                        }
                    }
                    Spacer().frame(width: Here.Spacing.sm)
                }
            }
        }
    }
}

// MARK: - Post Card
struct PostCard: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel
    let post: LocationPost

    @State private var showReactionPicker: Bool = false
    @State private var isJoining: Bool = false

    private var currentUserJoined: Bool {
        post.joinedUserIDs.contains(authVM.currentUser.id)
    }

    private var reactionGroups: [(emoji: String, count: Int, userReacted: Bool)] {
        let grouped = Dictionary(grouping: post.reactions, by: \.emoji)
        return grouped.map { emoji, reactions in
            (emoji: emoji, count: reactions.count, userReacted: reactions.contains { $0.userID == authVM.currentUser.id })
        }.sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────
            HStack(spacing: Here.Spacing.sm) {
                if let author = post.author {
                    AvatarView(user: author, size: 38)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.displayName ?? "")
                        .font(Here.Font.body(14, weight: .semibold))
                        .foregroundColor(Here.Color.ink)
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Here.Color.stone)
                        Text(post.locationName)
                            .font(Here.Font.mono(11))
                            .foregroundColor(Here.Color.stone)
                    }
                }
                Spacer()
                Text(post.timeAgo)
                    .font(Here.Font.body(12))
                    .foregroundColor(Here.Color.stone)

                Button {
                    feedVM.toggleFavorite(postID: post.id)
                } label: {
                    Image(systemName: post.isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(post.isFavorited ? Here.Color.danger : Here.Color.stone)
                }
            }
            .padding(.bottom, Here.Spacing.md)

            // ── Photo ─────────────────────────────────────────────
            if let local = post.localImage {
                Image(uiImage: local)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
                    .padding(.bottom, Here.Spacing.md)
            } else if let urlString = post.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
                    case .empty:
                        RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                            .fill(Here.Color.cloud).frame(height: 200)
                            .overlay(ProgressView().tint(Here.Color.stone))
                    default: EmptyView()
                    }
                }
                .padding(.bottom, Here.Spacing.md)
            }

            // ── Caption ────────────────────────────────────────────
            Text(post.caption)
                .font(Here.Font.body(15))
                .foregroundColor(Here.Color.ink)
                .lineSpacing(2)
                .padding(.bottom, Here.Spacing.md)

            // ── Who's there ────────────────────────────────────────
            if let joined = post.joinedUsers, !joined.isEmpty {
                HStack(spacing: 8) {
                    StackedAvatarsView(users: joined, size: 26)
                    Text("\(joined.count) \(joined.count == 1 ? "person" : "personen") dabei")
                        .font(Here.Font.body(13))
                        .foregroundColor(Here.Color.stone)
                }
                .padding(.bottom, Here.Spacing.md)
            }

            // ── Actions ────────────────────────────────────────────
            VStack(spacing: Here.Spacing.sm) {
                // Top row: Reactions & Join
                HStack(spacing: Here.Spacing.sm) {
                    // Reactions
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(reactionGroups, id: \.emoji) { group in
                                ReactionBadge(
                                    emoji: group.emoji,
                                    count: group.count,
                                    isSelected: group.userReacted
                                ) {
                                    feedVM.addReaction(postID: post.id, emoji: group.emoji, userID: authVM.currentUser.id)
                                }
                            }

                            // Add reaction
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    showReactionPicker.toggle()
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Here.Color.stone)
                                    .padding(8)
                                    .background(Here.Color.cloud)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    Spacer()

                    // Join button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                            feedVM.toggleJoin(postID: post.id, userID: authVM.currentUser.id)
                        }
                    } label: {
                        Text(currentUserJoined ? "dabei ✓" : "joinen")
                            .font(Here.Font.body(13, weight: .semibold))
                            .foregroundColor(currentUserJoined ? Here.Color.white : Here.Color.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(currentUserJoined ? Here.Color.ink : Here.Color.cloud)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    currentUserJoined ? Here.Color.ink : Here.Color.border,
                                    lineWidth: 1
                                )
                            )
                    }
                }
                
                // Bottom row: Comment button
                HStack {
                    CommentButtonStyled(post: post)
                    Spacer()
                }
            }

            // ── Reaction picker ────────────────────────────────────
            if showReactionPicker {
                EmojiPickerRow { emoji in
                    feedVM.addReaction(postID: post.id, emoji: emoji, userID: authVM.currentUser.id)
                    withAnimation { showReactionPicker = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomLeading)))
                .padding(.top, Here.Spacing.sm)
            }
        }
        .padding(Here.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Here.Radius.lg, style: .continuous)
                .fill(Here.Color.white)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: Here.Radius.lg, style: .continuous)
                        .strokeBorder(Here.Color.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Emoji picker
struct EmojiPickerRow: View {
    let onSelect: (String) -> Void
    private let emojis = ["🔥","❤️","👀","😂","🙌","☕","🏔","🛹","✨","💪"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 22))
                            .padding(8)
                            .background(Here.Color.cloud)
                            .clipShape(RoundedRectangle(cornerRadius: Here.Radius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Comment Button (styled for Here app)
struct CommentButtonStyled: View {
    let post: LocationPost
    @State private var showComments = false
    
    var body: some View {
        Button {
            showComments = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Here.Color.stone)
                
                if post.comments.count > 0 {
                    Text("\(post.comments.count)")
                        .font(Here.Font.body(13, weight: .medium))
                        .foregroundColor(Here.Color.stone)
                    
                    Text(post.comments.count == 1 ? "kommentar" : "kommentare")
                        .font(Here.Font.body(13))
                        .foregroundColor(Here.Color.stone)
                } else {
                    Text("kommentieren")
                        .font(Here.Font.body(13))
                        .foregroundColor(Here.Color.stone)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showComments) {
            NavigationStack {
                CommentsViewStyled(post: post)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("schließen") {
                                showComments = false
                            }
                            .font(Here.Font.body(15))
                            .foregroundColor(Here.Color.ink)
                        }
                    }
            }
        }
    }
}

// MARK: - Comments View (styled for Here app)
struct CommentsViewStyled: View {
    let post: LocationPost
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var commentViewModel = CommentViewModel()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("kommentare")
                    .font(Here.Font.display(20, weight: .bold))
                    .foregroundColor(Here.Color.ink)
                Spacer()
                Text("\(post.comments.count)")
                    .font(Here.Font.body(15))
                    .foregroundColor(Here.Color.stone)
            }
            .padding(.horizontal, Here.Spacing.lg)
            .padding(.vertical, Here.Spacing.md)
            
            Divider()
                .background(Here.Color.border)
            
            // Comments List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Here.Spacing.md) {
                    if post.comments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundStyle(Here.Color.stone.opacity(0.4))
                            Text("noch keine kommentare")
                                .font(Here.Font.body(14))
                                .foregroundStyle(Here.Color.stone)
                            Text("sei der erste, der kommentiert!")
                                .font(Here.Font.body(12))
                                .foregroundStyle(Here.Color.stone.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(post.comments) { comment in
                            CommentRowStyled(
                                comment: comment,
                                canDelete: comment.userID == authViewModel.currentUser.id,
                                onDelete: {
                                    feedViewModel.deleteComment(postID: post.id, commentID: comment.id)
                                }
                            )
                        }
                    }
                }
                .padding(Here.Spacing.lg)
            }
            
            Divider()
                .background(Here.Color.border)
            
            // Comment Input
            HStack(spacing: Here.Spacing.sm) {
                // User Avatar
                AvatarView(user: authViewModel.currentUser, size: 32)
                
                // Text Field
                TextField("kommentar hinzufügen...", text: $commentViewModel.commentText, axis: .vertical)
                    .font(Here.Font.body(15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Here.Color.cloud)
                    .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md))
                    .lineLimit(1...4)
                    .focused($isTextFieldFocused)
                
                // Send Button
                Button {
                    commentViewModel.submitComment(
                        postID: post.id,
                        user: authViewModel.currentUser,
                        feed: feedViewModel
                    )
                    isTextFieldFocused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(commentViewModel.canSubmit ? Here.Color.ink : Here.Color.stone.opacity(0.3))
                }
                .disabled(!commentViewModel.canSubmit)
            }
            .padding(Here.Spacing.lg)
            .background(Here.Color.white)
        }
        .background(Here.Color.white)
    }
}

// MARK: - Comment Row (styled for Here app)
struct CommentRowStyled: View {
    let comment: Comment
    let canDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: Here.Spacing.sm) {
            // User Avatar
            if let user = comment.user {
                AvatarView(user: user, size: 36)
            } else {
                Circle()
                    .fill(Here.Color.cloud)
                    .frame(width: 36, height: 36)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Username and time
                HStack(spacing: 8) {
                    Text(comment.user?.displayName ?? "unbekannt")
                        .font(Here.Font.body(14, weight: .semibold))
                        .foregroundColor(Here.Color.ink)
                    
                    Text(comment.timeAgo)
                        .font(Here.Font.mono(11))
                        .foregroundStyle(Here.Color.stone)
                    
                    Spacer()
                    
                    if canDelete {
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.3)) {
                                onDelete()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(Here.Color.danger)
                        }
                    }
                }
                
                // Comment text
                Text(comment.text)
                    .font(Here.Font.body(15))
                    .foregroundColor(Here.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FeedView()
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(LocationService())
}
