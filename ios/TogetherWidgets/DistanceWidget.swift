import SwiftUI
import WidgetKit

struct DistanceEntry: TimelineEntry {
    let date: Date
    let state: CoupleWidgetState?
}

struct DistanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> DistanceEntry {
        DistanceEntry(date: Date(), state: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DistanceEntry) -> Void) {
        completion(DistanceEntry(date: Date(), state: CoupleWidgetCache.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DistanceEntry>) -> Void) {
        let now = Date()
        let state = CoupleWidgetCache.load()
        let nextRefresh = state?.nextRefreshDate(after: now) ?? now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [DistanceEntry(date: now, state: state)], policy: .after(nextRefresh)))
    }
}

struct DistanceWidgetView: View {
    let entry: DistanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(URL(string: "together://home"))
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.96, blue: 1.0),
                            Color(red: 0.88, green: 0.82, blue: 0.97)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label(inlineText, systemImage: "heart.fill")
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                Text(compactValue)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text(compactUnit)
                    .font(.caption2.weight(.bold))
            }
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label(partnerTitle, systemImage: "heart.fill")
                    .font(.caption.weight(.bold))
                Text(primaryText)
                    .font(.headline.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(secondaryText)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .widgetAccentable()
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color(red: 0.44, green: 0.25, blue: 0.67))
                    Text(partnerTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(primaryText)
                    .font(.title2.bold())
                    .minimumScaleFactor(0.68)
                    .lineLimit(2)
                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .foregroundStyle(Color(red: 0.22, green: 0.15, blue: 0.28))
        }
    }

    private var partnerTitle: String {
        entry.state?.partnerDisplayName.map { "You + \($0)" } ?? "Together"
    }

    private var primaryText: String {
        guard let state = entry.state else { return "Open Together to get started" }
        guard state.pairingStatus == .paired else { return "Pair with your partner" }
        guard let distance = state.effectiveDistance else { return "Waiting for both locations" }
        return TogetherDistanceFormatter.text(miles: distance.miles)
    }

    private var secondaryText: String {
        guard let state = entry.state else { return "Tap to open" }
        switch state.pairingStatus {
        case .signedOut:
            return "Sign in to continue"
        case .unpaired, .pending:
            return "Tap to finish pairing"
        case .paired:
            guard let distance = state.effectiveDistance else { return "Waiting for your partner's location" }
            if distance.origin == .developerOverride { return "Test value · this device only" }
            switch state.distanceFreshness(at: entry.date) {
            case .fresh:
                return TogetherDistanceFormatter.ageText(since: distance.sourceUpdatedAt, now: entry.date)
            case .aging:
                return "Aging · \(TogetherDistanceFormatter.ageText(since: distance.sourceUpdatedAt, now: entry.date))"
            case .stale:
                return "Stale · last known"
            case .offlineCached:
                return "Offline · last known"
            case .missing:
                return "Waiting for both locations"
            }
        }
    }

    private var inlineText: String {
        guard let state = entry.state, state.pairingStatus == .paired, let distance = state.effectiveDistance else {
            return "Open Together"
        }
        return TogetherDistanceFormatter.text(miles: distance.miles)
    }

    private var compactValue: String {
        guard let state = entry.state, let distance = state.effectiveDistance else { return "—" }
        return TogetherDistanceFormatter.compactValue(miles: distance.miles)
    }

    private var compactUnit: String {
        entry.state?.effectiveDistance == nil ? "open" : "mi"
    }
}

struct DistanceWidget: Widget {
    let kind = "TogetherDistanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DistanceProvider()) { entry in
            DistanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Together Distance")
        .description("Shows your last synced distance and freshness.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    DistanceWidget()
} timeline: {
    DistanceEntry(date: Date(), state: nil)
}
