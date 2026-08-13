import Foundation
import SwiftUI

enum TogetherPairingCacheStatus: String, Codable, Sendable {
    case signedOut
    case unpaired
    case pending
    case paired
}

enum TogetherDistanceOrigin: String, Codable, Sendable {
    case live
    case developerOverride
}

enum TogetherDistanceFreshness: Equatable, Sendable {
    case fresh
    case aging
    case stale
    case missing
    case offlineCached
}

struct TogetherDistancePresentation: Codable, Equatable, Sendable {
    let miles: Double
    let sourceUpdatedAt: Date
    let cachedAt: Date
    let origin: TogetherDistanceOrigin
}

struct TogetherCachedPhotoReference: Codable, Equatable, Sendable {
    let photoId: UUID
    let fileName: String
    let updatedAt: Date
}

struct CoupleWidgetState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var accountId: UUID?
    var coupleId: UUID?
    var pairingStatus: TogetherPairingCacheStatus
    var partnerDisplayName: String?
    var distance: TogetherDistancePresentation?
    var localDistanceOverride: TogetherDistancePresentation?
    var partnerPhoto: TogetherCachedPhotoReference?
    var lastSuccessfulSync: Date?
    var isOffline: Bool

    static var signedOut: CoupleWidgetState {
        CoupleWidgetState(
            schemaVersion: currentSchemaVersion,
            accountId: nil,
            coupleId: nil,
            pairingStatus: .signedOut,
            partnerDisplayName: nil,
            distance: nil,
            localDistanceOverride: nil,
            partnerPhoto: nil,
            lastSuccessfulSync: nil,
            isOffline: false
        )
    }

    var effectiveDistance: TogetherDistancePresentation? {
        localDistanceOverride ?? distance
    }

    func distanceFreshness(at now: Date = Date()) -> TogetherDistanceFreshness {
        guard pairingStatus == .paired, let effectiveDistance else {
            return .missing
        }
        if isOffline, effectiveDistance.origin == .live {
            return .offlineCached
        }

        let age = max(0, now.timeIntervalSince(effectiveDistance.sourceUpdatedAt))
        if age < 30 * 60 {
            return .fresh
        }
        if age < 6 * 60 * 60 {
            return .aging
        }
        return .stale
    }

    func nextRefreshDate(after now: Date = Date()) -> Date {
        guard let effectiveDistance, effectiveDistance.origin == .live else {
            return now.addingTimeInterval(30 * 60)
        }

        let freshBoundary = effectiveDistance.sourceUpdatedAt.addingTimeInterval(30 * 60)
        if now < freshBoundary {
            return freshBoundary
        }
        let staleBoundary = effectiveDistance.sourceUpdatedAt.addingTimeInterval(6 * 60 * 60)
        if now < staleBoundary {
            return staleBoundary
        }
        return now.addingTimeInterval(30 * 60)
    }
}

enum CoupleWidgetCache {
    static let appGroupIdentifier = "group.com.sohaib.together"
    private static let stateKey = "together.widget-state.v1"
    private static let photoPrefix = "partner-photo-"

    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func sharedContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static func load() -> CoupleWidgetState? {
        guard
            let data = sharedDefaults()?.data(forKey: stateKey),
            let state = try? decoder.decode(CoupleWidgetState.self, from: data),
            state.schemaVersion == CoupleWidgetState.currentSchemaVersion
        else {
            return nil
        }
        return state
    }

    @discardableResult
    static func write(_ state: CoupleWidgetState) -> Bool {
        guard
            state.schemaVersion == CoupleWidgetState.currentSchemaVersion,
            let defaults = sharedDefaults(),
            let data = try? encoder.encode(state)
        else {
            return false
        }
        defaults.set(data, forKey: stateKey)
        return defaults.synchronize()
    }

    static func photoData(for state: CoupleWidgetState? = load()) -> Data? {
        guard
            let reference = state?.partnerPhoto,
            reference.fileName == URL(fileURLWithPath: reference.fileName).lastPathComponent,
            reference.fileName.hasPrefix(photoPrefix),
            let container = sharedContainerURL()
        else {
            return nil
        }
        return try? Data(contentsOf: container.appendingPathComponent(reference.fileName))
    }

    @discardableResult
    static func replacePartnerPhoto(
        data: Data,
        photoId: UUID,
        updatedAt: Date,
        in state: CoupleWidgetState
    ) -> CoupleWidgetState? {
        guard !data.isEmpty, let container = sharedContainerURL() else {
            return nil
        }

        let finalName = "\(photoPrefix)\(photoId.uuidString.lowercased()).jpg"
        let finalURL = container.appendingPathComponent(finalName)
        let stagingURL = container.appendingPathComponent(".\(finalName).\(UUID().uuidString).tmp")
        var backupDirectory: URL?
        do {
            try data.write(to: stagingURL, options: [.atomic])
            guard (try stagingURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
            if FileManager.default.fileExists(atPath: finalURL.path) {
                let replacementDirectory = container.appendingPathComponent(
                    ".partner-photo-backup-\(UUID().uuidString)",
                    isDirectory: true
                )
                try FileManager.default.createDirectory(at: replacementDirectory, withIntermediateDirectories: false)
                backupDirectory = replacementDirectory
                let backupURL = replacementDirectory.appendingPathComponent(finalName)
                try FileManager.default.moveItem(at: finalURL, to: backupURL)
                do {
                    try FileManager.default.moveItem(at: stagingURL, to: finalURL)
                } catch {
                    try? FileManager.default.moveItem(at: backupURL, to: finalURL)
                    throw error
                }
                try? FileManager.default.removeItem(at: replacementDirectory)
                backupDirectory = nil
            } else {
                try FileManager.default.moveItem(at: stagingURL, to: finalURL)
            }

            var updatedState = state
            let oldReference = updatedState.partnerPhoto
            updatedState.partnerPhoto = TogetherCachedPhotoReference(
                photoId: photoId,
                fileName: finalName,
                updatedAt: updatedAt
            )
            guard write(updatedState) else {
                try? FileManager.default.removeItem(at: finalURL)
                return nil
            }
            if let oldReference, oldReference.fileName != finalName {
                try? FileManager.default.removeItem(at: container.appendingPathComponent(oldReference.fileName))
            }
            return updatedState
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            if let backupDirectory {
                try? FileManager.default.removeItem(at: backupDirectory)
            }
            return nil
        }
    }

    @discardableResult
    static func clearPartnerPhoto(in state: CoupleWidgetState) -> CoupleWidgetState {
        var updatedState = state
        let oldReference = updatedState.partnerPhoto
        updatedState.partnerPhoto = nil
        guard write(updatedState) else {
            return state
        }
        if let oldReference, let container = sharedContainerURL() {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(oldReference.fileName))
        }
        return updatedState
    }

    static func clear() {
        sharedDefaults()?.removeObject(forKey: stateKey)
        guard
            let container = sharedContainerURL(),
            let files = try? FileManager.default.contentsOfDirectory(
                at: container,
                includingPropertiesForKeys: nil
            )
        else {
            return
        }
        for file in files where file.lastPathComponent.hasPrefix(photoPrefix) || file.lastPathComponent.hasPrefix(".\(photoPrefix)") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

enum TogetherDistanceFormatter {
    static func text(miles: Double) -> String {
        guard miles.isFinite, miles >= 0 else {
            return "Distance unavailable"
        }
        if miles < 0.1 {
            return "Less than 0.1 mi apart"
        }
        if miles < 10 {
            return "\(String(format: "%.1f", miles)) mi apart"
        }
        return "\(Int(miles.rounded()).formatted()) mi apart"
    }

    static func compactValue(miles: Double) -> String {
        miles < 10 ? String(format: "%.1f", miles) : Int(miles.rounded()).formatted()
    }

    static func ageText(since date: Date, now: Date = Date()) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "Updated just now" }
        if minutes < 60 { return "Updated \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "Updated \(hours)h ago" }
        return "Updated \(hours / 24)d ago"
    }
}

struct TogetherCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.95, blue: 1.0),
                        Color(red: 0.88, green: 0.82, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }
}

extension View {
    func togetherWidgetBackground() -> some View {
        modifier(TogetherCardBackground())
    }
}
