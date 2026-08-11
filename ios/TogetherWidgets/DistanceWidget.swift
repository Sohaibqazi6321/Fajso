import WidgetKit
import SwiftUI

struct DistanceEntry: TimelineEntry {
    let date: Date
    let snapshot: TogetherDistanceSnapshot
}

struct DistanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> DistanceEntry {
        DistanceEntry(date: Date(), snapshot: TogetherDemo.liveDistance())
    }

    func getSnapshot(in context: Context, completion: @escaping (DistanceEntry) -> Void) {
        completion(DistanceEntry(date: Date(), snapshot: TogetherDemo.liveDistance()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DistanceEntry>) -> Void) {
        let entry = DistanceEntry(date: Date(), snapshot: TogetherDemo.liveDistance())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30))))
    }
}

struct DistanceWidgetView: View {
    let entry: DistanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(entry.snapshot.text, systemImage: "heart.fill")
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption.bold())

                Text(entry.snapshot.lockCircleValue)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                Text("mi")
                    .font(.caption2.weight(.bold))
            }
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label(TogetherDemo.coupleName, systemImage: "heart.fill")
                    .font(.caption.weight(.bold))

                Text(entry.snapshot.text)
                    .font(.headline.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .widgetAccentable()
        default:
            homeScreenView
        }
    }

    private var homeScreenView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)

                Text(TogetherDemo.coupleName)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(entry.snapshot.text)
                .font(.title2.bold())
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text(entry.snapshot.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .togetherWidgetBackground()
    }
}

struct DistanceWidget: Widget {
    let kind = "TogetherDistanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DistanceProvider()) { entry in
            DistanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Together Distance")
        .description("Shows the distance between Sohaib and Fajr on the Home Screen or Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    DistanceWidget()
} timeline: {
    DistanceEntry(date: Date(), snapshot: TogetherDemo.liveDistance())
}

#Preview(as: .accessoryRectangular) {
    DistanceWidget()
} timeline: {
    DistanceEntry(date: Date(), snapshot: TogetherDemo.liveDistance())
}
