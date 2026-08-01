import OutboxKit
import SwiftUI

/// The edit form's trash affordance, with confirmation.
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
        Button("Move to Trash…", role: .destructive) {
          isConfirming = true
        }
      }
    }
    .confirmationDialog(
      "Move this post to the Trash?",
      isPresented: $isConfirming,
      titleVisibility: .visible
    ) {
      Button("Move to Trash", role: .destructive) {
        Task { await model.trashPost(post) }
      }
    } message: {
      Text(
        "Its file and any media move to the Trash, so you can put them back. "
          + "Copies already on networks stay published.")
    }
  }
}
