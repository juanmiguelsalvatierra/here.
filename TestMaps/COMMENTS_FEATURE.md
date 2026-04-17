# Kommentar- und Interaktionsfunktionen

## Übersicht

Die App unterstützt jetzt drei Hauptinteraktionen mit Posts:

### 1. **Join/Dazutragen** (bereits vorhanden)
Nutzer können zeigen, dass sie auch an diesem Ort sind oder sein werden.

```swift
// Verwendung:
feedViewModel.toggleJoin(postID: post.id, userID: currentUser.id)
```

### 2. **Reaktionen** (bereits vorhanden)
Nutzer können mit Emojis auf Posts reagieren.

```swift
// Verwendung:
feedViewModel.addReaction(postID: post.id, emoji: "🔥", userID: currentUser.id)
```

### 3. **Kommentare** (NEU)
Nutzer können bis zu 2 Kommentare pro Post schreiben.

```swift
// Kommentar hinzufügen:
feedViewModel.addComment(postID: post.id, text: "Toller Ort!", user: currentUser)

// Kommentar löschen:
feedViewModel.deleteComment(postID: post.id, commentID: comment.id)
```

## Implementierung

### Models (Models.swift)

**Comment Struktur:**
```swift
struct Comment: Identifiable, Codable {
    let id: String
    let userID: String
    var user: User?
    var text: String
    var timestamp: Date
    
    var timeAgo: String { ... }
}
```

**LocationPost erweitert:**
```swift
struct LocationPost: Identifiable, Codable {
    ...
    var comments: [Comment] = []  // NEU
    ...
}
```

### ViewModels (ViewModels.swift)

**FeedViewModel erweitert:**
```swift
class FeedViewModel: ObservableObject {
    // Kommentar hinzufügen
    func addComment(postID: String, text: String, user: User)
    
    // Kommentar löschen
    func deleteComment(postID: String, commentID: String)
}
```

**Neuer CommentViewModel:**
```swift
class CommentViewModel: ObservableObject {
    @Published var commentText: String = ""
    @Published var isCommenting: Bool = false
    
    var canSubmit: Bool { ... }
    
    func submitComment(postID: String, user: User, feed: FeedViewModel)
    func reset()
}
```

### Views (CommentsView.swift)

**CommentsView:**
- Vollständige Kommentaransicht mit ScrollView
- Zeigt alle Kommentare für einen Post
- Eingabefeld für neue Kommentare
- Löschen-Funktion für eigene Kommentare

**CommentButton:**
- Kompakter Button für Post-Cards
- Zeigt Anzahl der Kommentare
- Öffnet CommentsView als Sheet

**CommentRow:**
- Einzelne Kommentar-Darstellung
- Avatar, Username, Zeitstempel
- Löschen-Button (nur für eigene Kommentare)

## Integration in bestehende Views

### In FeedView oder Post Card:

```swift
HStack(spacing: 20) {
    // Join Button (bereits vorhanden)
    Button { 
        feedViewModel.toggleJoin(postID: post.id, userID: currentUser.id) 
    } label: {
        HStack {
            Image(systemName: post.joinedUserIDs.contains(currentUser.id) ? "person.fill.checkmark" : "person.badge.plus")
            Text("\(post.joinedUserIDs.count)")
        }
    }
    
    // Reaction Button (bereits vorhanden)
    Menu {
        ForEach(["🔥", "❤️", "👍", "😂", "😮", "🎉"], id: \.self) { emoji in
            Button(emoji) {
                feedViewModel.addReaction(postID: post.id, emoji: emoji, userID: currentUser.id)
            }
        }
    } label: {
        HStack {
            Image(systemName: "face.smiling")
            Text("\(post.reactions.count)")
        }
    }
    
    // Comment Button (NEU)
    CommentButton(post: post)
}
```

## Features

### ✅ Implementiert:
- Kommentare erstellen und anzeigen
- Kommentare löschen (nur eigene)
- Zeitstempel mit "vor X Minuten" Anzeige
- Animationen für neue Kommentare
- Leerer-Zustand wenn keine Kommentare vorhanden
- Zähler für Kommentaranzahl
- Avatar-Anzeige bei Kommentaren
- Mehrzeilige Texteingabe

### 🔮 Mögliche Erweiterungen:
- Limit von 2 Kommentaren pro User erzwingen
- Kommentar bearbeiten
- Kommentare mit Mentions (@username)
- Benachrichtigungen bei neuen Kommentaren
- Kommentar-Likes
- Verschachtelte Antworten (Threads)

## Beispiel-Verwendung

```swift
struct MyPostCardView: View {
    let post: LocationPost
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack {
            // Post content...
            
            HStack {
                // Join
                Button {
                    feedViewModel.toggleJoin(
                        postID: post.id, 
                        userID: authViewModel.currentUser.id
                    )
                } label: {
                    Label("\(post.joinedUserIDs.count)", 
                          systemImage: "person.badge.plus")
                }
                
                // Comments (NEU)
                CommentButton(post: post)
                
                // Reactions
                // ... existing code ...
            }
        }
    }
}
```

## Testing

Mock-Daten sind bereits in `MockData.posts` vorhanden:
- Post 1: 1 Kommentar
- Post 2: 2 Kommentare  
- Post 3: 0 Kommentare

Teste mit:
```swift
#Preview {
    NavigationStack {
        CommentsView(post: MockData.posts[1])
            .environmentObject(FeedViewModel())
            .environmentObject(AuthViewModel())
    }
}
```
