import SwiftUI
import WidgetKit

/// Phase 0 spike screen. Answers: does the App Group work on a free-signed
/// sideload, and can the widget reach Supabase by itself?
struct DiagnosticsFeature: FajsoFeature {
    let id = "diagnostics"
    let title = "Diagnostics"
    let symbol = "stethoscope"

    func homeCard() -> AnyView {
        AnyView(FeatureTile(title: title, subtitle: "Phase 0 checks: App Group & widget network", symbol: symbol))
    }

    func destination() -> AnyView {
        AnyView(DiagnosticsView())
    }
}

struct DiagnosticsView: View {
    @State private var appBackend: BackendCheck.Result?
    @State private var widgetHeartbeat: SharedStore.Availability = .empty
    @State private var isChecking = false

    var body: some View {
        List {
            Section("Build") {
                row("Version", FajsoConfig.versionDescription)
                row("Backend configured", FajsoConfig.isBackendConfigured ? "Yes" : "No")
                row("App Group", FajsoConfig.appGroupIdentifier)
            }

            Section {
                HStack {
                    Text("Container")
                    Spacer()
                    StatusPill(
                        tone: SharedStore.isAppGroupAvailable ? .good : .bad,
                        text: SharedStore.isAppGroupAvailable ? "Available" : "Missing"
                    )
                }
                widgetHeartbeatRow
            } header: {
                Text("App Group")
            } footer: {
                Text("Add a Fajso widget, wait a minute, then tap Run checks. If the container is missing, the sideload signing dropped the App Group, and widgets fall back to fetching on their own.")
            }

            Section("Backend from the app") {
                backendRow(appBackend)
            }

            Section {
                Button {
                    Task { await runChecks() }
                } label: {
                    HStack {
                        Text("Run checks")
                        if isChecking {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isChecking)

                Button("Reload widgets") {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FajsoColor.background.ignoresSafeArea())
        .task { await runChecks() }
    }

    @ViewBuilder
    private var widgetHeartbeatRow: some View {
        HStack {
            Text("Widget wrote")
            Spacer()
            switch widgetHeartbeat {
            case .unavailable:
                StatusPill(tone: .bad, text: "Can't read")
            case .empty:
                StatusPill(tone: .neutral, text: "Not yet")
            case .found(let heartbeat):
                VStack(alignment: .trailing, spacing: 4) {
                    StatusPill(tone: .good, text: DistanceFormatter.ageText(since: heartbeat.writtenAt, now: Date()))
                    if let backend = heartbeat.backend {
                        Text("Widget network: \(backend.succeeded ? "OK" : "failed") · \(backend.detail)")
                            .font(.caption)
                            .foregroundStyle(backend.succeeded ? FajsoColor.success : FajsoColor.warning)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func backendRow(_ result: BackendCheck.Result?) -> some View {
        HStack {
            Text("Supabase")
            Spacer()
            if let result {
                StatusPill(tone: result.succeeded ? .good : .bad, text: result.detail)
            } else {
                StatusPill(tone: .neutral, text: "Not checked")
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(FajsoColor.inkSoft)
                .multilineTextAlignment(.trailing)
        }
    }

    private func runChecks() async {
        isChecking = true
        let result = await BackendCheck.run()
        appBackend = result
        SharedStore.writeHeartbeat(from: .app, backend: result)
        widgetHeartbeat = SharedStore.heartbeat(from: .widget)
        WidgetCenter.shared.reloadAllTimelines()
        isChecking = false
    }
}
