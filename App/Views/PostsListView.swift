import OutboxKit
import SwiftUI

/// Second column: the archive, newest first, filtered by sidebar selection and search.
struct PostsListView: View {
  @AppStorage("LastFocusedColumn") private var lastFocusedColumn = "accounts"
  @Environment(AppModel.self) private var model
  @FocusState private var isFocused: Bool

  var body: some View {
    @Bindable var model = model
    List(model.visiblePosts, selection: $model.selectedPostID) { post in
      PostRowView(post: post)
    }
    .focused($isFocused)
    #if os(macOS)
      .focusSection()
    #endif
    .onChange(of: isFocused) {
      if isFocused { lastFocusedColumn = "posts" }
    }
    .onChange(of: model.focusRequest) {
      guard model.focusRequest == .posts else { return }
      isFocused = true
      model.focusRequest = nil
    }
    .task {
      if lastFocusedColumn == "posts" { isFocused = true }
    }
    .navigationTitle(model.selectedAccountLabel)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("New Post", systemImage: "square.and.pencil") {
          model.startNewPost()
        }
        .keyboardShortcut("n", modifiers: .command)
      }
    }
    .onChange(of: model.selectedPostID) {
      model.detailMode = .browse
    }
    .overlay {
      if model.visiblePosts.isEmpty {
        ContentUnavailableView(
          "No Posts",
          systemImage: "tray",
          description: Text("Press ⌘N to write your first post.")
        )
      }
    }
  }
}
