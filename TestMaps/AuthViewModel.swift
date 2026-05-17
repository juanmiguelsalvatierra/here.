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
            let profile = try? await fetchProfile(userID: resp.user.id, token: resp.accessToken)
            currentUser = profile?.toUser() ?? fallbackUser(resp.user)
            isLoggedIn  = true
        } catch AuthError.invalidCredentials {
            errorMessage = "E-Mail oder Passwort falsch."
        } catch {
            errorMessage = "Anmeldung fehlgeschlagen – bitte nochmal versuchen."
        }
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
        if status == 400 {
            if let body = try? JSONDecoder().decode(SupabaseError.self, from: data) {
                if body.message.contains("Email not confirmed") { throw AuthError.emailNotConfirmed }
                if body.message.contains("Invalid login")       { throw AuthError.invalidCredentials }
            }
            throw URLError(.badServerResponse)
        }
        guard status == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    private func fetchAuthUser(token: String) async throws -> AuthUser {
        let u = URL(string: "\(url)/auth/v1/user")!
        var req = URLRequest(url: u)
        req.setValue(key,           forHTTPHeaderField: "apikey")
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
        req.setValue(key,                    forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)",      forHTTPHeaderField: "Authorization")
        req.setValue("application/json",     forHTTPHeaderField: "Accept")
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
private enum AuthError: Error { case emailNotConfirmed, invalidCredentials }

// MARK: - Response types
private struct AuthResponse: Decodable {
    let accessToken: String; let refreshToken: String?; let user: AuthUser
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"; case refreshToken = "refresh_token"; case user
    }
}
private struct AuthUser:     Decodable { let id: String; let email: String? }
private struct SupabaseError: Decodable { let message: String }
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
