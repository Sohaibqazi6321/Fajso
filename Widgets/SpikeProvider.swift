import SwiftUI
import WidgetKit

/// Phase 0 timeline provider shared by both widgets. On each refresh the widget
/// calls Supabase itself, reads the app's heartbeat from the App Group, and writes
/// its own heartbeat back so the app's Diagnostics screen can show it.
/// Replaced by real distance/photo providers in Phases 2 and 3.
struct SpikeEntry: TimelineEntry {
    let date: Date
    let appGroupAvailable: Bool
    let appHeartbeat: SharedStore.Availability
    let backend: BackendCheck.Result?

    static let placeholder = SpikeEntry(date: Date(), appGroupAvailable: true, appHeartbeat: .empty, backend: nil)
}

struct SpikeProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SpikeEntry) -> Void) {
        completion(currentEntry(backend: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeEntry>) -> Void) {
        Task {
            let backend = await BackendCheck.run(timeout: 5)
            SharedStore.writeHeartbeat(from: .widget, backend: backend)
            let entry = currentEntry(backend: backend)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }

    private func currentEntry(backend: BackendCheck.Result?) -> SpikeEntry {
        SpikeEntry(
            date: Date(),
            appGroupAvailable: SharedStore.isAppGroupAvailable,
            appHeartbeat: SharedStore.heartbeat(from: .app),
            backend: backend
        )
    }
}

/// Two compact ✓/✗ marks: App Group ("AG") and network ("NET").
struct SpikeMarks: View {
    let entry: SpikeEntry

    var body: some View {
        HStack(spacing: 6) {
            mark("AG", ok: appGroupOK)
            mark("NET", ok: entry.backend?.succeeded)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
    }

    private var appGroupOK: Bool? {
        guard entry.appGroupAvailable else { return false }
        if case .found = entry.appHeartbeat { return true }
        return nil
    }

    private func mark(_ label: String, ok: Bool?) -> some View {
        let symbol: String
        switch ok {
        case .some(true): symbol = "checkmark"
        case .some(false): symbol = "xmark"
        case .none: symbol = "questionmark"
        }
        return Label(label, systemImage: symbol)
            .labelStyle(.titleAndIcon)
    }
}
