import OutboxKit
import SwiftUI

/// First column: All Posts plus one row per account, filtering the posts list.
struct AccountsSidebarView: View {
  @Environment(AppModel.self) private var model
  #if os(iOS)
    @State private var showsSettings = false
  #endif

  var body: some View {
    @Bindable var model = model
    List(selection: $model.sidebarSelection) {
      Section {
        Label("All Posts", systemImage: "tray.full")
          .tag(AppModel.SidebarSelection.all)
      }
      Section("Accounts") {
        ForEach(model.accounts) { account in
          Label {
            Text(account.handle)
          } icon: {
            NetworkIconView(network: account.network)
          }
          .tag(AppModel.SidebarSelection.account(account.id))
        }
      }
    }
    .navigationTitle("Outbox")
    .safeAreaInset(edge: .bottom) {
      HStack {
        #if os(macOS)
          SettingsLink {
            Label("Settings", systemImage: "gearshape")
          }
          .help("Settings (⌘,)")
        #else
          Button("Settings", systemImage: "gearshape") {
            showsSettings = true
          }
        #endif
        Spacer()
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .padding(10)
    }
    #if os(iOS)
      .sheet(isPresented: $showsSettings) {
        SettingsRootView()
      }
    #endif
  }
}
