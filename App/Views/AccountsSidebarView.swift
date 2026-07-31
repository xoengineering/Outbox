import OutboxKit
import SwiftUI

/// First column: All Posts plus one row per account, filtering the posts list.
struct AccountsSidebarView: View {
  @Environment(AppModel.self) private var model
  @Binding var showsAccounts: Bool
  @Binding var showsSettings: Bool

  var body: some View {
    @Bindable var model = model
    List(selection: $model.sidebarSelection) {
      Section {
        Label("All Posts", systemImage: "tray.full")
          .tag(AppModel.SidebarSelection.all)
      }
      Section("Accounts") {
        ForEach(model.accounts) { account in
          Label(account.handle, systemImage: account.network.symbolName)
            .tag(AppModel.SidebarSelection.account(account.id))
        }
      }
    }
    .navigationTitle("Outbox")
    .safeAreaInset(edge: .bottom) {
      HStack {
        Button("Manage Accounts", systemImage: "person.crop.circle.badge.plus") {
          showsAccounts = true
        }
        Spacer()
        Button("Settings", systemImage: "gearshape") {
          showsSettings = true
        }
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .padding(10)
    }
  }
}
