import OutboxKit
import SwiftUI

/// First column: All Posts / Published / Drafts, globally and per account.
///
/// Account groups are a flat, data-driven ForEach (not DisclosureGroup) so the
/// chevron centers on two-line rows and expansion animates as row slides.
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
        statusRow(accountID: nil, status: nil, indented: false)
        statusRow(accountID: nil, status: .published, indented: false)
        statusRow(accountID: nil, status: .draft, indented: false)
      }
      Section("Accounts") {
        ForEach(accountSectionRows) { row in
          switch row.kind {
          case .account(let account):
            accountRow(for: account)
          case .filter(let accountID, let status):
            statusRow(accountID: accountID, status: status, indented: true)
          }
        }
      }
    }
    .animation(.smooth(duration: 0.3), value: expandedAccountIDs)
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

  // MARK: - Rows

  private struct AccountSectionRow: Identifiable {
    enum Kind {
      case account(Account)
      case filter(accountID: UUID, status: StoredPost.Status?)
    }

    var id: String
    var kind: Kind
  }

  private var accountSectionRows: [AccountSectionRow] {
    var rows: [AccountSectionRow] = []
    for account in model.accounts {
      rows.append(AccountSectionRow(id: "account-\(account.id)", kind: .account(account)))
      guard expandedAccountIDs.contains(account.id) else { continue }
      rows.append(
        AccountSectionRow(id: "all-\(account.id)", kind: .filter(accountID: account.id, status: nil)))
      rows.append(
        AccountSectionRow(
          id: "published-\(account.id)", kind: .filter(accountID: account.id, status: .published)))
      rows.append(
        AccountSectionRow(id: "drafts-\(account.id)", kind: .filter(accountID: account.id, status: .draft)))
    }
    return rows
  }

  /// The account row: the chevron toggles expansion, clicking anywhere else selects.
  private func accountRow(for account: Account) -> some View {
    let selection = AppModel.SidebarSelection(accountID: account.id, isAccountRow: true)
    return HStack(spacing: 6) {
      Button {
        if !expandedAccountIDs.insert(account.id).inserted {
          expandedAccountIDs.remove(account.id)
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

  private func statusRow(accountID: UUID?, status: StoredPost.Status?, indented: Bool) -> some View {
    let (title, symbol) =
      switch status {
      case .published: ("Published", "paperplane")
      case .draft: ("Drafts", "doc.text")
      case nil: ("All Posts", "tray.full")
      }
    return Label(title, systemImage: symbol)
      .padding(.leading, indented ? 26 : 0)
      .tag(AppModel.SidebarSelection(accountID: accountID, status: status))
  }
}
