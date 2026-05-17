import Foundation
import SwiftUI
import Combine
import CoreLocation

// MARK: - Feed ViewModel

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts:         [LocationPost]      = []
    @Published var isLoading:     Bool                = false
    @Published var errorMessage:  String?
    @Published var showNewPost:   Bool                = false
    @Published var notifications: [HereNotification] = []

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    // MARK: Fetch
    func fetchPosts() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await SupabaseClient.get("/rest/v1/posts", query: [
                URLQueryItem(name: "select", value: "*,profiles(*),reactions(*),post_joins(*,profiles(*)),comments(*,profiles(*))"),
                URLQueryItem(name: "order",  value: "created_at.desc"),
                URLQueryItem(name: "limit",  value: "50")
            ])
            let decoded = try JSONDecoder().decode([DBPost].self, from: data)
            posts = decoded.map { $0.toPost() }
        } catch {
            errorMessage = "Fehler beim Laden."
        }
    }

    // MARK: Create post
    func createPost(caption: String, coordinate: CLLocationCoordinate2D,
                    locationName: String, author: User,
                    visibility: PostVisibility = .friends,
                    audienceIDs: [String] = []) async throws {
        let data = try await SupabaseClient.post("/rest/v1/posts", body: [
            "author_id":     author.id,
            "caption":       caption,
            "latitude":      coordinate.latitude,
            "longitude":     coordinate.longitude,
            "location_name": locationName,
            "visibility":    visibility.rawValue
        ])
        let rows = try JSONDecoder().decode([DBNewPost].self, from: data)
        guard let row = rows.first else { return }
        // If selected visibility, insert audience rows
        if visibility == .selected && !audienceIDs.isEmpty {
            for uid in audienceIDs {
                try? await SupabaseClient.upsert("/rest/v1/post_audience",
                                                 body: ["post_id": row.id, "user_id": uid])
            }
        }
        let post = LocationPost(
            id: row.id, authorID: author.id, author: author,
            caption: caption, imageURL: nil,
            coordinate: PostCoordinate(latitude: coordinate.latitude,
                                       longitude: coordinate.longitude),
            locationName: locationName, timestamp: Date(),
            reactions: [], joinedUserIDs: [], joinedUsers: [],
            visibility: visibility
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            posts.insert(post, at: 0)
        }
    }

    // MARK: Toggle join  (optimistic)
    func toggleJoin(postID: String, userID: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        let isJoined = posts[idx].joinedUserIDs.contains(userID)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if isJoined {
                posts[idx].joinedUserIDs.removeAll { $0 == userID }
                posts[idx].joinedUsers?.removeAll   { $0.id == userID }
            } else {
                posts[idx].joinedUserIDs.append(userID)
            }
        }
        Task {
            do {
                if isJoined {
                    try await SupabaseClient.delete("/rest/v1/post_joins", query: [
                        URLQueryItem(name: "post_id", value: "eq.\(postID)"),
                        URLQueryItem(name: "user_id", value: "eq.\(userID)")
                    ])
                } else {
                    try await SupabaseClient.upsert("/rest/v1/post_joins",
                                                    body: ["post_id": postID, "user_id": userID])
                }
            } catch { await fetchPosts() }   // rollback on failure
        }
    }

    // MARK: Reaction  (optimistic upsert)
    func addReaction(postID: String, emoji: String, userID: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[idx].reactions.removeAll { $0.userID == userID }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            posts[idx].reactions.append(
                Reaction(id: UUID().uuidString, userID: userID, emoji: emoji, timestamp: Date())
            )
        }
        Task {
            try? await SupabaseClient.upsert("/rest/v1/reactions",
                                             body: ["post_id": postID, "user_id": userID, "emoji": emoji])
        }
    }

    // MARK: Add comment  (optimistic)
    func addComment(postID: String, text: String, user: User) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        let tempID  = "tmp-\(UUID().uuidString)"
        let comment = Comment(id: tempID, userID: user.id, user: user, text: trimmed, timestamp: Date())
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            posts[idx].comments.append(comment)
        }
        Task {
            do {
                let data = try await SupabaseClient.post("/rest/v1/comments",
                                                         body: ["post_id": postID, "user_id": user.id, "text": trimmed])
                let rows = try JSONDecoder().decode([DBCommentID].self, from: data)
                if let real = rows.first,
                   let i  = posts.firstIndex(where: { $0.id == postID }),
                   let ci = posts[i].comments.firstIndex(where: { $0.id == tempID }) {
                    posts[i].comments[ci] = Comment(id: real.id, userID: user.id,
                                                     user: user, text: trimmed, timestamp: Date())
                }
            } catch {
                if let i = posts.firstIndex(where: { $0.id == postID }) {
                    posts[i].comments.removeAll { $0.id == tempID }
                }
            }
        }
    }

    // MARK: Delete comment  (optimistic)
    func deleteComment(postID: String, commentID: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            posts[idx].comments.removeAll { $0.id == commentID }
        }
        Task {
            try? await SupabaseClient.delete("/rest/v1/comments", query: [
                URLQueryItem(name: "id", value: "eq.\(commentID)")
            ])
        }
    }

    func toggleFavorite(postID: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        withAnimation { posts[idx].isFavorited.toggle() }
    }

    func markAllRead() {
        for i in notifications.indices { notifications[i].isRead = true }
    }
}

// MARK: - New Post ViewModel

@MainActor
class NewPostViewModel: ObservableObject {
    @Published var caption:       String          = ""
    @Published var selectedImage: UIImage?
    @Published var isPosting:     Bool            = false
    @Published var didPost:       Bool            = false
    @Published var errorMessage:  String?
    @Published var visibility:    PostVisibility  = .friends
    @Published var audienceIDs:   Set<String>     = []

    func submit(author: User, coordinate: CLLocationCoordinate2D?,
                placeName: String, feed: FeedViewModel) {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPosting = true; errorMessage = nil
        let loc  = CLLocationCoordinate2D(latitude:  coordinate?.latitude  ?? 48.2082,
                                          longitude: coordinate?.longitude ?? 16.3738)
        let name = placeName.isEmpty ? "Unbekannter Ort" : placeName
        Task {
            do {
                try await feed.createPost(
                    caption: trimmed, coordinate: loc, locationName: name,
                    author: author, visibility: visibility,
                    audienceIDs: Array(audienceIDs)
                )
                didPost = true
            } catch {
                print("[here.] createPost error: \(error)")
                errorMessage = error.localizedDescription
            }
            isPosting = false
        }
    }

    func reset() {
        caption = ""; selectedImage = nil; didPost = false
        errorMessage = nil; visibility = .friends; audienceIDs = []
    }
}

// MARK: - Comment ViewModel

@MainActor
class CommentViewModel: ObservableObject {
    @Published var commentText: String = ""

    var canSubmit: Bool { !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func submitComment(postID: String, user: User, feed: FeedViewModel) {
        guard canSubmit else { return }
        feed.addComment(postID: postID, text: commentText, user: user)
        commentText = ""
    }
}

// MARK: - Location Service

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentPlaceName: String = "Aktueller Standort"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }
    func startUpdating()     { manager.startUpdatingLocation() }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async { self.currentLocation = loc.coordinate; self.reverseGeocode(loc) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse { startUpdating() }
    }

    private func reverseGeocode(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let p = placemarks?.first {
                let name = [p.name, p.locality].compactMap { $0 }.first ?? "Unbekannter Ort"
                DispatchQueue.main.async { self?.currentPlaceName = name }
            }
        }
    }
}

// MARK: - Favorites ViewModel

class FavoritesViewModel: ObservableObject {
    @Published var places:     [FavoritePlace]    = []
    @Published var activities: [FavoriteActivity] = []

    func savePlace(_ place: FavoritePlace) { withAnimation { places.append(place) } }
    func removePlace(id: String)           { withAnimation { places.removeAll { $0.id == id } } }

    func saveActivity(from post: LocationPost) {
        let act = FavoriteActivity(id: UUID().uuidString, postID: post.id, imageURL: post.imageURL,
                                   caption: post.caption, locationName: post.locationName, savedAt: Date())
        withAnimation { activities.append(act) }
    }
}

// MARK: - Friend ViewModel

@MainActor
class FriendViewModel: ObservableObject {
    @Published var friends:          [User]       = []
    @Published var incoming:         [Friendship] = []  // pending requests TO me
    @Published var searchResults:    [User]       = []
    @Published var isSearching:      Bool         = false
    @Published var errorMessage:     String?

    // Cache of friendship statuses for search results: userID → status/nil
    @Published var statusCache:      [String: String] = [:]

    // MARK: Load on login
    func refresh(userID: String) async {
        await withTaskGroup(of: Void.self) { g in
            g.addTask { await self.fetchFriends(userID: userID) }
            g.addTask { await self.fetchIncoming(userID: userID) }
        }
    }

    // MARK: Search users by username
    func search(query: String, myID: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            let data = try await SupabaseClient.get("/rest/v1/profiles", query: [
                URLQueryItem(name: "username", value: "ilike.*\(q)*"),
                URLQueryItem(name: "select",   value: "id,username,display_name,avatar_url,avatar_color"),
                URLQueryItem(name: "limit",    value: "20")
            ])
            let rows = try JSONDecoder().decode([DBProfileSlim].self, from: data)
            searchResults = rows.compactMap { $0.id == myID ? nil : $0.toUser() }
            await refreshStatusCache(myID: myID)
        } catch { errorMessage = "Suche fehlgeschlagen." }
    }

    // MARK: Send friend request
    func sendRequest(to userID: String, myID: String) async {
        do {
            _ = try await SupabaseClient.post("/rest/v1/friendships", body: [
                "requester_id": myID,
                "addressee_id": userID
            ])
            statusCache[userID] = "pending"
        } catch { errorMessage = "Anfrage fehlgeschlagen." }
    }

    // MARK: Accept incoming request
    func accept(friendshipID: String, requesterID: String) async {
        do {
            try await SupabaseClient.patch("/rest/v1/friendships",
                                           query: [URLQueryItem(name: "id", value: "eq.\(friendshipID)")],
                                           body: ["status": "accepted"])
            incoming.removeAll { $0.id == friendshipID }
            await fetchFriends(userID: SupabaseClient.token.map { _ in requesterID } ?? requesterID)
        } catch { errorMessage = "Annehmen fehlgeschlagen." }
    }

    // MARK: Decline / remove
    func remove(friendshipID: String) async {
        do {
            try await SupabaseClient.delete("/rest/v1/friendships", query: [
                URLQueryItem(name: "id", value: "eq.\(friendshipID)")
            ])
            incoming.removeAll  { $0.id == friendshipID }
            // also remove from friends if it was accepted
        } catch { errorMessage = "Entfernen fehlgeschlagen." }
    }

    func removeFriend(friendID: String, myID: String) async {
        do {
            try await SupabaseClient.delete("/rest/v1/friendships", query: [
                URLQueryItem(name: "or", value:
                    "(and(requester_id.eq.\(myID),addressee_id.eq.\(friendID)),and(requester_id.eq.\(friendID),addressee_id.eq.\(myID)))")
            ])
            friends.removeAll { $0.id == friendID }
            statusCache[friendID] = nil
        } catch { errorMessage = "Entfernen fehlgeschlagen." }
    }

    // MARK: - Private

    private func fetchFriends(userID: String) async {
        do {
            let data = try await SupabaseClient.get("/rest/v1/friendships", query: [
                URLQueryItem(name: "or",     value: "(requester_id.eq.\(userID),addressee_id.eq.\(userID))"),
                URLQueryItem(name: "status", value: "eq.accepted"),
                URLQueryItem(name: "select", value: "requester_id,addressee_id")
            ])
            let rows = try JSONDecoder().decode([DBFriendshipIDs].self, from: data)
            let ids  = rows.map { $0.requesterID == userID ? $0.addresseeID : $0.requesterID }
            guard !ids.isEmpty else { friends = []; return }
            let profileData = try await SupabaseClient.get("/rest/v1/profiles", query: [
                URLQueryItem(name: "id",     value: "in.(\(ids.joined(separator: ",")))"),
                URLQueryItem(name: "select", value: "id,username,display_name,avatar_url,avatar_color")
            ])
            let profiles = try JSONDecoder().decode([DBProfileSlim].self, from: profileData)
            friends = profiles.map { $0.toUser() }
        } catch {}
    }

    private func fetchIncoming(userID: String) async {
        do {
            let data = try await SupabaseClient.get("/rest/v1/friendships", query: [
                URLQueryItem(name: "addressee_id", value: "eq.\(userID)"),
                URLQueryItem(name: "status",       value: "eq.pending"),
                URLQueryItem(name: "select",       value: "id,requester_id,addressee_id,status,created_at")
            ])
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            incoming = try decoder.decode([Friendship].self, from: data)
        } catch {}
    }

    private func refreshStatusCache(myID: String) async {
        let ids = searchResults.map { $0.id }
        guard !ids.isEmpty else { return }
        do {
            let data = try await SupabaseClient.get("/rest/v1/friendships", query: [
                URLQueryItem(name: "or",     value: ids.map {
                    "(and(requester_id.eq.\(myID),addressee_id.eq.\($0)),and(requester_id.eq.\($0),addressee_id.eq.\(myID)))"
                }.joined(separator: ",")),
                URLQueryItem(name: "select", value: "requester_id,addressee_id,status")
            ])
            let rows = try JSONDecoder().decode([DBFriendshipStatus].self, from: data)
            for row in rows {
                let friendID = row.requesterID == myID ? row.addresseeID : row.requesterID
                statusCache[friendID] = row.status
            }
        } catch {}
    }
}

private struct DBFriendshipIDs: Decodable {
    let requesterID: String
    let addresseeID: String
    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"; case addresseeID = "addressee_id"
    }
}

private struct DBFriendshipStatus: Decodable {
    let requesterID: String; let addresseeID: String; let status: String
    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"; case addresseeID = "addressee_id"; case status
    }
}

private struct DBProfileSlim: Decodable {
    let id: String; let username: String
    let displayName: String?; let avatarUrl: String?; let avatarColor: String?
    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"; case avatarUrl = "avatar_url"; case avatarColor = "avatar_color"
    }
    func toUser() -> User {
        User(id: id, username: username, displayName: displayName ?? username,
             avatarURL: avatarUrl, avatarColor: avatarColor ?? "#1A1A1A", bio: "", friendIDs: [])
    }
}

// MARK: - DB decode models  (private to this file)

private struct DBPost: Decodable {
    let id: String; let authorId: String; let caption: String
    let imageUrl: String?; let latitude: Double; let longitude: Double
    let locationName: String; let createdAt: String
    let profiles:  DBProfile
    let reactions: [DBReaction]
    let postJoins: [DBJoin]
    let comments:  [DBComment]

    enum CodingKeys: String, CodingKey {
        case id, caption, latitude, longitude, reactions, comments, profiles
        case authorId     = "author_id"
        case imageUrl     = "image_url"
        case locationName = "location_name"
        case createdAt    = "created_at"
        case postJoins    = "post_joins"
    }

    func toPost() -> LocationPost {
        let iso  = ISO8601DateFormatter()
        let date = iso.date(from: createdAt) ?? Date()
        return LocationPost(
            id: id, authorID: authorId,
            author: profiles.toUser(),
            caption: caption, imageURL: imageUrl,
            coordinate: PostCoordinate(latitude: latitude, longitude: longitude),
            locationName: locationName, timestamp: date,
            reactions: reactions.map {
                Reaction(id: $0.id, userID: $0.userId, emoji: $0.emoji, timestamp: Date())
            },
            joinedUserIDs: postJoins.map { $0.userId },
            joinedUsers:   postJoins.compactMap { $0.profiles?.toUser() },
            comments:      comments.map { c in
                Comment(id: c.id, userID: c.userId, user: c.profiles?.toUser(),
                        text: c.text,
                        timestamp: iso.date(from: c.createdAt) ?? Date())
            }
        )
    }
}

private struct DBProfile: Decodable {
    let id: String; let username: String
    let displayName: String?; let avatarUrl: String?; let avatarColor: String?; let bio: String?
    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"; case avatarUrl = "avatar_url"; case avatarColor = "avatar_color"
    }
    func toUser() -> User {
        User(id: id, username: username, displayName: displayName ?? username,
             avatarURL: avatarUrl, avatarColor: avatarColor ?? "#1A1A1A", bio: bio ?? "", friendIDs: [])
    }
}

private struct DBReaction: Decodable {
    let id: String; let userId: String; let emoji: String
    enum CodingKeys: String, CodingKey { case id, emoji; case userId = "user_id" }
}

private struct DBJoin: Decodable {
    let userId: String; let profiles: DBProfile?
    enum CodingKeys: String, CodingKey { case profiles; case userId = "user_id" }
}

private struct DBComment: Decodable {
    let id: String; let userId: String; let text: String; let createdAt: String
    let profiles: DBProfile?
    enum CodingKeys: String, CodingKey {
        case id, text, profiles; case userId = "user_id"; case createdAt = "created_at"
    }
}

private struct DBCommentID: Decodable { let id: String }
private struct DBNewPost:    Decodable { let id: String }
