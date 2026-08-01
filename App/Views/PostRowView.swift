import OutboxKit
import SwiftUI

/// One row in the posts list: content snippet, endpoint pairs, date, and status.
struct PostRowView: View {
  /// True when this row is selected and its list owns focus.
  var isEmphasized = false
  var pairs: [EndpointPair]
  var post: StoredPost

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(post.file.body.trimmingCharacters(in: .whitespacesAndNewlines))
        .font(.title3)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 4) {
        ForEach(pairs) { pair in
          AvatarNetworkPairView(
            avatarURL: pair.avatarURL,
            iconTint: isEmphasized ? Palette.selectedContent : nil,
            network: pair.network,
            size: 16
          )
        }
        if post.file.metadata.isFavorite {
          Image(systemName: "star.fill")
            .resizable()
            .scaledToFit()
            .frame(height: 16)
            .foregroundStyle(isEmphasized ? Palette.selectedContent : AnyShapeStyle(Palette.favorite))
        }
        Spacer()
        if post.status == .draft {
          Text("Draft")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(post.status.color.opacity(Palette.tintedCapsuleOpacity), in: Capsule())
            .foregroundStyle(post.status.color)
        } else {
          Text(post.file.metadata.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
        }
      }
      .font(.caption)
      .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 6)
  }
}
