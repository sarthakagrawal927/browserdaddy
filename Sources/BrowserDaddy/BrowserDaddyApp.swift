import SwiftUI

@main
struct BrowserDaddyApp: App {
    var body: some Scene {
        WindowGroup("browserdaddy") {
            Text("browserdaddy")
                .font(.largeTitle.monospaced())
                .frame(minWidth: 880, minHeight: 600)
        }
        .defaultSize(width: 1100, height: 720)
        .windowStyle(.hiddenTitleBar)
    }
}
