import Foundation

/// Data shared between the app and the widget through the App Group.
///
/// Phase 0 uses this to answer the project's biggest open question: does the
/// App Group survive free-Apple-ID sideload signing? The app and the widget
/// each write a heartbeat; each side shows whether it can read the other's.
enum SharedStore {
    struct Heartbeat: Codable, Equatable, Sendable {
        let writer: Writer
        let writtenAt: Date
        let backend: BackendCheck.Result?
    }

    enum Writer: String, Codable, Sendable {
        case app
        case widget
    }

    enum Availability: Equatable, Sendable {
        /// The App Group container could not be opened at all.
        case unavailable
        /// The container works but the other side has not written yet.
        case empty
        case found(Heartbeat)
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: FajsoConfig.appGroupIdentifier)
    }

    /// True only when the App Group is really provisioned. `UserDefaults(suiteName:)`
    /// succeeds even without the entitlement, so the container URL is the honest test.
    static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FajsoConfig.appGroupIdentifier) != nil
    }

    static func writeHeartbeat(from writer: Writer, backend: BackendCheck.Result?, now: Date = Date()) {
        guard isAppGroupAvailable, let defaults else { return }
        let heartbeat = Heartbeat(writer: writer, writtenAt: now, backend: backend)
        if let data = try? JSONEncoder().encode(heartbeat) {
            defaults.set(data, forKey: key(for: writer))
        }
    }

    static func heartbeat(from writer: Writer) -> Availability {
        guard isAppGroupAvailable, let defaults else { return .unavailable }
        guard
            let data = defaults.data(forKey: key(for: writer)),
            let heartbeat = try? JSONDecoder().decode(Heartbeat.self, from: data)
        else {
            return .empty
        }
        return .found(heartbeat)
    }

    private static func key(for writer: Writer) -> String {
        "fajso.heartbeat.\(writer.rawValue).v1"
    }
}
