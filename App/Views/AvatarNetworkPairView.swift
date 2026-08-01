import OutboxKit
import SwiftUI

/// An account's avatar and its network glyph side by side, as one `[avatar | icon]` capsule.
///
/// The avatar fills the rounded left end; the brand-colored glyph sits in its
/// own cell on the right.
struct AvatarNetworkPairView: View {
  var avatarURL: URL?
  var network: Network
  var size: CGFloat = 24

  var body: some View {
    HStack(spacing: 0) {
      avatar
        .frame(width: size, height: size)
        .clipShape(Circle())
      NetworkIconView(network: network, size: size)
        .padding(.horizontal, size * 0.2)
    }
    .padding(1)
    .background(Palette.inactiveFill, in: Capsule())
    .overlay {
      Capsule().strokeBorder(Palette.hairlineBorder, lineWidth: 1)
    }
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
