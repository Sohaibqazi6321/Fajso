import SwiftUI

/// Lock Screen distance. Implemented in Phase 2. See the vault note "04 Feature - Distance Widget".
struct DistanceFeature: FajsoFeature {
    let id = "distance"
    let title = "Distance"
    let symbol = "location.north.circle.fill"

    func homeCard() -> AnyView {
        AnyView(FeatureTile(title: title, subtitle: "Coming in Phase 2", symbol: symbol))
    }

    func destination() -> AnyView {
        AnyView(ComingSoonView(text: "Live distance between you two, on the Lock Screen."))
    }
}

struct ComingSoonView: View {
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(FajsoColor.dawn)
            Text(text)
                .font(FajsoFont.body(.body))
                .multilineTextAlignment(.center)
                .foregroundStyle(FajsoColor.inkSoft)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FajsoColor.background.ignoresSafeArea())
    }
}
