import Foundation
import CoreLocation
import SwiftUI

// MARK: - User
struct User: Identifiable, Codable, Equatable {
    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var avatarColor: String        // fallback hex color
    var bio: String
    var friendIDs: [String]

    static let preview = User(
        id: "u1",
        username: "lena.m",
        displayName: "Lena Müller",
        avatarURL: nil,
        avatarColor: "#1A1A1A",
        bio: "always outside",
        friendIDs: ["u2", "u3", "u4"]
    )
}

// MARK: - Location Post
struct LocationPost: Identifiable, Codable {
    let id: String
    let authorID: String
    var author: User?
    var caption: String
    var imageURL: String?
    var coordinate: PostCoordinate
    var locationName: String
    var timestamp: Date
    var reactions: [Reaction]
    var joinedUserIDs: [String]
    var joinedUsers: [User]?
    var comments: [Comment] = []
    var visibility: PostVisibility = .friends
    var isFavorited: Bool = false

    var timeAgo: String {
        let diff = Date().timeIntervalSince(timestamp)
        switch diff {
        case ..<60:        return "just now"
        case ..<3600:      return "\(Int(diff/60))m ago"
        case ..<86400:     return "\(Int(diff/3600))h ago"
        default:           return "\(Int(diff/86400))d ago"
        }
    }
}

struct PostCoordinate: Codable {
    var latitude: Double
    var longitude: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Reaction
struct Reaction: Identifiable, Codable {
    let id: String
    let userID: String
    var emoji: String
    var timestamp: Date
}

// MARK: - Comment
struct Comment: Identifiable, Codable {
    let id: String
    let userID: String
    var user: User?
    var text: String
    var timestamp: Date
    
    var timeAgo: String {
        let diff = Date().timeIntervalSince(timestamp)
        switch diff {
        case ..<60:        return "gerade eben"
        case ..<3600:      return "vor \(Int(diff/60))m"
        case ..<86400:     return "vor \(Int(diff/3600))h"
        default:           return "vor \(Int(diff/86400))d"
        }
    }
}

// MARK: - Post Visibility
enum PostVisibility: String, Codable {
    case friends  = "friends"   // all mutual friends
    case selected = "selected"  // specific chosen friends
    case city     = "public"    // everyone (city-level)

    var label: String {
        switch self {
        case .friends:  return "Freunde"
        case .selected: return "Auswahl"
        case .city:     return "Stadt"
        }
    }
    var icon: String {
        switch self {
        case .friends:  return "person.2"
        case .selected: return "person.badge.plus"
        case .city:     return "building.2"
        }
    }
}

// MARK: - Friendship
struct Friendship: Identifiable, Codable {
    let id:          String
    let requesterID: String
    let addresseeID: String
    var status:      String   // "pending" | "accepted"
    var createdAt:   Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case createdAt   = "created_at"
    }
}

// MARK: - Favorite Place
struct FavoritePlace: Identifiable, Codable {
    let id: String
    var name: String
    var coordinate: PostCoordinate
    var coverImageURL: String?
    var visitCount: Int
    var lastVisited: Date?
    var note: String
}

// MARK: - Favorite Activity / Photo
struct FavoriteActivity: Identifiable, Codable {
    let id: String
    var postID: String
    var imageURL: String?
    var caption: String
    var locationName: String
    var savedAt: Date
}

// MARK: - Notification
struct HereNotification: Identifiable, Codable {
    let id: String
    var type: NotificationType
    var fromUser: User?
    var postID: String?
    var message: String
    var timestamp: Date
    var isRead: Bool

    enum NotificationType: String, Codable {
        case friendPosted
        case friendJoined
        case reaction
        case newFriend
    }
}

// MARK: - Mock Data
enum MockData {
    static let users: [User] = [
        User(id: "u1", username: "lena.m",    displayName: "Lena",    avatarURL: nil, avatarColor: "#1A1A1A", bio: "always outside",    friendIDs: ["u2","u3","u4"]),
        User(id: "u2", username: "felix.k",   displayName: "Felix",   avatarURL: nil, avatarColor: "#2D6A4F", bio: "coffee & bikes",    friendIDs: ["u1","u3"]),
        User(id: "u3", username: "sara.b",    displayName: "Sara",    avatarURL: nil, avatarColor: "#9B2335", bio: "hiker",             friendIDs: ["u1","u2","u4"]),
        User(id: "u4", username: "max.w",     displayName: "Max",     avatarURL: nil, avatarColor: "#4A4E69", bio: "skate or die",      friendIDs: ["u1","u3"]),
        User(id: "u5", username: "julia.h",   displayName: "Julia",   avatarURL: nil, avatarColor: "#B5838D", bio: "art & sun",         friendIDs: ["u1"]),
    ]

    static let posts: [LocationPost] = [
        LocationPost(
            id: "p1", authorID: "u2",
            author: users[1],
            caption: "Best coffee in town, kein Witz ☕",
            imageURL: nil,
            coordinate: PostCoordinate(latitude: 48.2085, longitude: 16.3725),
            locationName: "Café Central, Wien",
            timestamp: Date().addingTimeInterval(-1200),
            reactions: [
                Reaction(id: "r1", userID: "u1", emoji: "🔥", timestamp: Date()),
                Reaction(id: "r2", userID: "u3", emoji: "☕", timestamp: Date()),
            ],
            joinedUserIDs: ["u3"],
            joinedUsers: [users[2]],
            comments: [
                Comment(id: "c1", userID: "u1", user: users[0], text: "Ich bin dabei! 👍", timestamp: Date().addingTimeInterval(-900))
            ]
        ),
        LocationPost(
            id: "p2", authorID: "u3",
            author: users[2],
            caption: "Auf dem Gipfel. Kein Netz, endlich frei 🏔",
            imageURL: nil,
            coordinate: PostCoordinate(latitude: 47.4219, longitude: 13.6224),
            locationName: "Dachstein, Steiermark",
            timestamp: Date().addingTimeInterval(-5400),
            reactions: [
                Reaction(id: "r3", userID: "u1", emoji: "🏔", timestamp: Date()),
                Reaction(id: "r4", userID: "u2", emoji: "💪", timestamp: Date()),
                Reaction(id: "r5", userID: "u4", emoji: "🔥", timestamp: Date()),
            ],
            joinedUserIDs: ["u4", "u1"],
            joinedUsers: [users[3], users[0]],
            comments: [
                Comment(id: "c2", userID: "u4", user: users[3], text: "Wahnsinn! Wie lange wart ihr unterwegs?", timestamp: Date().addingTimeInterval(-3000)),
                Comment(id: "c3", userID: "u1", user: users[0], text: "Die Aussicht ist mega!", timestamp: Date().addingTimeInterval(-2500))
            ]
        ),
        LocationPost(
            id: "p3", authorID: "u4",
            author: users[3],
            caption: "Skatepark läuft heute richtig gut 🛹",
            imageURL: nil,
            coordinate: PostCoordinate(latitude: 48.1920, longitude: 16.3667),
            locationName: "Skatepark Praterstern",
            timestamp: Date().addingTimeInterval(-9000),
            reactions: [Reaction(id: "r6", userID: "u2", emoji: "🛹", timestamp: Date())],
            joinedUserIDs: [],
            joinedUsers: [],
            comments: []
        ),
    ]

    static let favoritePlaces: [FavoritePlace] = [
        FavoritePlace(id: "fp1", name: "Dachstein", coordinate: PostCoordinate(latitude: 47.4219, longitude: 13.6224), coverImageURL: nil, visitCount: 3, lastVisited: Date().addingTimeInterval(-86400*5), note: "Immer wieder"),
        FavoritePlace(id: "fp2", name: "Café Central", coordinate: PostCoordinate(latitude: 48.2085, longitude: 16.3725), coverImageURL: nil, visitCount: 12, lastVisited: Date().addingTimeInterval(-86400*2), note: "Montags am besten"),
    ]

    static let notifications: [HereNotification] = [
        HereNotification(id: "n1", type: .friendPosted, fromUser: users[1], postID: "p1", message: "Felix ist gerade beim Café Central", timestamp: Date().addingTimeInterval(-1200), isRead: false),
        HereNotification(id: "n2", type: .friendJoined, fromUser: users[2], postID: "p2", message: "Sara hat deinem Spot gejoint", timestamp: Date().addingTimeInterval(-3600), isRead: false),
        HereNotification(id: "n3", type: .reaction, fromUser: users[3], postID: "p3", message: "Max hat mit 🔥 reagiert", timestamp: Date().addingTimeInterval(-7200), isRead: true),
    ]
}
