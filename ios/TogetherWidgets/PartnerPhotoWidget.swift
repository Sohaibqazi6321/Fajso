import WidgetKit
import SwiftUI
import UIKit

struct PartnerPhotoEntry: TimelineEntry {
    let date: Date
    let snapshot: TogetherPartnerPhotoSnapshot
}

struct PartnerPhotoProvider: TimelineProvider {
    func placeholder(in context: Context) -> PartnerPhotoEntry {
        PartnerPhotoEntry(date: Date(), snapshot: TogetherDemo.partnerPhoto())
    }

    func getSnapshot(in context: Context, completion: @escaping (PartnerPhotoEntry) -> Void) {
        completion(PartnerPhotoEntry(date: Date(), snapshot: TogetherDemo.partnerPhoto()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PartnerPhotoEntry>) -> Void) {
        let entry = PartnerPhotoEntry(date: Date(), snapshot: TogetherDemo.partnerPhoto())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30))))
    }
}

struct PartnerPhotoWidgetView: View {
    let entry: PartnerPhotoEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            widgetImage
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Together")
                    .font(.headline.bold())

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .foregroundStyle(.white)
            .padding(12)
        }
        .containerBackground(.black, for: .widget)
        .widgetURL(URL(string: "together://photo"))
    }

    private var statusText: String {
        entry.snapshot.statusText
    }

    private var widgetImage: Image {
        if
            let data = entry.snapshot.data,
            let image = UIImage(data: data)
        {
            return Image(uiImage: image)
        }

        guard
            let data = Data(base64Encoded: TogetherDemo.testPhotoBase64),
            let image = UIImage(data: data)
        else {
            return Image(systemName: "person.crop.square.fill")
        }

        return Image(uiImage: image)
    }
}

struct PartnerPhotoWidget: Widget {
    let kind = "TogetherPartnerPhotoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PartnerPhotoProvider()) { entry in
            PartnerPhotoWidgetView(entry: entry)
        }
        .configurationDisplayName("Together Photo")
        .description("Shows the latest photo from your partner.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    PartnerPhotoWidget()
} timeline: {
    PartnerPhotoEntry(date: Date(), snapshot: TogetherDemo.partnerPhoto())
}
