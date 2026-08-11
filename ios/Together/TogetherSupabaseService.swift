import Foundation
import Supabase

@MainActor
final class TogetherSupabaseService: ObservableObject {
    @Published private(set) var isConfigured = TogetherSupabaseConfig.isConfigured
    @Published private(set) var statusText = TogetherSupabaseConfig.isConfigured ? "Supabase ready" : "Supabase not configured"

    private let client: SupabaseClient?

    init(client: SupabaseClient? = TogetherSupabaseConfig.makeClient()) {
        self.client = client
    }

    func sendMagicLink(to email: String) async {
        guard let client else {
            statusText = "Supabase keys are missing."
            return
        }

        do {
            try await client.auth.signInWithOTP(email: email)
            statusText = "Magic link sent to \(email)."
        } catch {
            statusText = "Magic link failed: \(error.localizedDescription)"
        }
    }

    func refreshSessionStatus() async {
        guard let client else {
            statusText = "Supabase keys are missing."
            return
        }

        do {
            let session = try await client.auth.session
            statusText = "Signed in as \(session.user.email ?? "Supabase user")."
        } catch {
            statusText = "Not signed in yet."
        }
    }

    func signOut() async {
        guard let client else {
            statusText = "Supabase keys are missing."
            return
        }

        do {
            try await client.auth.signOut()
            statusText = "Signed out."
        } catch {
            statusText = "Sign out failed: \(error.localizedDescription)"
        }
    }
}
