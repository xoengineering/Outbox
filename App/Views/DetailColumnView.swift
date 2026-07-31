import SwiftUI

/// Third column: shows the selected post, or a form when composing/editing.
struct DetailColumnView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
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
    case .compose(let replyTo):
      PostFormView(mode: .new(replyTo: replyTo))
        .id("compose-\(replyTo?.absoluteString ?? "fresh")")
    case .edit(let post):
      PostFormView(mode: .edit(post))
        .id(post.id)
    }
  }
}
