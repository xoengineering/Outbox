import OutboxKit
import SwiftUI

/// Hidden buttons carrying the app-wide keyboard shortcuts.
///
/// ⌘1/2/3 focus columns; ⌘R reply; ⌘E edit; ⌘←/→ move between columns
/// (disabled while writing, so the editor keeps caret navigation);
/// ⌘⌥1–4 select sidebar groups; ⌃0–3 toggle pill filters; ⌃4–9 select accounts.
struct KeyboardCommandsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      focusButtons
      postButtons
      sidebarGroupButtons
      filterButtons
      accountFilterButtons
    }
    .hidden()
  }

  @ViewBuilder
  private var focusButtons: some View {
    Button("Focus Accounts") {
      model.focusRequest = .accounts
    }
    .keyboardShortcut("1", modifiers: .command)
    Button("Focus Posts") {
      model.focusRequest = .posts
    }
    .keyboardShortcut("2", modifiers: .command)
    Button("Focus Form") {
      if model.detailMode != .browse { model.focusRequest = .form }
    }
    .keyboardShortcut("3", modifiers: .command)
    if model.focusedColumn != .form {
      Button("Previous Column") {
        model.moveFocus(-1)
      }
      .keyboardShortcut(.leftArrow, modifiers: .command)
      Button("Next Column") {
        model.moveFocus(1)
      }
      .keyboardShortcut(.rightArrow, modifiers: .command)
    }
  }

  @ViewBuilder
  private var postButtons: some View {
    Button("Reply") {
      if let post = model.selectedPost, post.file.metadata.isPublished {
        model.startReply(to: post)
      }
    }
    .keyboardShortcut("r", modifiers: .command)
    Button("Edit Post") {
      if let post = model.selectedPost {
        model.detailMode = .edit(post)
      }
    }
    .keyboardShortcut("e", modifiers: .command)
  }

  @ViewBuilder
  private var sidebarGroupButtons: some View {
    Button("All Posts") {
      model.sidebarSelection = AppModel.SidebarSelection()
    }
    .keyboardShortcut("1", modifiers: [.command, .option])
    Button("Published") {
      model.sidebarSelection = AppModel.SidebarSelection(status: .published)
    }
    .keyboardShortcut("2", modifiers: [.command, .option])
    Button("Drafts") {
      model.sidebarSelection = AppModel.SidebarSelection(status: .draft)
    }
    .keyboardShortcut("3", modifiers: [.command, .option])
    Button("Favorites") {
      model.sidebarSelection = AppModel.SidebarSelection(onlyFavorites: true)
    }
    .keyboardShortcut("4", modifiers: [.command, .option])
  }

  @ViewBuilder
  private var filterButtons: some View {
    Button("Clear Filters") {
      model.clearFilters()
    }
    .keyboardShortcut("0", modifiers: .control)
    Button("Filter Drafts") {
      model.toggleStatusFilter(.draft)
    }
    .keyboardShortcut("1", modifiers: .control)
    Button("Filter Published") {
      model.toggleStatusFilter(.published)
    }
    .keyboardShortcut("2", modifiers: .control)
    Button("Filter Favorites") {
      model.favoritesFilter.toggle()
    }
    .keyboardShortcut("3", modifiers: .control)
  }

  @ViewBuilder
  private var accountFilterButtons: some View {
    ForEach(Array(model.accounts.prefix(6).enumerated()), id: \.element.id) { index, account in
      Button("Select \(account.handle)") {
        model.sidebarSelection = AppModel.SidebarSelection(accountID: account.id, isAccountRow: true)
      }
      .keyboardShortcut(KeyEquivalent(Character("\(index + 4)")), modifiers: .control)
    }
  }
}
