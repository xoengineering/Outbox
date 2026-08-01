import OutboxKit
import SwiftUI

/// One row in the posts list: content snippet, endpoint pairs, date, and status.
struct PostRowView: View {
  @AppStorage(DateFormatChoice.defaultsKey) private var dateFormat = DateFormatChoice.monthDayYear
  @AppStorage("ShowsRowAvatars") private var showsRowAvatars = true

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
        if post.status == .draft {
          Text("Draft")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(post.status.color.opacity(Palette.tintedCapsuleOpacity), in: Capsule())
            .foregroundStyle(post.status.color)
        }
        ForEach(pairs) { pair in
          if showsRowAvatars {
            AvatarNetworkPairView(
              avatarURL: pair.avatarURL,
              iconTint: isEmphasized ? Palette.selectedContent : nil,
              network: pair.network,
              size: 16
            )
          } else {
            NetworkIconView(
              network: pair.network,
              size: 14,
              tint: isEmphasized ? Palette.selectedContent : nil
            )
          }
        }
        if post.file.metadata.isFavorite {
          Image(systemName: "star.fill")
            .resizable()
            .scaledToFit()
            .frame(height: 16)
            .foregroundStyle(isEmphasized ? Palette.selectedContent : AnyShapeStyle(Palette.favorite))
        }
        Spacer()
        if post.status == .published {
          Text(dateFormat.dayAndTimeString(from: post.file.metadata.createdAt))
        }
      }
      .font(.caption)
      .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 6)
  }
}
