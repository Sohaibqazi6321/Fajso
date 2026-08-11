import Foundation
import SwiftUI

enum TogetherDemo {
    static let coupleName = "Sohaib + Fajr"
    static let distanceText = "7,846 mi apart"
    static let appGroupIdentifier = "group.com.sohaib.together"
    static let demoCacheKey = "together.phase1.demoCache"
    static let liveDistanceTextKey = "together.live.distanceText"
    static let liveDistanceMilesKey = "together.live.distanceMiles"
    static let liveDistanceUpdatedAtKey = "together.live.distanceUpdatedAt"
    static let partnerPhotoDataKey = "together.partnerPhoto.data"
    static let partnerPhotoIdKey = "together.partnerPhoto.id"
    static let partnerPhotoSenderKey = "together.partnerPhoto.sender"
    static let partnerPhotoUpdatedAtKey = "together.partnerPhoto.updatedAt"
    static let partnerPhotoSavedToPhotosIdKey = "together.partnerPhoto.savedToPhotosId"
    static let partnerPhotoFileName = "latest-partner-photo.jpg"

    static let testPhotoBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAL2SURBVGhD1dhvi01RFAbw/Xl8gPkWIsmcs7YkiSRJksaYMcbMnXvn/ptJkiTSJJEkSZJEkjRJkkhCJEmSJJEenhe7tF6cs/acc0/nvnhezlq/58XMnL0c/CL++EX89gv45Rfw0y/gh+/ju+/jm+/jq+/ji+/js+/hk+/ho+/hg+/hve/ine/irXTxWjp4JR28lA5eSAfPpYNn0sZTaeOJtPFY2ngk81iWeTyUeTyQFu5LC/ekhbvSwh1p4bY0cUuauClN3JAmrsscrskcrqZzuJI2cDlt4FLawMW0gQtpA+fTWZxLZ+GGGb/EAsOMP8sCw4w/k87ADTP+NAsMM/4UC5SJH1k1Yk4Z+JPpEbgy8BoXkyL4EyxQBK8xRbIS/HEWqAM+JBZ/LJ2Gqws+JAZ/lAXqhA+x4hdZIAZf9BfWGiu+nx6Gqxs+xILvsoAVH/t3vmgs+DYLWPH8D6uXDDIWfIsFrHh+HugleLNcWvRsC77JAlY8v230Eo0oEj3bgm8kU3BWPD/M9BKNKBI924KfYQErnl+VeolGFImebcFPs4AVz0/iQeEZXcCCn2KBleAHUULPtuAnk0NwFnx4jOglGlEkerYFP8ECVjxfUnqJRhSJnm3Bj7OAFc9noF6iEUWiZ1vwY8kknBXPN6xeUlYJPZOx4PezgBXPN6xeUkYJPSvEgt/HAlZ8eIDrRYMoYMXvZYEYPB/getlKi+if/T9W/B4WiMGH64FeWGZi8LuTCbhYPK8HemmZicHvYoFYfDh96MVlJBa/kwXqgg+Jwe9ggTrhQ6z47clBuLrhQyz4bSxQR3xIHn4rC9QVH5KF35KMw+XheavUQ6tMFn4zC+TheavUQ6tMFn4TC+TheWjVQ6tMFn4jC9QZz2ThhQWy8OFKrIdWmSx8MnoALg/PK7EeWmWy8BtYIA/PK7EeWmWy8OtZIA/PK7EeWmWy8OtYIA8frsR6cBXJw68dHYOz4MOhVS8YZCz4NSxgxYdbpV40iFjxq/8V+Au3QKkAYxRuuQAAAABJRU5ErkJggg=="

    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func sharedContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static func writeDemoCache() -> Bool {
        guard let defaults = sharedDefaults() else {
            return false
        }

        defaults.set(Date().timeIntervalSince1970, forKey: demoCacheKey)
        return defaults.synchronize()
    }

    static func cachedDemoDate() -> Date? {
        guard let value = sharedDefaults()?.double(forKey: demoCacheKey), value > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: value)
    }

    static func writeLiveDistance(distanceText: String, miles: Double, updatedAt: Date) -> Bool {
        guard let defaults = sharedDefaults() else {
            return false
        }

        defaults.set(distanceText, forKey: liveDistanceTextKey)
        defaults.set(miles, forKey: liveDistanceMilesKey)
        defaults.set(updatedAt.timeIntervalSince1970, forKey: liveDistanceUpdatedAtKey)
        return defaults.synchronize()
    }

    static func liveDistance() -> TogetherDistanceSnapshot {
        guard let defaults = sharedDefaults() else {
            return TogetherDistanceSnapshot(text: distanceText, miles: nil, updatedAt: nil, isLive: false)
        }

        let text = defaults.string(forKey: liveDistanceTextKey) ?? distanceText
        let updatedAtValue = defaults.double(forKey: liveDistanceUpdatedAtKey)
        let milesValue = defaults.double(forKey: liveDistanceMilesKey)
        return TogetherDistanceSnapshot(
            text: text,
            miles: milesValue > 0 ? milesValue : nil,
            updatedAt: updatedAtValue > 0 ? Date(timeIntervalSince1970: updatedAtValue) : nil,
            isLive: updatedAtValue > 0
        )
    }

    static func formattedDistance(miles: Double) -> String {
        if miles < 0.1 {
            return "less than 0.1 mi apart"
        }

        if miles < 10 {
            return "\(String(format: "%.1f", miles)) mi apart"
        }

        return "\(Int(miles.rounded()).formatted()) mi apart"
    }

    static func writePartnerPhoto(data: Data, photoId: UUID, senderUserId: UUID, updatedAt: Date) -> Bool {
        guard
            let defaults = sharedDefaults(),
            let photoURL = sharedContainerURL()?.appendingPathComponent(partnerPhotoFileName)
        else {
            return false
        }

        do {
            try data.write(to: photoURL, options: .atomic)
        } catch {
            return false
        }

        defaults.removeObject(forKey: partnerPhotoDataKey)
        defaults.set(photoId.uuidString, forKey: partnerPhotoIdKey)
        defaults.set(senderUserId.uuidString, forKey: partnerPhotoSenderKey)
        defaults.set(updatedAt.timeIntervalSince1970, forKey: partnerPhotoUpdatedAtKey)
        return defaults.synchronize()
    }

    static func partnerPhoto() -> TogetherPartnerPhotoSnapshot {
        guard let defaults = sharedDefaults() else {
            return TogetherPartnerPhotoSnapshot(data: nil, photoId: nil, senderUserId: nil, updatedAt: nil)
        }

        let updatedAtValue = defaults.double(forKey: partnerPhotoUpdatedAtKey)
        let fileData = sharedContainerURL()
            .map { $0.appendingPathComponent(partnerPhotoFileName) }
            .flatMap { try? Data(contentsOf: $0) }

        return TogetherPartnerPhotoSnapshot(
            data: fileData ?? defaults.data(forKey: partnerPhotoDataKey),
            photoId: (defaults.string(forKey: partnerPhotoIdKey)).flatMap(UUID.init(uuidString:)),
            senderUserId: (defaults.string(forKey: partnerPhotoSenderKey)).flatMap(UUID.init(uuidString:)),
            updatedAt: updatedAtValue > 0 ? Date(timeIntervalSince1970: updatedAtValue) : nil
        )
    }

    static func lastSavedPartnerPhotoId() -> UUID? {
        (sharedDefaults()?.string(forKey: partnerPhotoSavedToPhotosIdKey)).flatMap(UUID.init(uuidString:))
    }

    static func markPartnerPhotoSavedToPhotos(photoId: UUID) -> Bool {
        guard let defaults = sharedDefaults() else {
            return false
        }

        defaults.set(photoId.uuidString, forKey: partnerPhotoSavedToPhotosIdKey)
        return defaults.synchronize()
    }
}

struct TogetherDistanceSnapshot {
    let text: String
    let miles: Double?
    let updatedAt: Date?
    let isLive: Bool

    var lockCircleValue: String {
        guard let miles else {
            return "7,846"
        }

        if miles < 10 {
            return String(format: "%.1f", miles)
        }

        return Int(miles.rounded()).formatted()
    }

    var statusText: String {
        guard let updatedAt else {
            return "Phase 1 test"
        }

        let minutes = max(0, Int(Date().timeIntervalSince(updatedAt) / 60))
        if minutes < 1 {
            return "Updated just now"
        }

        return "Updated \(minutes) min ago"
    }
}

struct TogetherPartnerPhotoSnapshot {
    let data: Data?
    let photoId: UUID?
    let senderUserId: UUID?
    let updatedAt: Date?

    var statusText: String {
        guard let updatedAt else {
            return "Test Photo"
        }

        let minutes = max(0, Int(Date().timeIntervalSince(updatedAt) / 60))
        if minutes < 1 {
            return "Updated just now"
        }

        return "Updated \(minutes) min ago"
    }
}

struct TogetherCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.10, blue: 0.13),
                        Color(red: 0.25, green: 0.20, blue: 0.24)
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

