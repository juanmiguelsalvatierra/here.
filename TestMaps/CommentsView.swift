import SwiftUI

// MARK: - Comments View
struct CommentsView: View {
    let post: LocationPost
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var commentViewModel = CommentViewModel()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Kommentare")
                    .font(.headline)
                Spacer()
                Text("\(post.comments.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            Divider()
            
            // Comments List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if post.comments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Noch keine Kommentare")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Sei der Erste, der kommentiert!")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(post.comments) { comment in
                            CommentRow(
                                comment: comment,
                                canDelete: comment.userID == authViewModel.currentUser.id,
                                onDelete: {
                                    feedViewModel.deleteComment(postID: post.id, commentID: comment.id)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Comment Input
            HStack(spacing: 12) {
                // User Avatar
                AvatarView(user: authViewModel.currentUser, size: 32)
                
                // Text Field
                TextField("Kommentar hinzufügen...", text: $commentViewModel.commentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
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
                        .foregroundStyle(commentViewModel.canSubmit ? Color.accentColor : .secondary)
                }
                .disabled(!commentViewModel.canSubmit)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Kommentare")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    let canDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            if let user = comment.user {
                AvatarView(user: user, size: 36)
            } else {
                Circle()
                    .fill(.gray)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text("?")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Username and time
                HStack(spacing: 8) {
                    Text(comment.user?.displayName ?? "Unbekannt")
                        .font(.subheadline.bold())
                    
                    Text(comment.timeAgo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if canDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                // Comment text
                Text(comment.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Comment Button (for Post Card)
struct CommentButton: View {
    let post: LocationPost
    @State private var showComments = false
    
    var body: some View {
        Button {
            showComments = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .font(.subheadline)
                if post.comments.count > 0 {
                    Text("\(post.comments.count)")
                        .font(.caption.bold())
                }
            }
        }
        .foregroundStyle(.primary)
        .sheet(isPresented: $showComments) {
            NavigationStack {
                CommentsView(post: post)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Schließen") {
                                showComments = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CommentsView(post: MockData.posts[1])
            .environmentObject(FeedViewModel())
            .environmentObject(AuthViewModel())
    }
}
