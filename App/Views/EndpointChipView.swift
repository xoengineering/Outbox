import OutboxKit
import SwiftUI

/// A toggleable endpoint: brand glyph, handle, and live remaining-character count.
///
/// Toggled off: gray background, brand-colored icon.
/// Toggled on: brand-colored background, white icon.
struct EndpointChipView: View {
  var account: Account
  var isEnabled: Bool
  var remaining: Int
  var toggle: () -> Void

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: 6) {
        NetworkIconView(
          network: account.network,
          size: 13,
          tint: isEnabled ? account.network.brandContrastColor : nil
        )
        Text(account.handle)
          .lineLimit(1)
          .foregroundStyle(isEnabled ? account.network.brandContrastColor : AnyShapeStyle(.primary))
        Text("\(remaining)")
          .monospacedDigit()
          .foregroundStyle(countStyle)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        isEnabled ? account.network.brandColor : AnyShapeStyle(.quaternary),
        in: Capsule()
      )
      .overlay {
        if isOverLimit && isEnabled {
          Capsule().strokeBorder(.red, lineWidth: 1.5)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(account.network.displayName) \(account.handle)")
    .accessibilityValue(isEnabled ? "on, \(remaining) characters remaining" : "off")
  }

  private var isOverLimit: Bool { remaining < 0 }

  private var countStyle: AnyShapeStyle {
    if isEnabled {
      return isOverLimit ? AnyShapeStyle(.red) : account.network.brandContrastColor
    }
    if isOverLimit { return AnyShapeStyle(.red) }
    if remaining <= 20 { return AnyShapeStyle(.orange) }
    return AnyShapeStyle(.secondary)
  }
}
