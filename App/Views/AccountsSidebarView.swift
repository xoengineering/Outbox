import OutboxKit
import SwiftUI

/// First column: All Posts / Published / Drafts, globally and per account.
struct AccountsSidebarView: View {
  @Environment(AppModel.self) private var model
  #if os(iOS)
    @State private var showsSettings = false
  #endif

  var body: some View {
    @Bindable var model = model
    List(selection: $model.sidebarSelection) {
      Section {
        statusRows(accountID: nil)
      }
      Section("Accounts") {
        ForEach(model.accounts) { account in
          DisclosureGroup {
            statusRows(accountID: account.id)
          } label: {
            SidebarAccountRowView(account: account)
              .tag(AppModel.SidebarSelection(accountID: account.id, isAccountRow: true))
          }
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

  @ViewBuilder
  private func statusRows(accountID: UUID?) -> some View {
    Label("All Posts", systemImage: "tray.full")
      .tag(AppModel.SidebarSelection(accountID: accountID))
    Label("Published", systemImage: "paperplane")
      .tag(AppModel.SidebarSelection(accountID: accountID, status: .published))
    Label("Drafts", systemImage: "doc.text")
      .tag(AppModel.SidebarSelection(accountID: accountID, status: .draft))
  }
}
