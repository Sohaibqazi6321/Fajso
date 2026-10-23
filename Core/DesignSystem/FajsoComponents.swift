import SwiftUI

/// Rounded surface card used throughout the app.
struct FajsoCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(FajsoMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: FajsoMetrics.cornerRadius, style: .continuous)
                    .fill(FajsoColor.surface)
                    .shadow(color: FajsoColor.dusk.opacity(0.12), radius: 18, y: 8)
            )
    }
}

/// Small status pill: ✓ / ✗ / … with a label.
struct StatusPill: View {
    enum Tone {
        case good, bad, neutral
    }

    let tone: Tone
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(FajsoFont.body(.footnote, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private var symbol: String {
        switch tone {
        case .good: "checkmark.circle.fill"
        case .bad: "xmark.octagon.fill"
        case .neutral: "ellipsis.circle.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .good: FajsoColor.success
        case .bad: FajsoColor.warning
        case .neutral: FajsoColor.inkSoft
        }
    }
}
