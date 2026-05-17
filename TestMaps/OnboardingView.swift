import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email    = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Here.Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // MARK: Wordmark
                Spacer().frame(height: 80)
                VStack(alignment: .leading, spacing: 6) {
                    Text("here.")
                        .font(Here.Font.display(54, weight: .bold))
                        .foregroundColor(Here.Color.ink)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1), value: appeared)

                    Text("sei wo du bist.")
                        .font(Here.Font.body(17))
                        .foregroundColor(Here.Color.stone)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.25), value: appeared)
                }

                Spacer()

                // MARK: Form
                VStack(spacing: Here.Spacing.sm) {
                    HereField(placeholder: "e-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                    HereField(placeholder: "passwort", text: $password, isSecure: true)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.35), value: appeared)

                Spacer().frame(height: Here.Spacing.lg)

                // MARK: Actions
                VStack(spacing: Here.Spacing.sm) {
                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(Here.Font.body(13))
                            .foregroundColor(Here.Color.danger)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    Button {
                        Task {
                            if isSignUp {
                                await authVM.signUp(email: email, password: password)
                            } else {
                                await authVM.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isSignUp ? "konto erstellen" : "anmelden")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .herePrimary()
                    .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)

                    Button {
                        withAnimation(.spring()) {
                            isSignUp.toggle()
                            authVM.errorMessage = nil
                        }
                    } label: {
                        Text(isSignUp ? "bereits ein konto? anmelden" : "neu hier? konto erstellen")
                            .font(Here.Font.body(14))
                            .foregroundColor(Here.Color.stone)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.45), value: appeared)

                Spacer().frame(height: 48)
            }
            .padding(.horizontal, Here.Spacing.lg)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Text Field

private struct HereField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .font(Here.Font.body(16))
        .padding(Here.Spacing.md)
        .background(Here.Color.cloud)
        .clipShape(RoundedRectangle(cornerRadius: Here.Radius.md, style: .continuous))
    }
}

#Preview {
    OnboardingView().environmentObject(AuthViewModel())
}
