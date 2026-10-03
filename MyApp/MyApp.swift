import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup("FileBridge") {
            ContentView()
        }
        .defaultSize(width: 1_400, height: 850)
        .windowResizability(.contentMinSize)
        .commands {
            FileBridgeCommands()
        }

        Window("About FileBridge", id: "about-filebridge") {
            AboutFileBridgeView()
        }
        .windowResizability(.contentSize)

        Settings {
            FileBridgeSettingsView()
        }
    }
}
