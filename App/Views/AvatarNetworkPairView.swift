import OutboxKit
import SwiftUI

/// An account's avatar and its network glyph side by side, as one capsule:
/// `[avatar | icon]`. The avatar fills the rounded left end; the brand-colored
/// glyph sits in its own cell on the right.
struct AvatarNetworkPairView: View {
  var avatarURL: URL?
  var network: Network
  var size: CGFloat = 24

  var body: some View {
    HStack(spacing: 0) {
      avatar
        .frame(width: size, height: size)
        .clipShape(Circle())
      Divider()
        .frame(height: size * 0.55)
      NetworkIconView(network: network, size: size * 0.5)
        .frame(width: size * 0.95, height: size)
    }
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
