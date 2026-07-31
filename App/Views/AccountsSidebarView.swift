import OutboxKit
import SwiftUI

/// First column: All Posts / Published / Drafts, globally and per account.
///
/// Hand-rolled rows in a ScrollView rather than List: macOS List refuses to
/// animate structural row changes, and the accordion feel needs real transitions.
/// Keyboard: ↑/↓ move selection, → expands an account row, ← collapses it.
struct AccountsSidebarView: View {
  @AppStorage("LastFocusedColumn") private var lastFocusedColumn = "accounts"
  @Environment(AppModel.self) private var model
  @State private var expandedAccountIDs: Set<UUID> = []
  @FocusState private var isFocused: Bool
  #if os(iOS)
    @State private var showsSettings = false
  #endif

  var body: some View {
    ScrollViewReader { proxy in
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
      .focusable()
      .focusEffectDisabled()
      .focused($isFocused)
      .onChange(of: isFocused) {
        if isFocused { lastFocusedColumn = "accounts" }
      }
      .onChange(of: model.focusRequest) {
        guard model.focusRequest == .accounts else { return }
        isFocused = true
        model.focusRequest = nil
      }
      .task {
        if lastFocusedColumn == "accounts" { isFocused = true }
      }
      #if os(macOS)
        .onMoveCommand { direction in
          handleMove(direction, proxy: proxy)
        }
      #endif
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

  // MARK: - Keyboard

  /// Every selectable row in display order, for arrow-key traversal.
  private var orderedSelections: [AppModel.SidebarSelection] {
    var ordered: [AppModel.SidebarSelection] = [
      AppModel.SidebarSelection(),
      AppModel.SidebarSelection(status: .published),
      AppModel.SidebarSelection(status: .draft),
    ]
    for account in model.accounts {
      ordered.append(AppModel.SidebarSelection(accountID: account.id, isAccountRow: true))
      guard expandedAccountIDs.contains(account.id) else { continue }
      ordered.append(AppModel.SidebarSelection(accountID: account.id))
      ordered.append(AppModel.SidebarSelection(accountID: account.id, status: .published))
      ordered.append(AppModel.SidebarSelection(accountID: account.id, status: .draft))
    }
    return ordered
  }

  #if os(macOS)
    private func handleMove(_ direction: MoveCommandDirection, proxy: ScrollViewProxy) {
      switch direction {
      case .down, .up:
        let ordered = orderedSelections
        guard !ordered.isEmpty else { return }
        let currentIndex = model.sidebarSelection.flatMap { ordered.firstIndex(of: $0) }
        let nextIndex: Int
        if let currentIndex {
          nextIndex = min(max(currentIndex + (direction == .down ? 1 : -1), 0), ordered.count - 1)
        } else {
          nextIndex = 0
        }
        model.sidebarSelection = ordered[nextIndex]
        proxy.scrollTo(ordered[nextIndex])
      case .right:
        guard let selection = model.sidebarSelection, selection.isAccountRow,
          let accountID = selection.accountID
        else { return }
        expandedAccountIDs.insert(accountID)
      case .left:
        guard let selection = model.sidebarSelection, let accountID = selection.accountID else { return }
        if selection.isAccountRow {
          expandedAccountIDs.remove(accountID)
        } else {
          // Finder-style: from a child row, jump up to the parent account row.
          let parent = AppModel.SidebarSelection(accountID: accountID, isAccountRow: true)
          model.sidebarSelection = parent
          proxy.scrollTo(parent)
        }
      @unknown default:
        break
      }
    }
  #endif

  // MARK: - Rows

  /// The account row: the chevron toggles expansion, clicking anywhere else selects.
  private func accountRow(for account: Account) -> some View {
    let selection = AppModel.SidebarSelection(accountID: account.id, isAccountRow: true)
    let isSelected = model.sidebarSelection == selection
    let emphasized = isSelected && isFocused
    return HStack(spacing: 6) {
      Button {
        if !expandedAccountIDs.insert(account.id).inserted {
          expandedAccountIDs.remove(account.id)
        }
      } label: {
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(emphasized ? Palette.selectedContent : AnyShapeStyle(.secondary))
          .rotationEffect(.degrees(expandedAccountIDs.contains(account.id) ? 90 : 0))
          .frame(width: 12)
      }
      .buttonStyle(.plain)
      .help("Show Published and Drafts")

      Button {
        select(selection)
      } label: {
        SidebarAccountRowView(account: account, isSelected: emphasized)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(rowBackground(isSelected: isSelected))
    .id(selection)
  }

  private func statusRow(accountID: UUID?, status: StoredPost.Status?, indented: Bool) -> some View {
    let selection = AppModel.SidebarSelection(accountID: accountID, status: status)
    let isSelected = model.sidebarSelection == selection
    let emphasized = isSelected && isFocused
    let (title, symbol) =
      switch status {
      case .published: ("Published", "paperplane")
      case .draft: ("Drafts", "doc.text")
      case nil: ("All Posts", "tray.full")
      }
    return Button {
      select(selection)
    } label: {
      Label(title, systemImage: symbol)
        .foregroundStyle(emphasized ? Palette.selectedContent : AnyShapeStyle(.primary))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.leading, indented ? 32 : 6)
    .padding(.trailing, 6)
    .padding(.vertical, 5)
    .background(rowBackground(isSelected: isSelected))
    .transition(.move(edge: .top).combined(with: .opacity))
    .id(selection)
  }

  private func select(_ selection: AppModel.SidebarSelection) {
    model.sidebarSelection = selection
    isFocused = true
  }

  /// Accent highlight when the sidebar owns focus, quiet gray when it doesn't.
  private func rowBackground(isSelected: Bool) -> some View {
    let fill: AnyShapeStyle =
      if !isSelected {
        AnyShapeStyle(.clear)
      } else if isFocused {
        Palette.focusedSelectionFill
      } else {
        Palette.unfocusedSelectionFill
      }
    return RoundedRectangle(cornerRadius: 6).fill(fill)
  }
}
