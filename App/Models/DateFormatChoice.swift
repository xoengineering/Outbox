import Foundation

/// User-selectable date rendering, applied wherever post dates appear.
enum DateFormatChoice: String, CaseIterable, Identifiable {
  case monthDayYear
  case iso
  case slashes

  static let defaultsKey = "DateFormatChoice"

  var id: Self { self }

  var label: String {
    switch self {
    case .iso: "1979-09-18"
    case .monthDayYear: "Sep 18, 1979"
    case .slashes: "09/18/1979"
    }
  }

  func dayString(from date: Date) -> String {
    switch self {
    case .iso:
      return date.formatted(
        .iso8601.year().month().day().dateSeparator(.dash))
    case .monthDayYear:
      return date.formatted(.dateTime.month(.abbreviated).day().year())
    case .slashes:
      return date.formatted(
        .dateTime.month(.twoDigits).day(.twoDigits).year())
    }
  }

  func dayAndTimeString(from date: Date) -> String {
    "\(dayString(from: date)) \(date.formatted(date: .omitted, time: .shortened))"
  }
}
