import OutboxKit
import SwiftUI

/// A toggleable endpoint: network badge, handle, and live remaining-character count.
struct EndpointChipView: View {
  var account: Account
  var isEnabled: Bool
  var remaining: Int
  var toggle: () -> Void

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: 6) {
        Image(systemName: account.network.symbolName)
        Text(account.handle)
          .lineLimit(1)
        Text("\(remaining)")
          .monospacedDigit()
          .foregroundStyle(countColor)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(chipBackground, in: Capsule())
      .overlay {
        if isOverLimit && isEnabled {
          Capsule().strokeBorder(.red, lineWidth: 1.5)
        }
      }
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.45)
    .accessibilityLabel("\(account.network.displayName) \(account.handle)")
    .accessibilityValue(isEnabled ? "on, \(remaining) characters remaining" : "off")
  }

  private var isOverLimit: Bool { remaining < 0 }

  private var chipBackground: AnyShapeStyle {
    isEnabled ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary)
  }

  private var countColor: Color {
    if isOverLimit { return .red }
    if remaining <= 20 { return .orange }
    return .secondary
  }
}
