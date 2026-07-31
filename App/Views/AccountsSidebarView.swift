import OutboxKit
import SwiftUI

/// First column: All Posts / Published / Drafts, globally and per account.
///
/// Hand-rolled rows in a ScrollView rather than List: macOS List refuses to
/// animate structural row changes, and the accordion feel needs real transitions.
struct AccountsSidebarView: View {
  @Environment(AppModel.self) private var model
  @State private var expandedAccountIDs: Set<UUID> = []
  #if os(iOS)
    @State private var showsSettings = false
  #endif

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        statusRow(accountID: nil, status: nil, indented: false)
        statusRow(accountID: nil, status: .published, indented: false)
        statusRow(accountID: nil, status: .draft, indented: false)

        Text("Accounts")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.top, 14)
          .padding(.bottom, 2)

        ForEach(model.accounts) { account in
          accountRow(for: account)
          VStack(alignment: .leading, spacing: 2) {
            if expandedAccountIDs.contains(account.id) {
              statusRow(accountID: account.id, status: nil, indented: true)
              statusRow(accountID: account.id, status: .published, indented: true)
              statusRow(accountID: account.id, status: .draft, indented: true)
            }
          }
          .clipped()
        }
      }
      .padding(8)
      .animation(.smooth(duration: 0.3), value: expandedAccountIDs)
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

  // MARK: - Rows

  /// The account row: the chevron toggles expansion, clicking anywhere else selects.
  private func accountRow(for account: Account) -> some View {
    let selection = AppModel.SidebarSelection(accountID: account.id, isAccountRow: true)
    let isSelected = model.sidebarSelection == selection
    return HStack(spacing: 6) {
      Button {
        if !expandedAccountIDs.insert(account.id).inserted {
          expandedAccountIDs.remove(account.id)
        }
      } label: {
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
          .rotationEffect(.degrees(expandedAccountIDs.contains(account.id) ? 90 : 0))
          .frame(width: 12)
      }
      .buttonStyle(.plain)
      .help("Show Published and Drafts")

      Button {
        model.sidebarSelection = selection
      } label: {
        SidebarAccountRowView(account: account, isSelected: isSelected)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(rowBackground(isSelected: isSelected))
  }

  private func statusRow(accountID: UUID?, status: StoredPost.Status?, indented: Bool) -> some View {
    let selection = AppModel.SidebarSelection(accountID: accountID, status: status)
    let isSelected = model.sidebarSelection == selection
    let (title, symbol) =
      switch status {
      case .published: ("Published", "paperplane")
      case .draft: ("Drafts", "doc.text")
      case nil: ("All Posts", "tray.full")
      }
    return Button {
      model.sidebarSelection = selection
    } label: {
      Label(title, systemImage: symbol)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.leading, indented ? 32 : 6)
    .padding(.trailing, 6)
    .padding(.vertical, 5)
    .background(rowBackground(isSelected: isSelected))
    .transition(.move(edge: .top).combined(with: .opacity))
  }

  private func rowBackground(isSelected: Bool) -> some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
  }
}
