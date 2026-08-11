import Foundation
import SwiftUI

enum TogetherDemo {
    static let coupleName = "Sohaib + Fajr"
    static let distanceText = "7,846 mi apart"
    static let appGroupIdentifier = "group.com.sohaib.together"
    static let demoCacheKey = "together.phase1.demoCache"

    static let testPhotoBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAYAAABw4pVUAAAA8ElEQVR4nO3csQ3CQBAEwYz/f2dhoKQigU0BfJ53taRmxs7uzv0ewHfEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgSKIEYEiiBGBIogRgRKP9m27btt3/f9Qy36wJvA1QLzQAAAABJRU5ErkJggg=="

    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
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

