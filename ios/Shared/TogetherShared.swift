import Foundation
import SwiftUI

enum TogetherDemo {
    static let coupleName = "Sohaib + Fajr"
    static let distanceText = "7,846 mi apart"
    static let appGroupIdentifier = "group.com.sohaib.together"
    static let demoCacheKey = "together.phase1.demoCache"

    static let testPhotoBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAL2SURBVGhD1dhvi01RFAbw/Xl8gPkWIsmcs7YkiSRJksaYMcbMnXvn/ptJkiTSJJEkSZJEkjRJkkhCJEmSJJEenhe7tF6cs/acc0/nvnhezlq/58XMnL0c/CL++EX89gv45Rfw0y/gh+/ju+/jm+/jq+/ji+/js+/hk+/ho+/hg+/hve/ine/irXTxWjp4JR28lA5eSAfPpYNn0sZTaeOJtPFY2ngk81iWeTyUeTyQFu5LC/ekhbvSwh1p4bY0cUuauClN3JAmrsscrskcrqZzuJI2cDlt4FLawMW0gQtpA+fTWZxLZ+GGGb/EAsOMP8sCw4w/k87ADTP+NAsMM/4UC5SJH1k1Yk4Z+JPpEbgy8BoXkyL4EyxQBK8xRbIS/HEWqAM+JBZ/LJ2Gqws+JAZ/lAXqhA+x4hdZIAZf9BfWGiu+nx6Gqxs+xILvsoAVH/t3vmgs+DYLWPH8D6uXDDIWfIsFrHh+HugleLNcWvRsC77JAlY8v230Eo0oEj3bgm8kU3BWPD/M9BKNKBI924KfYQErnl+VeolGFImebcFPs4AVz0/iQeEZXcCCn2KBleAHUULPtuAnk0NwFnx4jOglGlEkerYFP8ECVjxfUnqJRhSJnm3Bj7OAFc9noF6iEUWiZ1vwY8kknBXPN6xeUlYJPZOx4PezgBXPN6xeUkYJPSvEgt/HAlZ8eIDrRYMoYMXvZYEYPB/getlKi+if/T9W/B4WiMGH64FeWGZi8LuTCbhYPK8HemmZicHvYoFYfDh96MVlJBa/kwXqgg+Jwe9ggTrhQ6z47clBuLrhQyz4bSxQR3xIHn4rC9QVH5KF35KMw+XheavUQ6tMFn4zC+TheavUQ6tMFn4TC+TheWjVQ6tMFn4jC9QZz2ThhQWy8OFKrIdWmSx8MnoALg/PK7EeWmWy8BtYIA/PK7EeWmWy8OtZIA/PK7EeWmWy8OtYIA8frsR6cBXJw68dHYOz4MOhVS8YZCz4NSxgxYdbpV40iFjxq/8V+Au3QKkAYxRuuQAAAABJRU5ErkJggg=="

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

