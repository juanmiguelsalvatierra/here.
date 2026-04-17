import SwiftUI

// MARK: - Here Design System
// Aesthetic: Raw minimalism — black ink on white paper.
// No gradients. No color. Just weight, space, and type.
// Inspired by: BeReal's authenticity, Braun's industrial design.

enum Here {

    // MARK: Colors
    enum Color {
        static let ink       = SwiftUI.Color(hex: "#0D0D0D")     // near-black
        static let inkLight  = SwiftUI.Color(hex: "#1A1A1A")
        static let stone     = SwiftUI.Color(hex: "#8A8A8A")     // secondary text
        static let cloud     = SwiftUI.Color(hex: "#F5F5F3")     // background
        static let white     = SwiftUI.Color.white
        static let border    = SwiftUI.Color(hex: "#E8E8E6")
        static let accent    = SwiftUI.Color(hex: "#0D0D0D")     // same ink — accent = bold
        static let danger    = SwiftUI.Color(hex: "#CC3333")
        static let success   = SwiftUI.Color(hex: "#1A6B3A")
    }

    // MARK: Typography
    enum Font {
        // Display — used for headings
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        // Body — readable, clean
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }

        // Mono — coordinates, codes
        static func mono(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .monospaced)
        }
    }

    // MARK: Spacing
    enum Spacing {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 36
        static let xxl:  CGFloat = 56
    }

    // MARK: Corner Radius
    enum Radius {
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 14
        static let lg:  CGFloat = 20
        static let full: CGFloat = 999
    }
}

// MARK: - Color hex extension
extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Reusable Modifiers
struct HerePrimaryButton: ViewModifier {
    var isDestructive: Bool = false
    func body(content: Content) -> some View {
        content
            .font(Here.Font.body(15, weight: .semibold))
            .foregroundColor(isDestructive ? Here.Color.danger : Here.Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isDestructive ? Here.Color.danger : Here.Color.ink)
            .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
    }
}

struct HereSecondaryButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Here.Font.body(15, weight: .medium))
            .foregroundColor(Here.Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Here.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                    .strokeBorder(Here.Color.border, lineWidth: 1.5)
            )
    }
}

extension View {
    func herePrimary(destructive: Bool = false) -> some View { modifier(HerePrimaryButton(isDestructive: destructive)) }
    func hereSecondary() -> some View { modifier(HereSecondaryButton()) }
}

// MARK: - Avatar View
struct AvatarView: View {
    let user: User
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: user.avatarColor))
            Text(String(user.displayName.prefix(1)).uppercased())
                .font(Here.Font.display(size * 0.38, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stacked Avatars
struct StackedAvatarsView: View {
    let users: [User]
    var maxShown: Int = 4
    var size: CGFloat = 28

    var body: some View {
        let shown = Array(users.prefix(maxShown))
        HStack(spacing: -(size * 0.3)) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, user in
                AvatarView(user: user, size: size)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .zIndex(Double(shown.count - idx))
            }
            if users.count > maxShown {
                ZStack {
                    Circle().fill(Here.Color.border)
                    Text("+\(users.count - maxShown)")
                        .font(Here.Font.mono(size * 0.3))
                        .foregroundColor(Here.Color.stone)
                }
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
            }
        }
    }
}

// MARK: - Emoji Reaction Badge
struct ReactionBadge: View {
    let emoji: String
    let count: Int
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji).font(.system(size: 14))
                if count > 0 {
                    Text("\(count)")
                        .font(Here.Font.mono(12))
                        .foregroundColor(isSelected ? Here.Color.white : Here.Color.ink)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Here.Color.ink : Here.Color.cloud)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Here.Color.ink : Here.Color.border,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}
