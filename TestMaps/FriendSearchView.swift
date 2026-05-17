import SwiftUI

struct FriendSearchView: View {
    @EnvironmentObject var authVM:   AuthViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Here.Color.white.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Here.Spacing.lg) {

                        // Search bar
                        HStack(spacing: Here.Spacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Here.Color.stone)
                            TextField("benutzername suchen…", text: $query)
                                .font(Here.Font.body(16))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: query) { _, q in
                                    Task { await friendVM.search(query: q, myID: authVM.currentUser.id) }
                                }
                        }
                        .padding(Here.Spacing.md)
                        .background(Here.Color.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))

                        // Search results
                        if !friendVM.searchResults.isEmpty {
                            SectionHeader("ergebnisse")
                            ForEach(friendVM.searchResults) { user in
                                UserRow(user: user,
                                        status: friendVM.statusCache[user.id],
                                        myID: authVM.currentUser.id)
                                Divider().padding(.leading, 44 + Here.Spacing.sm)
                            }
                        } else if friendVM.isSearching {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        }

                        // Incoming requests
                        if !friendVM.incoming.isEmpty {
                            SectionHeader("anfragen")
                            ForEach(friendVM.incoming) { req in
                                IncomingRow(friendship: req)
                                Divider().padding(.leading, 44 + Here.Spacing.sm)
                            }
                        }

                        // Friends list
                        if !friendVM.friends.isEmpty {
                            SectionHeader("\(friendVM.friends.count) freunde")
                            ForEach(friendVM.friends) { user in
                                FriendRow(user: user)
                                Divider().padding(.leading, 44 + Here.Spacing.sm)
                            }
                        }
                    }
                    .padding(Here.Spacing.lg)
                }
            }
            .navigationTitle("freunde")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await friendVM.refresh(userID: authVM.currentUser.id) }
    }
}

#Preview {
    FriendSearchView()
        .environmentObject(AuthViewModel())
        .environmentObject(FriendViewModel())
}
