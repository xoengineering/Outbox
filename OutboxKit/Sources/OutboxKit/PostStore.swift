import Foundation

/// Writes post files into the on-disk archive.
///
/// Layout: `<base>/<YYYY>/<MM>/<DD>/<NN>-<slug>.md` — one file per Post, with a
/// zero-padded Nth-of-day prefix so a day's folder lists chronologically;
/// network copies live inside the frontmatter.
public struct PostStore: Sendable {
  public var baseDirectory: URL
  public var timeZone: TimeZone

  public init(baseDirectory: URL, timeZone: TimeZone = .current) {
    self.baseDirectory = baseDirectory
    self.timeZone = timeZone
  }

  /// Saves a new post file, deriving its path from metadata and content.
  ///
  /// - Returns: The saved file's URL.
  @discardableResult
  public func save(_ file: PostFile) throws -> URL {
    let directory = dayDirectory(for: file.metadata)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let slug = Slug.from(file.body)
    var nthOfDay = try existingPostCount(in: directory) + 1
    var url = directory.appendingPathComponent(fileName(nthOfDay: nthOfDay, slug: slug))
    while FileManager.default.fileExists(atPath: url.path) {
      nthOfDay += 1
      url = directory.appendingPathComponent(fileName(nthOfDay: nthOfDay, slug: slug))
    }

    try save(file, to: url)
    return url
  }

  /// Writes a post file to an exact URL, replacing any existing content.
  public func save(_ file: PostFile, to url: URL) throws {
    let serialized = try file.serialized()
    try serialized.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Reads every parseable post in the archive, newest first.
  ///
  /// Files that fail to parse are skipped, never destroyed.
  public func allPosts() throws -> [StoredPost] {
    guard FileManager.default.fileExists(atPath: baseDirectory.path) else { return [] }

    let enumerator = FileManager.default.enumerator(
      at: baseDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    var posts: [StoredPost] = []
    while let fileURL = enumerator?.nextObject() as? URL {
      guard fileURL.pathExtension == "md" else { continue }
      guard let text = try? String(contentsOf: fileURL, encoding: .utf8),
        let file = try? PostFile.parse(text)
      else { continue }
      posts.append(StoredPost(file: file, fileURL: fileURL))
    }
    return posts.sorted { $0.file.metadata.createdAt > $1.file.metadata.createdAt }
  }

  public func delete(_ post: StoredPost) throws {
    try FileManager.default.removeItem(at: post.fileURL)
  }

  /// The archive-relative path of a file, used for `in_reply_to_post` references.
  public func relativePath(of fileURL: URL) -> String {
    let base = baseDirectory.standardizedFileURL.path
    let full = fileURL.standardizedFileURL.path
    guard full.hasPrefix(base) else { return full }
    return String(full.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  private func dayDirectory(for metadata: PostMetadata) -> URL {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.year, .month, .day], from: metadata.createdAt)

    return
      baseDirectory
      .appendingPathComponent(String(format: "%04d", components.year!), isDirectory: true)
      .appendingPathComponent(String(format: "%02d", components.month!), isDirectory: true)
      .appendingPathComponent(String(format: "%02d", components.day!), isDirectory: true)
  }

  private func fileName(nthOfDay: Int, slug: String) -> String {
    String(format: "%02d-%@.md", nthOfDay, slug)
  }

  private func existingPostCount(in directory: URL) throws -> Int {
    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    return contents.count { $0.hasSuffix(".md") }
  }
}
