import OutboxKit
import SwiftUI

/// One row in the posts list: content snippet, avatar-network pair, date, and status.
struct PostRowView: View {
  var avatarURL: URL?
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
        AvatarNetworkPairView(avatarURL: avatarURL, network: post.file.metadata.network, size: 16)
        Spacer()
        Text(post.file.metadata.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
      }
      .font(.caption)
      .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 3)
  }
}
