import OutboxKit
import SwiftUI

/// The full post a new thread continuation follows, rendered whole above the form.
struct ThreadParentPreviewView: View {
  var parent: StoredPost

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Continuing thread", systemImage: "text.append")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(parent.file.body.trimmingCharacters(in: .whitespacesAndNewlines))
        .font(.callout)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(10)
    .background(Palette.editorFill, in: RoundedRectangle(cornerRadius: 8))
  }
}
