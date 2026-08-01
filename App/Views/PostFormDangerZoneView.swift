import OutboxKit
import SwiftUI

/// The edit form's delete affordance, with confirmation.
struct PostFormDangerZoneView: View {
  @Environment(AppModel.self) private var model
  @State private var isConfirming = false
  var post: StoredPost

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Divider()
      HStack {
        Label("Danger Zone", systemImage: "exclamationmark.triangle")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Button("Delete Post…", role: .destructive) {
          isConfirming = true
        }
      }
    }
    .confirmationDialog(
      "Delete this post file?",
      isPresented: $isConfirming,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await model.deletePost(post) }
      }
    } message: {
      Text("This removes the local file only. Copies already on networks stay published.")
    }
  }
}
