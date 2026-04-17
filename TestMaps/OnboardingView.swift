import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            Here.Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Wordmark
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

                // Form
                VStack(spacing: Here.Spacing.sm) {
                    HereTextField(placeholder: "benutzername", text: $username)
                    HereTextField(placeholder: "passwort", text: $password, isSecure: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.35), value: appeared)

                Spacer().frame(height: Here.Spacing.lg)

                // Actions
                VStack(spacing: Here.Spacing.sm) {
                    Button {
                        authVM.login(username: username, password: password)
                    } label: {
                        Text(isSignUp ? "konto erstellen" : "anmelden")
                    }
                    .herePrimary()

                    Button {
                        withAnimation(.spring()) { isSignUp.toggle() }
                    } label: {
                        Text(isSignUp ? "bereits ein konto?" : "neu hier?")
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

struct HereTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
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
