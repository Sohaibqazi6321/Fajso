import SwiftUI
import WidgetKit

@main
struct FajsoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                let backend = await BackendCheck.run()
                SharedStore.writeHeartbeat(from: .app, backend: backend)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
