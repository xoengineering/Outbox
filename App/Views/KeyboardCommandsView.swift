import OutboxKit
import SwiftUI

#if os(macOS)
  import AppKit
#endif

/// Hidden buttons carrying the app-wide keyboard shortcuts.
///
/// ⌘1/2/3 focus columns; ⌘R reply; ⌘E edit; ⌘←/→ move between columns
/// (disabled while writing, so the editor keeps caret navigation);
/// ⌘⌥1–4 select sidebar groups; ⌃0–3 toggle status/favorite pills;
/// ⌃4–9 toggle network pills.
struct KeyboardCommandsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      focusButtons
      postButtons
      sidebarGroupButtons
      filterButtons
      networkFilterButtons
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
    #if os(macOS)
      Button("Show in Finder") {
        if let post = model.selectedPost {
          NSWorkspace.shared.activateFileViewerSelecting([post.fileURL])
        }
      }
      .keyboardShortcut("r", modifiers: [.command, .option])
    #endif
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
  private var networkFilterButtons: some View {
    ForEach(Array(Network.allCases.prefix(6).enumerated()), id: \.element) { index, network in
      Button("Filter \(network.displayName)") {
        if !model.networkFilters.insert(network).inserted {
          model.networkFilters.remove(network)
        }
      }
      .keyboardShortcut(KeyEquivalent(Character("\(index + 4)")), modifiers: .control)
    }
  }
}
