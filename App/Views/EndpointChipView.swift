import OutboxKit
import SwiftUI

/// A toggleable endpoint: brand glyph, handle, and live remaining-character count.
///
/// Toggled off: gray background, icon and text screened to 50%.
/// Toggled on: solid brand background, white icon and text.
/// Toggled on but over the limit: brand background screened to 10%, icon and
/// handle at 50%, so the full-strength red count and outline carry the warning.
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
          tint: isSolidBrand ? account.network.brandContrastColor : nil
        )
        .opacity(isSolidBrand ? 1 : 0.5)
        Text(account.handle)
          .lineLimit(1)
          .foregroundStyle(isSolidBrand ? account.network.brandContrastColor : AnyShapeStyle(.primary))
          .opacity(isSolidBrand ? 1 : 0.5)
        Text("\(remaining)")
          .monospacedDigit()
          .foregroundStyle(countStyle)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(backgroundStyle, in: Capsule())
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

  /// Full-strength brand background only when enabled and within the limit.
  private var isSolidBrand: Bool { isEnabled && !isOverLimit }

  private var backgroundStyle: AnyShapeStyle {
    guard isEnabled else { return AnyShapeStyle(.quaternary) }
    guard !isOverLimit else { return AnyShapeStyle(account.network.brandColor.opacity(0.1)) }
    return account.network.brandColor
  }

  private var countStyle: AnyShapeStyle {
    if isOverLimit { return AnyShapeStyle(.red) }
    if isSolidBrand { return account.network.brandContrastColor }
    if remaining <= 20 { return AnyShapeStyle(.orange) }
    return AnyShapeStyle(.secondary)
  }
}
