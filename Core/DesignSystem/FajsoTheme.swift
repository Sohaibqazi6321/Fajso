import SwiftUI
import UIKit

// Design tokens from the vault note "08 Design System". Compiled into both the
// app and the widget extension so widgets match the app.

enum FajsoColor {
    static let background = dynamic(light: 0xFBF6F1, dark: 0x141018)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1F1A24)
    static let ink = dynamic(light: 0x2A2130, dark: 0xF3ECE6)
    static let inkSoft = dynamic(light: 0x7A6E80, dark: 0xA99FB0)
    static let dawn = dynamic(light: 0xF2A27A, dark: 0xF5B08E)
    static let dusk = dynamic(light: 0x8C6BB1, dark: 0xB49AD6)
    static let heart = dynamic(light: 0xE46A82, dark: 0xEE8399)
    static let success = dynamic(light: 0x3E8E6A, dark: 0x6CC49B)
    static let warning = dynamic(light: 0xC0563B, dark: 0xF08A6E)

    /// Signature dawn gradient. Use sparingly: hero card, send button, widget empty states.
    static let dawnGradient = LinearGradient(
        colors: [dawn, heart, dusk],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum FajsoFont {
    /// Editorial serif for headlines (Apple's New York).
    static func title(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Friendly rounded type for UI and body text.
    static func body(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    /// Heavy rounded digits for distances. Pair with `.monospacedDigit()`.
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

enum FajsoMetrics {
    static let cornerRadius: CGFloat = 24
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 18
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
