import SwiftUI

@main
struct MihwalApp: App {
    @State private var appState = AppState()

    init() {
        // Nothing from a previous session is kept: inputs and results live only in tmp.
        FileStore.removeTemporaryFiles()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(appState)
                .onOpenURL { url in
                    Task { await appState.receive(url) }
                }
                #if DEBUG
                .task {
                    guard UITestSupport.isActive else { return }
                    UITestSupport.prepare()
                    if let route = await UITestSupport.initialRoute() {
                        appState.path = [route]
                    }
                }
                #endif
        }
    }
}
