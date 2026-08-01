import OutboxKit
import SwiftUI

/// An account in the sidebar: badged avatar, display name, and handle beneath.
struct SidebarAccountRowView: View {
  var account: Account
  var isSelected = false

  var body: some View {
    HStack(spacing: 8) {
      AvatarBadgeView(avatarURL: account.avatarURL, network: account.network, size: 28)
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
