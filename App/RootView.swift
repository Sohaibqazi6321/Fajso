import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    HeroCard()
                    ForEach(FeatureRegistry.all.indices, id: \.self) { index in
                        let feature = FeatureRegistry.all[index]
                        NavigationLink {
                            feature.destination()
                                .navigationTitle(feature.title)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            feature.homeCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(FajsoMetrics.screenPadding)
            }
            .background(FajsoColor.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(FajsoColor.dusk)
        .foregroundStyle(FajsoColor.ink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fajso")
                .font(FajsoFont.title(40))
            Text("A little place for the two of you.")
                .font(FajsoFont.body(.subheadline))
                .foregroundStyle(FajsoColor.inkSoft)
        }
        .padding(.top, 8)
    }
}

private struct HeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: -10) {
                avatar("S")
                avatar("F")
            }
            Text("Soon: how far apart you are, right here.")
                .font(FajsoFont.title(22))
                .foregroundStyle(.white)
            Text("Phase 0 build. Open Diagnostics to check widgets.")
                .font(FajsoFont.body(.footnote))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FajsoMetrics.cornerRadius, style: .continuous)
                .fill(FajsoColor.dawnGradient)
        )
    }

    private func avatar(_ initial: String) -> some View {
        Text(initial)
            .font(FajsoFont.body(.headline, weight: .bold))
            .foregroundStyle(FajsoColor.dusk)
            .frame(width: 44, height: 44)
            .background(Circle().fill(.white))
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
    }
}

/// Standard Home-screen tile for a feature.
struct FeatureTile: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        FajsoCard {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(FajsoColor.heart)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FajsoFont.body(.headline, weight: .semibold))
                    Text(subtitle)
                        .font(FajsoFont.body(.subheadline))
                        .foregroundStyle(FajsoColor.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FajsoColor.inkSoft)
            }
        }
    }
}
