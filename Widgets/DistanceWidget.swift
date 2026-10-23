import SwiftUI
import WidgetKit

/// Lock Screen distance widget. Phase 0: shows the spike results in the real
/// widget shapes. Phase 2 swaps in live distance. See vault note "04".
struct DistanceWidget: Widget {
    let kind = "FajsoDistanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpikeProvider()) { entry in
            DistanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Distance")
        .description("How far apart you two are.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall])
    }
}

struct DistanceWidgetView: View {
    let entry: SpikeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(URL(string: "fajso://distance"))
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    FajsoColor.background
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("Fajso · — km", systemImage: "heart.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("—")
                        .font(FajsoFont.number(18))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Fajso", systemImage: "heart.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("— km")
                    .font(FajsoFont.number(20))
                    .widgetAccentable()
                SpikeMarks(entry: entry)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(FajsoColor.heart)
                Spacer(minLength: 0)
                Text("— km")
                    .font(FajsoFont.number(28))
                    .foregroundStyle(FajsoColor.ink)
                SpikeMarks(entry: entry)
                    .foregroundStyle(FajsoColor.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
