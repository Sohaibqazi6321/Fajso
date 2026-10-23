import Foundation

/// A tiny request to Supabase, used by the Phase 0 spike to prove the widget
/// extension can reach the backend on its own (the Fajso design relies on it).
enum BackendCheck {
    struct Result: Codable, Equatable, Sendable {
        let succeeded: Bool
        let detail: String
        let checkedAt: Date
    }

    static func run(timeout: TimeInterval = 8) async -> Result {
        guard
            let baseURL = FajsoConfig.supabaseURL,
            let key = FajsoConfig.supabasePublishableKey
        else {
            return Result(succeeded: false, detail: "Not configured", checkedAt: Date())
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("auth/v1/health"))
        request.timeoutInterval = timeout
        request.setValue(key, forHTTPHeaderField: "apikey")

        let started = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let milliseconds = Int(Date().timeIntervalSince(started) * 1_000)
            return Result(
                succeeded: (200..<300).contains(status),
                detail: "HTTP \(status) · \(milliseconds) ms",
                checkedAt: Date()
            )
        } catch {
            return Result(succeeded: false, detail: error.localizedDescription, checkedAt: Date())
        }
    }
}
