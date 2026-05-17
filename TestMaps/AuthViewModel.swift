import SwiftUI
import Combine

// MARK: - Auth ViewModel

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn:   Bool   = false
    @Published var currentUser:  User   = .preview
    @Published var isLoading:    Bool   = false
    @Published var errorMessage: String?

    private let url = SupabaseClient.baseURL
    private let key = SupabaseClient.apiKey

    // MARK: Session restore on launch
    func restoreSession() async {
        guard let token = KeychainStore.read("access_token") else { return }
        do {
            let authUser = try await fetchAuthUser(token: token)
            await ensureProfile(userID: authUser.id, email: authUser.email, token: token)
            let profile  = try? await fetchProfile(userID: authUser.id, token: token)
            currentUser  = profile?.toUser() ?? fallbackUser(authUser)
            isLoggedIn   = true
        } catch {
            KeychainStore.delete("access_token")
            KeychainStore.delete("refresh_token")
        }
    }

    // MARK: Sign Up
    func signUp(email: String, password: String) async {
        guard password.count >= 6 else {
            errorMessage = "Passwort muss mindestens 6 Zeichen lang sein."
            return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await supabaseAuth(endpoint: "signup", email: email, password: password)
            storeSession(resp)
            let profile = try? await fetchProfile(userID: resp.user.id, token: resp.accessToken)
            currentUser = profile?.toUser() ?? fallbackUser(resp.user)
            isLoggedIn  = true
        } catch AuthError.emailNotConfirmed {
            errorMessage = "Bitte bestätige deine E-Mail-Adresse."
        } catch AuthError.emailAlreadyExists {
            errorMessage = "Diese E-Mail ist bereits registriert. Bitte einloggen."
        } catch AuthError.weakPassword {
            errorMessage = "Passwort muss mindestens 6 Zeichen lang sein."
        } catch {
            errorMessage = "Registrierung fehlgeschlagen – bitte nochmal versuchen."
        }
    }

    // MARK: Sign In
    func signIn(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await supabaseAuth(endpoint: "token?grant_type=password", email: email, password: password)
            storeSession(resp)
            await ensureProfile(userID: resp.user.id, email: resp.user.email, token: resp.accessToken)
            let profile = try? await fetchProfile(userID: resp.user.id, token: resp.accessToken)
            currentUser = profile?.toUser() ?? fallbackUser(resp.user)
            isLoggedIn  = true
        } catch AuthError.invalidCredentials {
            errorMessage = "E-Mail oder Passwort falsch."
        } catch {
            errorMessage = "Anmeldung fehlgeschlagen – bitte nochmal versuchen."
        }
    }


    // MARK: Update Profile
    func updateProfile(displayName: String, bio: String, avatarImage: UIImage?) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            var avatarURL = currentUser.avatarURL
            // Upload new avatar if provided
            if let image = avatarImage, let jpeg = image.jpegCompressed(maxDimension: 400) {
                let path = "avatars/\(currentUser.id).jpg"
                avatarURL = try await SupabaseClient.upload(bucket: "avatars", path: path, data: jpeg)
            }
            var body: [String: Any] = ["display_name": displayName, "bio": bio]
            if let url = avatarURL { body["avatar_url"] = url }
            try await SupabaseClient.patch(
                "/rest/v1/profiles",
                query: [URLQueryItem(name: "id", value: "eq.\(currentUser.id)")],
                body: body
            )
            currentUser = User(
                id: currentUser.id, username: currentUser.username,
                displayName: displayName, avatarURL: avatarURL,
                avatarColor: currentUser.avatarColor, bio: bio,
                friendIDs: currentUser.friendIDs
            )
        } catch {
            errorMessage = "Profil konnte nicht gespeichert werden."
        }
    }


    // MARK: Ensure profile exists (safety net for accounts created before trigger)
    private func ensureProfile(userID: String, email: String?, token: String) async {
        if (try? await fetchProfile(userID: userID, token: token)) != nil { return }
        // No profile row — create one now
        let username = (email ?? userID)
            .components(separatedBy: "@").first?
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_.]", with: ".", options: .regularExpression)
            ?? "user"
        let safe = String(username.prefix(25)).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let final = safe.count < 3 ? safe + String(userID.prefix(4)) : safe
        try? await SupabaseClient.upsert("/rest/v1/profiles", body: [
            "id":           userID,
            "username":     final,
            "display_name": email?.components(separatedBy: "@").first ?? "here. user"
        ])
    }

    // MARK: Logout
    func logout() {
        KeychainStore.delete("access_token")
        KeychainStore.delete("refresh_token")
        currentUser = .preview
        isLoggedIn  = false
    }

    // MARK: - Private

    private func storeSession(_ resp: AuthResponse) {
        KeychainStore.write("access_token", resp.accessToken)
        if let r = resp.refreshToken { KeychainStore.write("refresh_token", r) }
    }

    private func supabaseAuth(endpoint: String, email: String, password: String) async throws -> AuthResponse {
        let u = URL(string: "\(url)/auth/v1/\(endpoint)")!
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0

        // Parse error body for all non-200 responses
        if status != 200 {
            if let body = try? JSONDecoder().decode(SupabaseError.self, from: data) {
                let msg = body.message.lowercased()
                if msg.contains("email not confirmed")         { throw AuthError.emailNotConfirmed }
                if msg.contains("invalid login")               { throw AuthError.invalidCredentials }
                if msg.contains("user already registered")     { throw AuthError.emailAlreadyExists }
                if msg.contains("password should be")          { throw AuthError.weakPassword }
                if msg.contains("weak password")               { throw AuthError.weakPassword }
            }
            throw URLError(.badServerResponse)
        }

        // Signup with email confirmation enabled returns 200 but no access_token
        if let decoded = try? JSONDecoder().decode(AuthResponse.self, from: data),
           !decoded.accessToken.isEmpty {
            return decoded
        }

        // If we land here, email confirmation is required
        throw AuthError.emailNotConfirmed
    }

    private func fetchAuthUser(token: String) async throws -> AuthUser {
        let u = URL(string: "\(url)/auth/v1/user")!
        var req = URLRequest(url: u)
        req.setValue(key,               forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
        return try JSONDecoder().decode(AuthUser.self, from: data)
    }

    private func fetchProfile(userID: String, token: String) async throws -> DBProfile {
        var comps = URLComponents(string: "\(url)/rest/v1/profiles")!
        comps.queryItems = [
            URLQueryItem(name: "id",     value: "eq.\(userID)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit",  value: "1")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(key,               forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        let rows = try JSONDecoder().decode([DBProfile].self, from: data)
        guard let p = rows.first else { throw URLError(.cannotFindHost) }
        return p
    }

    private func fallbackUser(_ u: AuthUser) -> User {
        User(id: u.id, username: u.email ?? u.id, displayName: u.email ?? "User",
             avatarURL: nil, avatarColor: "#1A1A1A", bio: "", friendIDs: [])
    }
}

// MARK: - Errors
private enum AuthError: Error {
    case emailNotConfirmed, invalidCredentials, emailAlreadyExists, weakPassword
}

// MARK: - Response types
private struct AuthResponse: Decodable {
    let accessToken: String; let refreshToken: String?; let user: AuthUser
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"; case refreshToken = "refresh_token"; case user
    }
}
private struct AuthUser:     Decodable { let id: String; let email: String? }
private struct SupabaseError: Decodable {
    let message: String
    enum CodingKeys: String, CodingKey { case message, msg }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = (try? c.decode(String.self, forKey: .message))
               ?? (try? c.decode(String.self, forKey: .msg))
               ?? "unknown error"
    }
}
private struct DBProfile: Decodable {
    let id: String; let username: String
    let displayName: String?; let avatarUrl: String?; let avatarColor: String?; let bio: String?
    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"; case avatarUrl = "avatar_url"; case avatarColor = "avatar_color"
    }
    func toUser() -> User {
        User(id: id, username: username, displayName: displayName ?? username,
             avatarURL: avatarUrl, avatarColor: avatarColor ?? "#1A1A1A", bio: bio ?? "", friendIDs: [])
    }
}
