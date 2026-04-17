import SwiftUI
import PhotosUI

struct NewPostView: View {
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @StateObject private var vm = NewPostViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var appeared: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Here.Color.white.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Here.Spacing.lg) {

                        // ── Location header ───────────────────────────
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Here.Color.ink)
                                Text(locationService.currentPlaceName)
                                    .font(Here.Font.mono(13))
                                    .foregroundColor(Here.Color.ink)
                            }
                            Text("teile diesen moment")
                                .font(Here.Font.display(24, weight: .bold))
                                .foregroundColor(Here.Color.ink)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

                        // ── Photo picker ──────────────────────────────
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                RoundedRectangle(cornerRadius: Here.Radius.lg, style: .continuous)
                                    .fill(Here.Color.cloud)
                                    .frame(height: 220)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Here.Radius.lg, style: .continuous)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                            .foregroundColor(Here.Color.border)
                                    )

                                if let image = vm.selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.lg, style: .continuous))
                                } else {
                                    VStack(spacing: 10) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 32, weight: .light))
                                            .foregroundColor(Here.Color.stone)
                                        Text("foto hinzufügen")
                                            .font(Here.Font.body(14))
                                            .foregroundColor(Here.Color.stone)
                                        Text("optional")
                                            .font(Here.Font.body(12))
                                            .foregroundColor(Here.Color.stone.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .onChange(of: selectedItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    await MainActor.run { vm.selectedImage = uiImage }
                                }
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)

                        // ── Caption ────────────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("was machst du?")
                                .font(Here.Font.body(13, weight: .medium))
                                .foregroundColor(Here.Color.stone)

                            ZStack(alignment: .topLeading) {
                                if vm.caption.isEmpty {
                                    Text("erzähl deinen freunden was los ist…")
                                        .font(Here.Font.body(16))
                                        .foregroundColor(Here.Color.stone.opacity(0.5))
                                        .padding(.top, 2)
                                        .padding(.leading, 1)
                                }
                                TextEditor(text: $vm.caption)
                                    .font(Here.Font.body(16))
                                    .foregroundColor(Here.Color.ink)
                                    .frame(minHeight: 80, maxHeight: 160)
                                    .scrollContentBackground(.hidden)
                            }
                            .padding(Here.Spacing.md)
                            .background(Here.Color.cloud)
                            .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))

                            HStack {
                                Spacer()
                                Text("\(vm.caption.count)/200")
                                    .font(Here.Font.mono(11))
                                    .foregroundColor(vm.caption.count > 180 ? Here.Color.danger : Here.Color.stone)
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.24), value: appeared)

                        // ── Privacy note ───────────────────────────────
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Here.Color.stone)
                            Text("nur deine freunde sehen diesen post")
                                .font(Here.Font.body(12))
                                .foregroundColor(Here.Color.stone)
                        }
                        .padding(Here.Spacing.sm)
                        .background(Here.Color.cloud)
                        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.sm, style: .continuous))
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)

                        // ── Submit ─────────────────────────────────────
                        Button {
                            vm.submit(
                                author: authVM.currentUser,
                                coordinate: locationService.currentLocation,
                                placeName: locationService.currentPlaceName,
                                feed: feedVM
                            )
                        } label: {
                            if vm.isPosting {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                    Text("wird geteilt…")
                                }
                            } else {
                                Text("teilen")
                            }
                        }
                        .herePrimary()
                        .disabled(vm.caption.isEmpty || vm.isPosting)
                        .opacity(vm.caption.isEmpty ? 0.5 : 1.0)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.36), value: appeared)

                        Spacer().frame(height: 20)
                    }
                    .padding(Here.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("abbrechen") { dismiss() }
                        .font(Here.Font.body(15))
                        .foregroundColor(Here.Color.stone)
                }
            }
        }
        .onAppear { appeared = true }
        .onChange(of: vm.didPost) { _, posted in
            if posted {
                dismiss()
                vm.reset()
            }
        }
    }
}

#Preview {
    NewPostView()
        .environmentObject(FeedViewModel())
        .environmentObject(LocationService())
        .environmentObject(AuthViewModel())
}
