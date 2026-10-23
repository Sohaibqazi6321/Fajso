import SwiftUI
import WidgetKit

/// Home Screen photo widget. Phase 0: dawn-gradient empty state plus spike
/// results. Phase 3 shows the partner's latest photo. See vault note "05".
struct PhotoWidget: Widget {
    let kind = "FajsoPhotoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpikeProvider()) { entry in
            PhotoWidgetView(entry: entry)
        }
        .configurationDisplayName("Photo")
        .description("The latest photo from your partner.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct PhotoWidgetView: View {
    let entry: SpikeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.title3)
            Spacer(minLength: 0)
            Text("No photo yet")
                .font(FajsoFont.title(20))
            Text("Send one 💛")
                .font(FajsoFont.body(.footnote))
                .opacity(0.9)
            SpikeMarks(entry: entry)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "fajso://photos"))
        .containerBackground(for: .widget) {
            FajsoColor.dawnGradient
        }
    }
}
