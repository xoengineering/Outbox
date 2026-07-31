import OutboxKit
import SwiftUI

/// One row in the posts list: first line, snippet, account, date, and status.
struct PostRowView: View {
  var post: StoredPost

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .top) {
        Text(post.file.body.trimmingCharacters(in: .whitespacesAndNewlines))
          .lineLimit(2)
        Spacer()
        if post.status == .draft {
          Text("Draft")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(post.status.color.opacity(Palette.tintedCapsuleOpacity), in: Capsule())
            .foregroundStyle(post.status.color)
        }
      }
      HStack(spacing: 4) {
        NetworkIconView(network: post.file.metadata.network, size: 10)
        Text(post.file.metadata.account)
          .lineLimit(1)
        Spacer()
        Text(post.file.metadata.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
      }
      .font(.caption)
      .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 3)
  }
}
