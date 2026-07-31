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
        statusRows(accountID: nil, indented: false)
      }
      Section("Accounts (custom hstack)") {
        ForEach(model.accounts) { account in
          accountRow(for: account)
          if expandedAccountIDs.contains(account.id) {
            statusRows(accountID: account.id, indented: true)
          }
        }
      }
      // Temporary A/B: same rows via DisclosureGroup, for animation comparison.
      // Not selectable — just expand/collapse to compare the feel.
      Section("Accounts (disclosuregroup)") {
        ForEach(model.accounts) { account in
          DisclosureGroup {
            Label("All Posts", systemImage: "tray.full")
            Label("Published", systemImage: "paperplane")
            Label("Drafts", systemImage: "doc.text")
          } label: {
            SidebarAccountRowView(account: account)
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

  /// The account row: the chevron toggles expansion, clicking anywhere else selects.
  private func accountRow(for account: Account) -> some View {
    let selection = accountRowSelection(for: account)
    return HStack(spacing: 6) {
      Button {
        withAnimation(.smooth(duration: 0.3)) {
          if !expandedAccountIDs.insert(account.id).inserted {
            expandedAccountIDs.remove(account.id)
          }
        }
      } label: {
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .rotationEffect(.degrees(expandedAccountIDs.contains(account.id) ? 90 : 0))
          .frame(width: 12)
      }
      .buttonStyle(.plain)
      .help("Show Published and Drafts")

      SidebarAccountRowView(account: account, isSelected: model.sidebarSelection == selection)
    }
    .tag(selection)
  }

  private func accountRowSelection(for account: Account) -> AppModel.SidebarSelection {
    AppModel.SidebarSelection(accountID: account.id, isAccountRow: true)
  }

  @ViewBuilder
  private func statusRows(accountID: UUID?, indented: Bool) -> some View {
    let indent: CGFloat = indented ? 26 : 0
    Label("All Posts", systemImage: "tray.full")
      .padding(.leading, indent)
      .tag(AppModel.SidebarSelection(accountID: accountID))
    Label("Published", systemImage: "paperplane")
      .padding(.leading, indent)
      .tag(AppModel.SidebarSelection(accountID: accountID, status: .published))
    Label("Drafts", systemImage: "doc.text")
      .padding(.leading, indent)
      .tag(AppModel.SidebarSelection(accountID: accountID, status: .draft))
  }
}
