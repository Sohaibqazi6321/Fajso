import SwiftUI
import UIKit
import WidgetKit

struct PartnerPhotoEntry: TimelineEntry {
    let date: Date
    let state: CoupleWidgetState?
    let photoData: Data?
}

struct PartnerPhotoProvider: TimelineProvider {
    func placeholder(in context: Context) -> PartnerPhotoEntry {
        PartnerPhotoEntry(date: Date(), state: nil, photoData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PartnerPhotoEntry) -> Void) {
        let state = CoupleWidgetCache.load()
        completion(PartnerPhotoEntry(date: Date(), state: state, photoData: CoupleWidgetCache.photoData(for: state)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PartnerPhotoEntry>) -> Void) {
        let state = CoupleWidgetCache.load()
        let entry = PartnerPhotoEntry(date: Date(), state: state, photoData: CoupleWidgetCache.photoData(for: state))
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

struct PartnerPhotoWidgetView: View {
    let entry: PartnerPhotoEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = entry.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.66)], startPoint: .center, endPoint: .bottom)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.96, blue: 1.0),
                        Color(red: 0.88, green: 0.82, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color(red: 0.44, green: 0.25, blue: 0.67).opacity(0.75))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Together")
                    .font(.headline.bold())
                Text(statusText)
                    .font(.caption)
                    .lineLimit(2)
                    .opacity(0.85)
            }
            .foregroundStyle(entry.photoData == nil ? Color(red: 0.22, green: 0.15, blue: 0.28) : .white)
            .padding(12)
        }
        .containerBackground(Color(red: 0.95, green: 0.91, blue: 0.99), for: .widget)
        .widgetURL(URL(string: "together://photo"))
    }

    private var statusText: String {
        guard let state = entry.state else { return "Open Together to get started" }
        guard state.pairingStatus == .paired else { return "Pair with your partner" }
        guard let photo = state.partnerPhoto, entry.photoData != nil else { return "Waiting for a photo" }
        return TogetherDistanceFormatter.ageText(since: photo.updatedAt, now: entry.date)
    }
}

struct PartnerPhotoWidget: Widget {
    let kind = "TogetherPartnerPhotoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PartnerPhotoProvider()) { entry in
            PartnerPhotoWidgetView(entry: entry)
        }
        .configurationDisplayName("Together Photo")
        .description("Shows the current photo from your partner, including while offline.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    PartnerPhotoWidget()
} timeline: {
    PartnerPhotoEntry(date: Date(), state: nil, photoData: nil)
}
