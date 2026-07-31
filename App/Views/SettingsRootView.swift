import SwiftUI

/// The Settings window (macOS, ⌘,) with General and Accounts tabs.
///
/// The window height adapts to the selected tab, Safari-style.
/// On iOS the same content is presented as a sheet.
struct SettingsRootView: View {
  #if os(macOS)
    private enum SettingsTab: Hashable {
      case accounts
      case general
    }

    @State private var selectedTab: SettingsTab = .general
  #else
    @Environment(\.dismiss) private var dismiss
  #endif

  var body: some View {
    #if os(macOS)
      TabView(selection: $selectedTab) {
        Tab("General", systemImage: "gearshape", value: .general) {
          GeneralSettingsView()
        }
        Tab("Accounts", systemImage: "person.crop.circle", value: .accounts) {
          AccountsSettingsView()
        }
      }
      .frame(width: 600, height: selectedTab == .general ? 220 : 560)
    #else
      NavigationStack {
        List {
          NavigationLink("General") {
            GeneralSettingsView()
              .navigationTitle("General")
          }
          NavigationLink("Accounts") {
            AccountsSettingsView()
              .navigationTitle("Accounts")
          }
        }
        .navigationTitle("Settings")
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
          }
        }
      }
    #endif
  }
}
