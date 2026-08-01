import SwiftUI

/// Third column: shows the selected post, or a form when composing/editing.
struct DetailColumnView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      switch model.detailMode {
      case .browse:
        if let post = model.selectedPost {
          PostDetailView(post: post)
        } else {
          ContentUnavailableView(
            "No Post Selected",
            systemImage: "square.and.pencil",
            description: Text("Select a post, or press ⌘N to write a new one.")
          )
        }
      case .compose(let reply):
        PostFormView(mode: .new(reply: reply))
          .id(composeIdentity(for: reply))
      case .edit(let post):
        PostFormView(mode: .edit(post))
          .id(post.id)
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button("New Post", systemImage: "square.and.pencil") {
          model.startNewPost()
        }
        .keyboardShortcut("n", modifiers: .command)
        .help("New Post (⌘N)")
      }
    }
  }

  private func composeIdentity(for reply: AppModel.ReplyContext?) -> String {
    switch reply {
    case .external(let url): "compose-external-\(url.absoluteString)"
    case .thread(let parent): "compose-thread-\(parent.fileURL.path)"
    case nil: "compose-fresh"
    }
  }
}
