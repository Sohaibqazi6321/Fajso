import WidgetKit
import SwiftUI

struct DistanceEntry: TimelineEntry {
    let date: Date
}

struct DistanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> DistanceEntry {
        DistanceEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DistanceEntry) -> Void) {
        completion(DistanceEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DistanceEntry>) -> Void) {
        completion(Timeline(entries: [DistanceEntry(date: Date())], policy: .after(Date().addingTimeInterval(60 * 30))))
    }
}

struct DistanceWidgetView: View {
    let entry: DistanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)

                Text(TogetherDemo.coupleName)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(TogetherDemo.distanceText)
                .font(.title2.bold())
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text("Phase 1 test")
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
        .description("Shows the distance between Sohaib and Fajr.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    DistanceWidget()
} timeline: {
    DistanceEntry(date: Date())
}

