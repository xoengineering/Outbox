import SwiftUI

@main
struct OutboxApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(model)
    }

    #if os(macOS)
      Settings {
        SettingsRootView()
          .environment(model)
      }
    #endif
  }
}
