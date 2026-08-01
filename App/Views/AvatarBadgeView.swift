import OutboxKit
import SwiftUI

/// An account's avatar with its network glyph layered as a badge in the
/// bottom-trailing corner — a mini take on HIG layered icons.
struct AvatarBadgeView: View {
  var avatarURL: URL?
  var network: Network
  var size: CGFloat = 28

  var body: some View {
    avatar
      .frame(width: size, height: size)
      .clipShape(Circle())
      .overlay(alignment: .bottomTrailing) {
        badge
      }
      .padding(.bottom, badgeOffset)
      .padding(.trailing, badgeOffset)
      .accessibilityLabel(network.displayName)
  }

  @ViewBuilder
  private var avatar: some View {
    AsyncImage(url: avatarURL) { image in
      image
        .resizable()
        .scaledToFill()
    } placeholder: {
      Image(systemName: "person.crop.circle.fill")
        .resizable()
        .foregroundStyle(.quaternary)
    }
  }

  private var badge: some View {
    NetworkIconView(network: network, size: size * 0.4)
      .padding(size * 0.08)
      .background(Palette.surface, in: Circle())
      .offset(x: badgeOffset, y: badgeOffset)
  }

  /// How far the badge pokes out past the avatar's corner.
  private var badgeOffset: CGFloat { size * 0.12 }
}
