import SwiftUI

/// The Settings window (macOS, ⌘,) with General and Accounts tabs.
///
/// On iOS the same content is presented as a sheet.
struct SettingsRootView: View {
  #if os(iOS)
    @Environment(\.dismiss) private var dismiss
  #endif

  var body: some View {
    #if os(macOS)
      TabView {
        Tab("General", systemImage: "gearshape") {
          GeneralSettingsView()
        }
        Tab("Accounts", systemImage: "person.crop.circle") {
          AccountsSettingsView()
        }
      }
      .frame(minWidth: 520, minHeight: 340)
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
