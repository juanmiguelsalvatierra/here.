import SwiftUI
import MapKit

struct MapFeedView: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var authVM: AuthViewModel

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var selectedPost: LocationPost?
    @State private var showNewPost: Bool = false
    @State private var mapOffset: CGFloat = 0
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Map ──────────────────────────────────────────────
            Map(position: $cameraPosition) {
                // User location
                UserAnnotation()

                // Post annotations
                ForEach(feedVM.posts) { post in
                    Annotation("", coordinate: post.coordinate.clLocation) {
                        PostMapPin(post: post, isSelected: selectedPost?.id == post.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedPost = (selectedPost?.id == post.id) ? nil : post
                                }
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { }
            .ignoresSafeArea()

            // ── Top overlay: wordmark + location ────────────────
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("here.")
                            .font(Here.Font.display(28, weight: .bold))
                            .foregroundColor(Here.Color.ink)
                        Text(locationService.currentPlaceName)
                            .font(Here.Font.body(12))
                            .foregroundColor(Here.Color.stone)
                    }
                    Spacer()

                    // Recenter
                    Button {
                        if let loc = locationService.currentLocation {
                            withAnimation(.spring()) {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: loc,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                ))
                            }
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Here.Color.ink)
                            .padding(11)
                            .background(Circle().fill(Here.Color.white).shadow(color: .black.opacity(0.1), radius: 8))
                    }
                }
                .padding(.horizontal, Here.Spacing.lg)
                .padding(.top, 56)

                Spacer()
            }

            // ── Post card peek ────────────────────────────────────
            VStack(spacing: Here.Spacing.sm) {
                if let post = selectedPost {
                    MapPostCard(post: post)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { selectedPost = nil }
                }

                // ── CTA button ───────────────────────────────────
                Button {
                    showNewPost = true
                    locationService.startUpdating()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("jetzt teilen")
                            .font(Here.Font.body(16, weight: .semibold))
                    }
                    .foregroundColor(Here.Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Here.Color.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Here.Radius.lg, style: .continuous))
                }
                .padding(.horizontal, Here.Spacing.lg)
                .padding(.bottom, 80)
            }
        }
        .sheet(isPresented: $showNewPost) {
            NewPostView()
                .environmentObject(feedVM)
                .environmentObject(locationService)
                .environmentObject(authVM)
        }
        .onAppear {
            locationService.requestPermission()
        }
    }
}

// MARK: - Map Pin
struct PostMapPin: View {
    let post: LocationPost
    var isSelected: Bool

    var body: some View {
        ZStack {
            // Pulse ring when selected
            if isSelected {
                Circle()
                    .fill(Here.Color.ink.opacity(0.12))
                    .frame(width: 56, height: 56)
            }

            Circle()
                .fill(isSelected ? Here.Color.ink : Here.Color.white)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .overlay(
                    Circle().strokeBorder(Here.Color.ink, lineWidth: isSelected ? 0 : 1.5)
                )
                .overlay(
                    // Mini stacked avatars in pin
                    Group {
                        if let author = post.author {
                            Text(String(author.displayName.prefix(1)))
                                .font(Here.Font.display(14, weight: .semibold))
                                .foregroundColor(isSelected ? .white : Here.Color.ink)
                        }
                    }
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Map Post Card (bottom sheet peek)
struct MapPostCard: View {
    let post: LocationPost
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showFullPost = false
    
    private var currentUserJoined: Bool {
        post.joinedUserIDs.contains(authVM.currentUser.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Here.Spacing.sm) {
            HStack(spacing: Here.Spacing.sm) {
                if let author = post.author {
                    AvatarView(user: author, size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.author?.displayName ?? "")
                            .font(Here.Font.body(14, weight: .semibold))
                            .foregroundColor(Here.Color.ink)
                        Text("·")
                            .foregroundColor(Here.Color.stone)
                        Text(post.timeAgo)
                            .font(Here.Font.body(13))
                            .foregroundColor(Here.Color.stone)
                    }
                    Text(post.locationName)
                        .font(Here.Font.mono(11))
                        .foregroundColor(Here.Color.stone)
                }
                Spacer()
            }

            Text(post.caption)
                .font(Here.Font.body(15))
                .foregroundColor(Here.Color.ink)
                .lineLimit(2)

            // Who's joined
            if let joined = post.joinedUsers, !joined.isEmpty {
                HStack(spacing: 6) {
                    StackedAvatarsView(users: joined, size: 22)
                    Text("\(joined.count) dabei")
                        .font(Here.Font.body(12))
                        .foregroundColor(Here.Color.stone)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Actions
            HStack(spacing: Here.Spacing.md) {
                // Join Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                        feedVM.toggleJoin(postID: post.id, userID: authVM.currentUser.id)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: currentUserJoined ? "checkmark.circle.fill" : "person.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                        Text(currentUserJoined ? "dabei" : "joinen")
                            .font(Here.Font.body(14, weight: .semibold))
                    }
                    .foregroundColor(currentUserJoined ? Here.Color.white : Here.Color.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(currentUserJoined ? Here.Color.ink : Here.Color.cloud)
                    .clipShape(Capsule())
                }
                
                // Comment Button
                Button {
                    showFullPost = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 14, weight: .medium))
                        if post.comments.count > 0 {
                            Text("\(post.comments.count)")
                                .font(Here.Font.body(13, weight: .medium))
                        }
                    }
                    .foregroundColor(Here.Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Here.Color.cloud)
                    .clipShape(Capsule())
                }
                
                // Reactions count
                if !post.reactions.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 14, weight: .medium))
                        Text("\(post.reactions.count)")
                            .font(Here.Font.body(13, weight: .medium))
                    }
                    .foregroundColor(Here.Color.stone)
                }
                
                Spacer()
            }
        }
        .padding(Here.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Here.Radius.lg, style: .continuous)
                .fill(Here.Color.white)
                .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
        )
        .padding(.horizontal, Here.Spacing.lg)
        .sheet(isPresented: $showFullPost) {
            NavigationStack {
                MapPostDetailView(post: post)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("schließen") {
                                showFullPost = false
                            }
                            .font(Here.Font.body(15))
                            .foregroundColor(Here.Color.ink)
                        }
                    }
            }
        }
    }
}

// MARK: - Map Post Detail View
struct MapPostDetailView: View {
    let post: LocationPost
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showComments = false
    @State private var showReactionPicker = false
    
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
        ScrollView {
            VStack(alignment: .leading, spacing: Here.Spacing.md) {
                
                // Header
                HStack(spacing: Here.Spacing.sm) {
                    if let author = post.author {
                        AvatarView(user: author, size: 48)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.author?.displayName ?? "")
                            .font(Here.Font.body(16, weight: .semibold))
                            .foregroundColor(Here.Color.ink)
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Here.Color.stone)
                            Text(post.locationName)
                                .font(Here.Font.mono(12))
                                .foregroundColor(Here.Color.stone)
                        }
                    }
                    Spacer()
                    Text(post.timeAgo)
                        .font(Here.Font.body(13))
                        .foregroundColor(Here.Color.stone)
                }
                
                // Caption
                Text(post.caption)
                    .font(Here.Font.body(16))
                    .foregroundColor(Here.Color.ink)
                    .lineSpacing(3)
                
                // Photo placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                        .fill(Here.Color.cloud)
                        .frame(height: 250)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(Here.Color.stone.opacity(0.5))
                        Text("foto")
                            .font(Here.Font.body(13))
                            .foregroundColor(Here.Color.stone.opacity(0.5))
                    }
                }
                
                // Who's joined
                if let joined = post.joinedUsers, !joined.isEmpty {
                    VStack(alignment: .leading, spacing: Here.Spacing.xs) {
                        Text("dabei")
                            .font(Here.Font.body(12, weight: .medium))
                            .foregroundColor(Here.Color.stone)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 8) {
                            StackedAvatarsView(users: joined, size: 28)
                            Text("\(joined.count) \(joined.count == 1 ? "person" : "personen")")
                                .font(Here.Font.body(14))
                                .foregroundColor(Here.Color.stone)
                        }
                    }
                    .padding(.top, Here.Spacing.xs)
                }
                
                Divider()
                    .padding(.vertical, Here.Spacing.xs)
                
                // Actions
                VStack(spacing: Here.Spacing.md) {
                    // Join Button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                            feedVM.toggleJoin(postID: post.id, userID: authVM.currentUser.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: currentUserJoined ? "checkmark.circle.fill" : "person.badge.plus")
                                .font(.system(size: 16, weight: .medium))
                            Text(currentUserJoined ? "Du bist dabei ✓" : "Joinen")
                                .font(Here.Font.body(16, weight: .semibold))
                        }
                        .foregroundColor(currentUserJoined ? Here.Color.white : Here.Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(currentUserJoined ? Here.Color.ink : Here.Color.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                                .strokeBorder(currentUserJoined ? Here.Color.ink : Here.Color.border, lineWidth: 1.5)
                        )
                    }
                    
                    // Reactions
                    VStack(alignment: .leading, spacing: Here.Spacing.sm) {
                        Text("reaktionen")
                            .font(Here.Font.body(12, weight: .medium))
                            .foregroundColor(Here.Color.stone)
                            .textCase(.uppercase)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(reactionGroups, id: \.emoji) { group in
                                    ReactionBadge(
                                        emoji: group.emoji,
                                        count: group.count,
                                        isSelected: group.userReacted
                                    ) {
                                        feedVM.addReaction(postID: post.id, emoji: group.emoji, userID: authVM.currentUser.id)
                                    }
                                }
                                
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        showReactionPicker.toggle()
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Here.Color.stone)
                                        .padding(10)
                                        .background(Here.Color.cloud)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        
                        if showReactionPicker {
                            MapEmojiPickerRow { emoji in
                                feedVM.addReaction(postID: post.id, emoji: emoji, userID: authVM.currentUser.id)
                                withAnimation { showReactionPicker = false }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    
                    // Comments
                    Button {
                        showComments = true
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16, weight: .medium))
                            Text(post.comments.isEmpty ? "Kommentieren" : "\(post.comments.count) Kommentare anzeigen")
                                .font(Here.Font.body(16, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Here.Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, Here.Spacing.md)
                        .background(Here.Color.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
                    }
                }
                
            }
            .padding(Here.Spacing.lg)
        }
        .background(Here.Color.white)
        .navigationTitle("aktivität")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Map Emoji Picker
struct MapEmojiPickerRow: View {
    let onSelect: (String) -> Void
    private let emojis = ["🔥","❤️","👀","😂","🙌","☕","🏔","🛹","✨","💪"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .padding(10)
                            .background(Here.Color.cloud)
                            .clipShape(RoundedRectangle(cornerRadius: Here.Radius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    MapFeedView()
        .environmentObject(FeedViewModel())
        .environmentObject(LocationService())
        .environmentObject(AuthViewModel())
}
