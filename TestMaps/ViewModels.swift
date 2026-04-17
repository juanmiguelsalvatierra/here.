import Foundation
import SwiftUI
import Combine
import CoreLocation

// MARK: - Auth ViewModel
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = true   // set true for preview
    @Published var currentUser: User = MockData.users[0]
    @Published var errorMessage: String?

    func login(username: String, password: String) {
        // In production: call your auth API
        withAnimation(.spring()) { isLoggedIn = true }
    }

    func logout() {
        withAnimation { isLoggedIn = false }
    }
}

// MARK: - Feed ViewModel
class FeedViewModel: ObservableObject {
    @Published var posts: [LocationPost] = MockData.posts
    @Published var isLoading: Bool = false
    @Published var showNewPost: Bool = false
    @Published var notifications: [HereNotification] = MockData.notifications

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func toggleJoin(postID: String, userID: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        let joined = posts[idx].joinedUserIDs.contains(userID)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if joined {
                posts[idx].joinedUserIDs.removeAll { $0 == userID }
                posts[idx].joinedUsers?.removeAll { $0.id == userID }
            } else {
                posts[idx].joinedUserIDs.append(userID)
                if posts[idx].joinedUsers == nil { posts[idx].joinedUsers = [] }
                posts[idx].joinedUsers?.append(MockData.users[0])
            }
        }
    }

    func addReaction(postID: String, emoji: String, userID: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        // Remove existing reaction from same user
        posts[idx].reactions.removeAll { $0.userID == userID }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            posts[idx].reactions.append(
                Reaction(id: UUID().uuidString, userID: userID, emoji: emoji, timestamp: Date())
            )
        }
    }
    
    func addComment(postID: String, text: String, user: User) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let comment = Comment(
            id: UUID().uuidString,
            userID: user.id,
            user: user,
            text: text,
            timestamp: Date()
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            posts[idx].comments.append(comment)
        }
    }
    
    func deleteComment(postID: String, commentID: String) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            posts[idx].comments.removeAll { $0.id == commentID }
        }
    }

    func addPost(_ post: LocationPost) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            posts.insert(post, at: 0)
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

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = loc.coordinate
            self.reverseGeocode(loc)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse { startUpdating() }
    }

    private func reverseGeocode(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let p = placemarks?.first {
                let name = [p.name, p.locality].compactMap { $0 }.first ?? "Unbekannter Ort"
                DispatchQueue.main.async { self?.currentPlaceName = name }
            }
        }
    }
}

// MARK: - Favorites ViewModel
class FavoritesViewModel: ObservableObject {
    @Published var places: [FavoritePlace] = MockData.favoritePlaces
    @Published var activities: [FavoriteActivity] = []

    func savePlace(_ place: FavoritePlace) {
        withAnimation { places.append(place) }
    }

    func removePlace(id: String) {
        withAnimation { places.removeAll { $0.id == id } }
    }

    func saveActivity(from post: LocationPost) {
        let act = FavoriteActivity(
            id: UUID().uuidString,
            postID: post.id,
            imageURL: post.imageURL,
            caption: post.caption,
            locationName: post.locationName,
            savedAt: Date()
        )
        withAnimation { activities.append(act) }
    }
}

// MARK: - New Post ViewModel
class NewPostViewModel: ObservableObject {
    @Published var caption: String = ""
    @Published var selectedImage: UIImage?
    @Published var locationName: String = ""
    @Published var isPosting: Bool = false
    @Published var didPost: Bool = false

    func submit(author: User, coordinate: CLLocationCoordinate2D?, placeName: String, feed: FeedViewModel) {
        guard !caption.isEmpty else { return }
        isPosting = true

        let post = LocationPost(
            id: UUID().uuidString,
            authorID: author.id,
            author: author,
            caption: caption,
            imageURL: nil,
            coordinate: PostCoordinate(
                latitude: coordinate?.latitude ?? 48.2082,
                longitude: coordinate?.longitude ?? 16.3738
            ),
            locationName: placeName.isEmpty ? "Unbekannter Ort" : placeName,
            timestamp: Date(),
            reactions: [],
            joinedUserIDs: [],
            joinedUsers: []
        )

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            feed.addPost(post)
            self?.isPosting = false
            self?.didPost = true
        }
    }

    func reset() {
        caption = ""
        selectedImage = nil
        locationName = ""
        didPost = false
    }
}
// MARK: - Comment ViewModel
class CommentViewModel: ObservableObject {
    @Published var commentText: String = ""
    @Published var isCommenting: Bool = false
    
    var canSubmit: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func submitComment(postID: String, user: User, feed: FeedViewModel) {
        guard canSubmit else { return }
        
        feed.addComment(postID: postID, text: commentText, user: user)
        commentText = ""
    }
    
    func reset() {
        commentText = ""
        isCommenting = false
    }
}

