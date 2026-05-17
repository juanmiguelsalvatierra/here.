import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var displayName: String
    @State private var bio:         String
    @State private var pickerItem:  PhotosPickerItem?
    @State private var avatarImage: UIImage?

    init(user: User) {
        _displayName = State(initialValue: user.displayName)
        _bio         = State(initialValue: user.bio)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Here.Spacing.lg) {

                    // Avatar
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if let img = avatarImage {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(Circle())
                            } else {
                                AvatarView(user: authVM.currentUser, size: 88)
                            }
                            Circle()
                                .fill(Here.Color.ink)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .onChange(of: pickerItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let img  = UIImage(data: data) {
                                avatarImage = img
                            }
                        }
                    }
                    .padding(.top, Here.Spacing.lg)

                    // Fields
                    VStack(alignment: .leading, spacing: Here.Spacing.md) {
                        EditField(label: "anzeigename", text: $displayName, limit: 50)
                        EditField(label: "bio", text: $bio, limit: 160, multiline: true)
                    }

                    if let err = authVM.errorMessage {
                        Text(err)
                            .font(Here.Font.body(13))
                            .foregroundColor(Here.Color.danger)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }
                .padding(.horizontal, Here.Spacing.lg)
            }
            .background(Here.Color.white)
            .navigationTitle("profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("abbrechen") { dismiss() }
                        .font(Here.Font.body(15))
                        .foregroundColor(Here.Color.stone)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await authVM.updateProfile(
                                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                                avatarImage: avatarImage
                            )
                            if authVM.errorMessage == nil { dismiss() }
                        }
                    } label: {
                        if authVM.isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("speichern")
                                .font(Here.Font.body(15, weight: .semibold))
                                .foregroundColor(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                 ? Here.Color.stone : Here.Color.ink)
                        }
                    }
                    .disabled(authVM.isLoading ||
                              displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct EditField: View {
    let label:     String
    @Binding var text: String
    let limit:     Int
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Here.Font.body(12, weight: .medium))
                .foregroundColor(Here.Color.stone)
                .textCase(.uppercase)
                .tracking(0.6)

            Group {
                if multiline {
                    TextEditor(text: $text)
                        .frame(minHeight: 72, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(Here.Font.body(16))
            .foregroundColor(Here.Color.ink)
            .padding(Here.Spacing.md)
            .background(Here.Color.cloud)
            .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
            .onChange(of: text) { _, v in
                if v.count > limit { text = String(v.prefix(limit)) }
            }

            HStack {
                Spacer()
                Text("\(text.count)/\(limit)")
                    .font(Here.Font.mono(11))
                    .foregroundColor(text.count > Int(Double(limit) * 0.9) ? Here.Color.danger : Here.Color.stone)
            }
        }
    }
}

#Preview {
    ProfileEditView(user: .preview).environmentObject(AuthViewModel())
}
