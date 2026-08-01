import SwiftUI

@main
struct OutboxApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(model)
    }
    .commands {
      SidebarCommands()
    }

    #if os(macOS)
      Settings {
        SettingsRootView()
          .environment(model)
      }
      .windowResizability(.contentSize)
    #endif
  }
}
