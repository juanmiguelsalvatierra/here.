# here. — Swift iOS App

> *sei wo du bist.* — Teile deinen echten Standort mit Freunden, ohne Filter, ohne Algorithmus.

## Philosophie

here. ist gegen infinite scroll. Gegen Performances. Für echte Momente, echte Orte, echte Menschen.
Das Design (schwarz/weiß, keine Icons-Overload, keine bunten Farben) unterstützt diese Mission — es gibt nichts zu verstecken.

---

## Screens

| Screen | Funktion |
|--------|----------|
| **Karte** | Interaktive Map mit Live-Pins aller Freundes-Posts. Tap = Preview-Card. „Jetzt teilen"-CTA. |
| **Feed** | Chronologischer Feed mit Post-Cards. Reaktionen, Join-Button, Favoriten-Heart. |
| **Neuer Post** | Photo Picker + Caption + automatischer Standort. Push an Freunde nach dem Posten. |
| **Gespeichert** | Lieblingsorte (Grid) & gespeicherte Momente (Foto-Grid). |
| **Profil** | Eigene Posts, Stats, Einstellungen, Logout. |
| **Benachrichtigungen** | Sheet mit ungelesenen Aktivitäten der Freunde. |

---

## Architektur

```
HereApp/
├── HereApp.swift           # App entry, environment setup
├── DesignSystem.swift      # Farben, Fonts, Abstände, Komponenten
├── Info.plist              # Berechtigungen
│
├── Models/
│   └── Models.swift        # User, LocationPost, Purchase, FavoritePlace, …
│
├── ViewModels/
│   └── ViewModels.swift    # AuthVM, FeedVM, LocationService, FavoritesVM, NewPostVM
│
└── Views/
    ├── OnboardingView.swift
    ├── MainTabView.swift    # Custom Tab Bar
    ├── MapFeedView.swift    # Karte + MapKit Annotations
    ├── FeedView.swift       # Post Feed + Reactions
    ├── NewPostView.swift    # Moment teilen
    ├── FavoritesView.swift  # Orte & Momente
    └── ProfileView.swift    # Profil + Notifications
```

**Pattern**: MVVM mit `@EnvironmentObject` für globalen State.

---

## Features

### ✅ Implementiert
- [ ] Interaktive Karte (MapKit) mit Post-Pins und Preview-Cards
- [ ] Feed mit Post-Cards, Reaktionen (Emoji-Picker), Join-Funktion
- [ ] Gestapelte Avatar-Anzeige (wer ist gerade dabei)
- [ ] Neuer Post: Foto wählen (PhotosUI) + Caption + Standort
- [ ] Benachrichtigungsanzeige (Badge + Sheet)
- [ ] Lieblingsorte & Lieblingsmomente speichern/löschen
- [ ] Profil mit eigenen Posts und Stats
- [ ] Minimalistisches Design-System (here. Design Language)
- [ ] Animations mit SwiftUI spring()
- [ ] Mock-Daten für alle Screens

### 🔜 Nächste Schritte (Backend)
- [ ] Firebase Auth / Supabase für echte User
- [ ] Firestore / PostgreSQL für Posts & Reactions
- [ ] Firebase Cloud Messaging für Push-Benachrichtigungen
- [ ] Cloud Storage für Fotos
- [ ] WebSocket / Firestore Listener für Live-Updates

---

## Setup

### Voraussetzungen
- Xcode 15+
- iOS 17+ Deployment Target
- Swift 5.9+

### Starten
1. Projekt klonen / öffnen: `HereApp.xcodeproj`
2. Bundle ID in Signing & Capabilities setzen
3. Location & Camera Capability aktivieren
4. Gerät oder Simulator wählen → Run

### Permissions (Info.plist bereits konfiguriert)
- `NSLocationWhenInUseUsageDescription`
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

---

## Design-Prinzipien

```
Farbe:   Schwarz (#0D0D0D) · Weiß · Stone (#8A8A8A) · Cloud (#F5F5F3)
Schrift: SF Rounded (Display) · SF Pro (Body) · SF Mono (Koordinaten)
Radius:  8 · 14 · 20 · 999 (Pill)
Spacing: 4 · 8 · 16 · 24 · 36 · 56
```

Kein Farbverlauf. Kein Drop-Shadow-Overload. Kein Dark Mode — bewusste Entscheidung für Klarheit.
