# Map Interaktionen - Feature Update

## Übersicht

Die Karten-Ansicht wurde erweitert, sodass du jetzt direkt von der Map aus mit Posts interagieren kannst!

## Neue Funktionen

### 1. **Interaktive Map Post Card**
Wenn du auf einen Pin auf der Karte tippst, erscheint eine Karte mit:
- ✅ **Join Button** - Direkt joinen/verlassen
- ✅ **Comment Button** - Kommentare anzeigen und schreiben
- ✅ **Reactions Count** - Anzahl der Reaktionen sehen

### 2. **Vollständige Post-Detailansicht**
Tippe auf den "Kommentieren" Button oder die Karte, um eine vollständige Detail-Ansicht zu öffnen mit:
- ✅ **Großer Join Button** - "Du bist dabei ✓" / "Joinen"
- ✅ **Reaktionen hinzufügen** - Emoji-Picker mit allen Reaktionen
- ✅ **Kommentare anzeigen** - Öffnet die Kommentar-View
- ✅ **Wer ist dabei** - Liste aller Teilnehmer
- ✅ **Foto-Vorschau** - Placeholder für Fotos

## User Flow

```
1. User öffnet Map-Tab
   ↓
2. Sieht Pins von Freunden auf der Karte
   ↓
3. Tippt auf einen Pin
   ↓
4. Kleine Karte erscheint am unteren Rand mit:
   - Post-Info
   - Join Button (sofort joinen möglich!)
   - Comment Button
   - Reactions Count
   ↓
5. [Optional] Tippt auf Comment Button
   ↓
6. Vollständige Detail-Ansicht öffnet sich als Sheet
   ↓
7. User kann:
   - Joinen/verlassen
   - Reaktionen hinzufügen
   - Kommentare lesen
   - Kommentare schreiben
```

## Code-Struktur

### MapPostCard (Bottom Sheet Peek)
- Kleine Vorschau-Karte am unteren Bildschirmrand
- Schnelle Aktionen: Join & Comment
- Tap öffnet vollständige Detail-Ansicht

### MapPostDetailView (Full Screen Sheet)
- Vollständige Post-Ansicht
- Alle Interaktionen möglich:
  - Join/Leave
  - Add Reactions
  - View/Add Comments
- Styled im "Here" Design

### MapEmojiPickerRow
- Emoji-Auswahl für Reaktionen
- Horizontal scrollbar
- Erweiterbarer Picker

## Implementierung

### MapFeedView.swift
```swift
// MapPostCard hat jetzt:
@EnvironmentObject var feedVM: FeedViewModel
@EnvironmentObject var authVM: AuthViewModel
@State private var showFullPost = false

// Join Button
Button {
    feedVM.toggleJoin(postID: post.id, userID: authVM.currentUser.id)
} label: { ... }

// Comment Button
Button {
    showFullPost = true
} label: { ... }

// Sheet für Detail-View
.sheet(isPresented: $showFullPost) {
    NavigationStack {
        MapPostDetailView(post: post)
    }
}
```

### MapPostDetailView
```swift
struct MapPostDetailView: View {
    let post: LocationPost
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var authVM: AuthViewModel
    
    // Große Join-Button
    // Reaktionen mit Picker
    // Kommentar-Button öffnet CommentsViewStyled
}
```

## Features im Detail

### Join-Funktionalität
- **Quick Join** in der kleinen Karte (MapPostCard)
- **Großer Join Button** in der Detail-Ansicht
- Zeigt Status: "dabei" vs "joinen"
- Animation beim Toggle
- Updates in Echtzeit (shared ViewModel)

### Kommentare
- Button zeigt Anzahl der Kommentare
- Öffnet `CommentsViewStyled` als separates Sheet
- Vollständige Kommentar-Funktionalität:
  - Lesen
  - Schreiben
  - Löschen (eigene)

### Reaktionen
- Anzeige der Reaktions-Anzahl in der kleinen Karte
- Vollständiger Emoji-Picker in der Detail-Ansicht
- Zeigt alle bestehenden Reaktionen
- User kann eigene Reaktion ändern

## Design-Entscheidungen

### Warum zwei Ebenen?

1. **MapPostCard (klein)**
   - Schnelle Übersicht
   - Sofort handeln (Join)
   - Keine Navigation weg von der Karte

2. **MapPostDetailView (groß)**
   - Vollständige Informationen
   - Alle Interaktionsmöglichkeiten
   - Fokus auf eine Aktivität

### Navigation Flow
- Kleine Karte: Erscheint/verschwindet mit Tap auf Pin
- Detail-View: Sheet-Präsentation (kann geschlossen werden)
- Kommentare: Nested Sheet (zweite Ebene)

## Verwendete ViewModels

### FeedViewModel
```swift
// Wird in der Map verwendet für:
- toggleJoin(postID:userID:)
- addReaction(postID:emoji:userID:)
- addComment(postID:text:user:)
- deleteComment(postID:commentID:)
```

### AuthViewModel
```swift
// Wird verwendet für:
- currentUser (zum Joinen)
- User-Authentifizierung
```

## Testing

Test mit Mock-Daten:
```swift
#Preview {
    NavigationStack {
        MapPostDetailView(post: MockData.posts[1])
            .environmentObject(FeedViewModel())
            .environmentObject(AuthViewModel())
    }
}
```

## Nächste Schritte (Optional)

- [ ] Foto-Upload in Map-Posts
- [ ] Filter für Map (nur Freunde, nur heute, etc.)
- [ ] Cluster für nahe beieinander liegende Posts
- [ ] Routing zum Post-Location
- [ ] "Ich bin auf dem Weg" Status
- [ ] Live-Updates wenn Freund joint

## Zusammenfassung

✅ Map-Posts sind jetzt vollständig interaktiv
✅ Join-Funktionalität direkt auf der Karte
✅ Kommentare von der Karte aus möglich
✅ Reaktionen können hinzugefügt werden
✅ Nahtlose Integration mit bestehendem Feed
✅ Konsistentes "Here" Design

Die Map ist jetzt nicht mehr nur eine Übersicht, sondern ein vollwertiges soziales Feature! 🗺️✨
