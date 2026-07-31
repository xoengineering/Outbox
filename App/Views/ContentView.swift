import OutboxKit
import SwiftUI

/// The three-column shell: accounts sidebar, posts list, post detail.
struct ContentView: View {
  @AppStorage("LastFocusedColumn") private var lastFocusedColumn = "accounts"
  @Environment(AppModel.self) private var model
  @FocusState private var isSearchFocused: Bool

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      AccountsSidebarView()
        .navigationSplitViewColumnWidth(min: 180, ideal: 230)
        #if os(macOS)
          .focusSection()
        #endif
    } content: {
      PostsListView()
        .searchable(text: $model.searchText, prompt: "Search posts")
        .searchFocused($isSearchFocused)
        .navigationSplitViewColumnWidth(min: 240, ideal: 320)
    } detail: {
      DetailColumnView()
        #if os(macOS)
          .frame(minWidth: 380)
        #endif
    }
    .background {
      Group {
        Button("Find") {
          isSearchFocused = true
        }
        .keyboardShortcut("f", modifiers: .command)
        Button("Focus Accounts") {
          model.focusRequest = .accounts
        }
        .keyboardShortcut("1", modifiers: .command)
        Button("Focus Posts") {
          model.focusRequest = .posts
        }
        .keyboardShortcut("2", modifiers: .command)
        Button("Focus Form") {
          if model.detailMode != .browse {
            model.focusRequest = .form
          }
        }
        .keyboardShortcut("3", modifiers: .command)
      }
      .hidden()
    }
    .task {
      await model.reloadPosts()
      if lastFocusedColumn == "search" {
        isSearchFocused = true
      }
      await model.refreshProfiles()
    }
    .onChange(of: isSearchFocused) {
      if isSearchFocused { lastFocusedColumn = "search" }
    }
    #if os(macOS)
      .navigationSubtitle(model.selectedAccountLabel)
    #endif
  }
}
