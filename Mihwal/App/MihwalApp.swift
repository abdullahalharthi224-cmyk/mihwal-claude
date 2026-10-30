import SwiftUI

@main
struct MihwalApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(appState)
        }
    }
}
