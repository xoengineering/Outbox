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
  var showsNetworkIcon = true
  var size: CGFloat = 24

  var body: some View {
    HStack(spacing: 0) {
      avatar
        .frame(width: size, height: size)
        .clipShape(Circle())
      if showsNetworkIcon {
        NetworkIconView(network: network, size: size, tint: iconTint)
          .padding(.horizontal, size * 0.2)
      }
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
