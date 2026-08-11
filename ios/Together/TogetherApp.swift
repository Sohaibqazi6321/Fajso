import SwiftUI

@main
struct TogetherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    TogetherSupabaseConfig.handleOpenURL(url)
                }
        }
    }
}
