import SwiftUI

/// Shared photo widget. Implemented in Phase 3. See the vault note "05 Feature - Photo Widget".
struct PhotosFeature: FajsoFeature {
    let id = "photos"
    let title = "Photos"
    let symbol = "camera.fill"

    func homeCard() -> AnyView {
        AnyView(FeatureTile(title: title, subtitle: "Coming in Phase 3", symbol: symbol))
    }

    func destination() -> AnyView {
        AnyView(ComingSoonView(text: "Snap a photo and it appears on your partner's Home Screen."))
    }
}
