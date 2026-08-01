import OutboxKit
import SwiftUI

/// An account in the sidebar: avatar, display name, and network + handle beneath.
struct SidebarAccountRowView: View {
  var account: Account
  var isSelected = false

  var body: some View {
    HStack(spacing: 8) {
      AvatarNetworkPairView(avatarURL: account.avatarURL, network: account.network, size: 26)
      VStack(alignment: .leading, spacing: 1) {
        Text(account.displayName ?? account.handle)
          .lineLimit(1)
          .foregroundStyle(isSelected ? Palette.selectedContent : AnyShapeStyle(.primary))
        Text(account.handle)
          .lineLimit(1)
          .font(.caption)
          .foregroundStyle(isSelected ? Palette.selectedSecondaryContent : AnyShapeStyle(.secondary))
      }
    }
    .padding(.vertical, 2)
  }
}
