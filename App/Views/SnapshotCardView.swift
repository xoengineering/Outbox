import OutboxKit
import SwiftUI

/// A quoted preview of the upstream post being replied to.
struct SnapshotCardView: View {
  var snapshot: ReplySnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(snapshot.author)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(snapshot.text)
        .font(.callout)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(10)
    .background(Palette.editorFill, in: RoundedRectangle(cornerRadius: 8))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 1)
        .fill(.tertiary)
        .frame(width: 3)
        .padding(.vertical, 6)
        .padding(.leading, 2)
    }
  }
}
