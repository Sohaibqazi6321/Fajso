import Foundation
import Supabase

enum TogetherSupabaseConfig {
    private static let placeholderURL = "YOUR_SUPABASE_URL"
    private static let placeholderKey = "YOUR_SUPABASE_PUBLISHABLE_KEY"
    static let authRedirectURL = URL(string: "together://auth-callback")!

    static let client: SupabaseClient? = {
        guard isConfigured, let url = URL(string: supabaseURLString) else {
            return nil
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
    }()

    static var supabaseURLString: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? placeholderURL
    }

    static var publishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? placeholderKey
    }

    static var isConfigured: Bool {
        guard
            let url = URL(string: supabaseURLString),
            ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            return false
        }

        return !publishableKey.isEmpty && publishableKey != placeholderKey
    }

    static func makeClient() -> SupabaseClient? {
        client
    }

    static func handleOpenURL(_ url: URL) {
        client?.auth.handle(url)
    }

    static var developerUserId: UUID? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "TOGETHER_DEVELOPER_USER_ID") as? String,
            !rawValue.isEmpty,
            !rawValue.contains("$(")
        else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }
}
