import Foundation
import Observation
import OutboxKit

/// Where the local post archive lives.
///
/// Defaults to the app's Documents folder;
/// on macOS the user can pick any folder, remembered via a security-scoped bookmark.
@MainActor @Observable final class ArchiveFolder {
  private static let bookmarkDefaultsKey = "ArchiveFolderBookmark"

  private(set) var url: URL

  init() {
    url = Self.resolveBookmark() ?? Self.defaultURL
  }

  static var defaultURL: URL {
    URL.documentsDirectory.appending(path: "Outbox", directoryHint: .isDirectory)
  }

  func choose(_ newURL: URL) {
    #if os(macOS)
      guard newURL.startAccessingSecurityScopedResource() else { return }
      defer { newURL.stopAccessingSecurityScopedResource() }
      guard let bookmark = try? newURL.bookmarkData(options: .withSecurityScope) else { return }
      UserDefaults.standard.set(bookmark, forKey: Self.bookmarkDefaultsKey)
      url = newURL
    #endif
  }

  func resetToDefault() {
    UserDefaults.standard.removeObject(forKey: Self.bookmarkDefaultsKey)
    url = Self.defaultURL
  }

  func withAccess<T: Sendable>(_ work: (URL) async throws -> T) async rethrows -> T {
    let isScoped = url.startAccessingSecurityScopedResource()
    defer {
      if isScoped { url.stopAccessingSecurityScopedResource() }
    }
    return try await work(url)
  }

  private static func resolveBookmark() -> URL? {
    #if os(macOS)
      guard let bookmark = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else { return nil }
      var isStale = false
      let resolved = try? URL(
        resolvingBookmarkData: bookmark,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      return isStale ? nil : resolved
    #else
      return nil
    #endif
  }
}
