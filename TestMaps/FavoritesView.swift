import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favVM: FavoritesViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @State private var selectedSegment: Int = 0
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Here.Spacing.lg) {

                    // Header
                    Text("gespeichert")
                        .font(Here.Font.display(28, weight: .bold))
                        .foregroundColor(Here.Color.ink)
                        .padding(.top, 56)

                    // Segment control
                    HerePillSegment(
                        options: ["orte", "momente"],
                        selected: $selectedSegment
                    )

                    if selectedSegment == 0 {
                        FavoritePlacesGrid(places: favVM.places) { id in
                            favVM.removePlace(id: id)
                        }
                    } else {
                        FavoriteMomentsGrid(posts: feedVM.posts.filter { $0.isFavorited })
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, Here.Spacing.lg)
            }
            .background(Here.Color.white)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Pill Segment
struct HerePillSegment: View {
    let options: [String]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selected = idx
                    }
                } label: {
                    Text(option)
                        .font(Here.Font.body(14, weight: selected == idx ? .semibold : .regular))
                        .foregroundColor(selected == idx ? Here.Color.white : Here.Color.stone)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selected == idx ? Here.Color.ink : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Here.Color.cloud))
    }
}

// MARK: - Places Grid
struct FavoritePlacesGrid: View {
    let places: [FavoritePlace]
    let onDelete: (String) -> Void

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        if places.isEmpty {
            EmptyStateView(icon: "mappin.and.ellipse", text: "noch keine lieblingsorte")
        } else {
            LazyVGrid(columns: columns, spacing: Here.Spacing.sm) {
                ForEach(places) { place in
                    PlaceCard(place: place, onDelete: { onDelete(place.id) })
                }
            }
        }
    }
}

struct PlaceCard: View {
    let place: FavoritePlace
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Map thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: Here.Radius.sm, style: .continuous)
                    .fill(Here.Color.cloud)
                    .frame(height: 100)
                Image(systemName: "mappin")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Here.Color.stone)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(Here.Font.body(13, weight: .semibold))
                    .foregroundColor(Here.Color.ink)
                    .lineLimit(1)

                Text("\(place.visitCount)× besucht")
                    .font(Here.Font.mono(10))
                    .foregroundColor(Here.Color.stone)
            }
        }
        .padding(Here.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                .fill(Here.Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous)
                        .strokeBorder(Here.Color.border, lineWidth: 1)
                )
        )
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("entfernen", systemImage: "trash")
            }
        }
    }
}

// MARK: - Moments Grid
struct FavoriteMomentsGrid: View {
    let posts: [LocationPost]

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        if posts.isEmpty {
            EmptyStateView(icon: "heart", text: "noch keine gespeicherten momente")
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(posts) { post in
                    ZStack(alignment: .bottomLeading) {
                        Rectangle()
                            .fill(Here.Color.cloud)
                            .aspectRatio(1, contentMode: .fit)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author?.displayName ?? "")
                                .font(Here.Font.body(9, weight: .semibold))
                                .foregroundColor(.white)
                            Text(post.locationName)
                                .font(Here.Font.mono(8))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(6)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: Here.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Here.Color.stone.opacity(0.4))
            Text(text)
                .font(Here.Font.body(14))
                .foregroundColor(Here.Color.stone)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Here.Spacing.xxl)
    }
}

#Preview {
    FavoritesView()
        .environmentObject(FavoritesViewModel())
        .environmentObject(FeedViewModel())
}
