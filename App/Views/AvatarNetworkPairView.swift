import OutboxKit
import SwiftUI

/// An account's avatar and its network glyph side by side, as one `[avatar | icon]` capsule.
///
/// The avatar fills the rounded left end; the brand-colored glyph sits in its
/// own cell on the right.
struct AvatarNetworkPairView: View {
  var avatarURL: URL?
  var iconTint: AnyShapeStyle?
  var network: Network
  var size: CGFloat = 24

  var body: some View {
    HStack(spacing: 0) {
      avatar
        .frame(width: size, height: size)
        .clipShape(Circle())
      // Glyph shapes vary, so their square frames leave uneven negative space.
      // Oversize each glyph and crop it to an avatar-sized circle for a
      // consistent footprint.
      NetworkIconView(network: network, size: size * 1.35, tint: iconTint)
        .frame(width: size, height: size)
        .clipShape(Circle())
        .padding(.horizontal, size * 0.2)
    }
    .padding(1)
    .background(Palette.inactiveFill, in: Capsule())
    .accessibilityElement(children: .combine)
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
}
