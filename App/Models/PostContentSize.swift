import SwiftUI

/// User-selectable content type size for the post detail column.
enum PostContentSize: String, CaseIterable, Identifiable {
  case xs, small, medium, large, xl

  static let defaultsKey = "PostContentSize"

  var id: Self { self }

  var label: String {
    switch self {
    case .large: "L"
    case .medium: "M"
    case .small: "S"
    case .xl: "XL"
    case .xs: "XS"
    }
  }

  var font: Font {
    switch self {
    case .large: .system(size: 18)
    case .medium: .system(size: 15)
    case .small: .system(size: 13)
    case .xl: .system(size: 22)
    case .xs: .system(size: 11)
    }
  }
}
