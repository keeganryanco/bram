import Foundation
import Supabase

enum BramOAuthProvider: Equatable {
    case apple
    case google
}

protocol BramAuthServicing: Sendable {
    func restoreSessionUserId() async throws -> UUID?
    func signUp(email: String, password: String) async throws -> UUID?
    func signIn(email: String, password: String) async throws -> UUID
    func signInWithOAuth(_ provider: BramOAuthProvider) async throws -> UUID?
    func handleCallbackURL(_ url: URL) async throws -> UUID
    func signOut() async throws
}

struct BramAuthService: BramAuthServicing {
    private let client: SupabaseClient
    private let configuration: BramSupabaseConfiguration

    init(client: SupabaseClient, configuration: BramSupabaseConfiguration) {
        self.client = client
        self.configuration = configuration
    }

    func restoreSessionUserId() async throws -> UUID? {
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            return nil
        }
    }

    func signUp(email: String, password: String) async throws -> UUID? {
        let response = try await client.auth.signUp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            redirectTo: configuration.redirectURL
        )
        return response.session?.user.id ?? response.user.id
    }

    func signIn(email: String, password: String) async throws -> UUID {
        let session = try await client.auth.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        return session.user.id
    }

    func signInWithOAuth(_ provider: BramOAuthProvider) async throws -> UUID? {
        switch provider {
        case .apple:
            let session = try await client.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: configuration.redirectURL
            )
            return session.user.id
        case .google:
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: configuration.redirectURL
            )
            return session.user.id
        }
    }

    func handleCallbackURL(_ url: URL) async throws -> UUID {
        let session = try await client.auth.session(from: url)
        return session.user.id
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
