import OutboxKit
import SwiftUI

/// An account in the sidebar: avatar, display name, and network + handle beneath.
struct SidebarAccountRowView: View {
  var account: Account
  var isSelected = false

  var body: some View {
    HStack(spacing: 8) {
      avatar
      VStack(alignment: .leading, spacing: 1) {
        Text(account.displayName ?? account.handle)
          .lineLimit(1)
        HStack(spacing: 4) {
          NetworkIconView(
            network: account.network,
            size: 10,
            tint: isSelected ? AnyShapeStyle(.white) : nil
          )
          Text(account.handle)
            .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }

  @ViewBuilder
  private var avatar: some View {
    AsyncImage(url: account.avatarURL) { image in
      image
        .resizable()
        .scaledToFill()
    } placeholder: {
      Image(systemName: "person.crop.circle.fill")
        .resizable()
        .foregroundStyle(.quaternary)
    }
    .frame(width: 28, height: 28)
    .clipShape(Circle())
  }
}
