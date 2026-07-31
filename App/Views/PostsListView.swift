import OutboxKit
import SwiftUI

/// Second column: the archive, newest first, filtered by sidebar selection and search.
struct PostsListView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    List(model.visiblePosts, selection: $model.selectedPostID) { post in
      PostRowView(post: post)
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
