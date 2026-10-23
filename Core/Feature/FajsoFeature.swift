import SwiftUI

/// Every Fajso feature is a self-contained module that plugs into the Home
/// screen. To add one: create Features/<Name>/, conform to this protocol, and
/// add it to `FeatureRegistry.all`. See the vault note "03 Architecture".
@MainActor
protocol FajsoFeature {
    var id: String { get }
    var title: String { get }
    /// SF Symbol name.
    var symbol: String { get }
    /// Tile shown on the Home screen.
    func homeCard() -> AnyView
    /// Screen pushed when the tile is tapped.
    func destination() -> AnyView
}

@MainActor
enum FeatureRegistry {
    static let all: [any FajsoFeature] = [
        DistanceFeature(),
        PhotosFeature(),
        DiagnosticsFeature()
    ]
}
