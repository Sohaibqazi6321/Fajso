import Foundation

/// Values injected from Config/Fajso.xcconfig through each target's Info.plist.
/// Compiled into both the app and the widget extension.
enum FajsoConfig {
    static var supabaseURL: URL? {
        guard let host = infoString("SUPABASE_HOST") else { return nil }
        return URL(string: "https://\(host)")
    }

    static var supabasePublishableKey: String? {
        infoString("SUPABASE_PUBLISHABLE_KEY")
    }

    static var appGroupIdentifier: String {
        infoString("FAJSO_APP_GROUP") ?? "group.com.sohaib.fajso"
    }

    static var isBackendConfigured: Bool {
        supabaseURL != nil && supabasePublishableKey != nil
    }

    static var versionDescription: String {
        let version = infoString("CFBundleShortVersionString") ?? "?"
        let build = infoString("CFBundleVersion") ?? "?"
        return "\(version) (\(build))"
    }

    private static func infoString(_ key: String) -> String? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty,
            !value.contains("$(")
        else {
            return nil
        }
        return value
    }
}
