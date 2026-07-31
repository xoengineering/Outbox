import OutboxKit
import SwiftUI

/// First column: All Posts / Published / Drafts, globally and per account.
struct AccountsSidebarView: View {
  @Environment(AppModel.self) private var model
  @State private var expandedAccountIDs: Set<UUID> = []
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
          DisclosureGroup(isExpanded: isExpanded(account)) {
            statusRows(accountID: account.id)
          } label: {
            Label {
              Text(account.handle)
            } icon: {
              NetworkIconView(network: account.network)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
              withAnimation {
                isExpanded(account).wrappedValue.toggle()
              }
            }
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

  private func isExpanded(_ account: Account) -> Binding<Bool> {
    Binding(
      get: { expandedAccountIDs.contains(account.id) },
      set: { expanded in
        if expanded {
          expandedAccountIDs.insert(account.id)
        } else {
          expandedAccountIDs.remove(account.id)
        }
      }
    )
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
