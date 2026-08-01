import Foundation

/// What an import run did with an account's remote posts.
public struct ImportReport: Equatable, Sendable {
  public var created = 0
  public var merged = 0
  public var skipped = 0

  public init() {}
}

/// Pulls an account's already-published posts from its network into the archive.
///
/// Collision policy: a remote copy we already track is skipped; a post whose
/// text matches exactly one archived Post merges into it as a new syndication
/// entry; anything ambiguous becomes a new file (err toward keeping dupes —
/// the de-duper reviews them with a human).
public struct PostImporter: Sendable {
  /// Pages fetched per account, as a runaway guard (40×40 / 40×100 posts).
  private static let maximumPages = 40

  private let onProgress: @Sendable (String) -> Void
  private let store: PostStore
  private let transport: any HTTPTransport

  public init(
    onProgress: @escaping @Sendable (String) -> Void = { _ in },
    store: PostStore,
    transport: any HTTPTransport = URLSessionTransport()
  ) {
    self.onProgress = onProgress
    self.store = store
    self.transport = transport
  }

  public func importPosts(for account: Account, credential: Credential) async throws -> ImportReport {
    let remote: [RemotePost] =
      switch account.network {
      case .bluesky: try await fetchBluesky(account: account, credential: credential)
      case .mastodon: try await fetchMastodon(account: account, credential: credential)
      case .threads: []
      }
    return try merge(remote, into: Endpoint(account: account.handle, network: account.network))
  }

  struct RemotePost {
    var createdAt: Date
    var inReplyTo: URL?
    var remoteID: String
    var remoteURL: URL?
    var text: String
  }

  // MARK: - Merging

  private func merge(_ remote: [RemotePost], into endpoint: Endpoint) throws -> ImportReport {
    var report = ImportReport()

    for (index, item) in remote.enumerated() {
      onProgress("Merging \(index + 1) of \(remote.count)…")
      let posts = try store.allPosts()
      if posts.contains(where: { post in
        post.file.metadata.syndication.contains { $0.endpoint == endpoint && $0.remoteID == item.remoteID }
      }) {
        report.skipped += 1
        continue
      }

      let normalized = normalize(item.text)
      let matches = posts.filter { normalize($0.file.body) == normalized }
      let entry = Syndication(
        account: endpoint.account,
        network: endpoint.network,
        publishedAt: item.createdAt,
        remoteID: item.remoteID,
        remoteURL: item.remoteURL
      )

      if matches.count == 1, var file = matches.first.map(\.file), let fileURL = matches.first?.fileURL {
        var copy = entry
        if item.text != file.body.trimmingCharacters(in: .whitespacesAndNewlines) {
          copy.text = item.text
        }
        file.metadata.syndication.append(copy)
        file.metadata.targets.removeAll { $0 == endpoint }
        if file.metadata.inReplyTo == nil { file.metadata.inReplyTo = item.inReplyTo }
        try store.save(file, to: fileURL)
        report.merged += 1
      } else {
        let file = PostFile(
          body: item.text + "\n",
          metadata: PostMetadata(
            createdAt: item.createdAt,
            inReplyTo: item.inReplyTo,
            syndication: [entry]
          )
        )
        try store.save(file)
        report.created += 1
      }
    }
    return report
  }

  private func normalize(_ text: String) -> String {
    String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
  }

  // MARK: - Mastodon

  private func fetchMastodon(account: Account, credential: Credential) async throws -> [RemotePost] {
    guard case .accessToken(let token) = credential else { throw AdapterError.missingCredential }

    var request = URLRequest(url: account.serverURL.appending(path: "api/v1/accounts/verify_credentials"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let identity: MastodonIdentity = try await getJSON(request)

    var statuses: [MastodonStatus] = []
    var maxID: String?
    for _ in 0..<Self.maximumPages {
      var components = URLComponents(
        url: account.serverURL.appending(path: "api/v1/accounts/\(identity.id)/statuses"),
        resolvingAgainstBaseURL: false
      )!
      components.queryItems = [
        URLQueryItem(name: "exclude_reblogs", value: "true"),
        URLQueryItem(name: "limit", value: "40"),
      ]
      if let maxID {
        components.queryItems?.append(URLQueryItem(name: "max_id", value: maxID))
      }
      var pageRequest = URLRequest(url: components.url!)
      pageRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

      let page: [MastodonStatus] = try await getJSON(pageRequest)
      guard !page.isEmpty else { break }
      statuses.append(contentsOf: page)
      onProgress("Fetched \(statuses.count) posts…")
      maxID = page.last?.id
    }

    let parentURLs = try await mastodonParentURLs(
      for: statuses,
      account: account,
      token: token
    )
    return statuses.map { status in
      RemotePost(
        createdAt: ISO8601.date(from: status.createdAt) ?? Date(),
        inReplyTo: status.inReplyToID.flatMap { parentURLs[$0] },
        remoteID: status.id,
        remoteURL: status.url.flatMap(URL.init(string:)),
        text: HTMLText.plainText(fromHTML: status.content ?? "")
      )
    }
  }

  /// Maps parent status IDs to their public URLs, reusing what we already
  /// fetched and looking up only the parents we haven't seen (other people's).
  private func mastodonParentURLs(
    for statuses: [MastodonStatus],
    account: Account,
    token: String
  ) async throws -> [String: URL] {
    var urls: [String: URL] = [:]
    for status in statuses {
      if let url = status.url.flatMap(URL.init(string:)) { urls[status.id] = url }
    }

    let missing = Set(statuses.compactMap(\.inReplyToID)).subtracting(urls.keys)
    for (index, parentID) in missing.enumerated() {
      onProgress("Resolving reply \(index + 1) of \(missing.count)…")
      var request = URLRequest(url: account.serverURL.appending(path: "api/v1/statuses/\(parentID)"))
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      // A parent can be deleted or unreachable; skip it rather than fail the import.
      guard let parent: MastodonStatus = try? await getJSON(request),
        let url = parent.url.flatMap(URL.init(string:))
      else { continue }
      urls[parentID] = url
    }
    return urls
  }

  private struct MastodonIdentity: Decodable {
    var id: String
  }

  private struct MastodonStatus: Decodable {
    var content: String?
    var createdAt: String
    var id: String
    var inReplyToID: String?
    var url: String?

    enum CodingKeys: String, CodingKey {
      case content
      case createdAt = "created_at"
      case id
      case inReplyToID = "in_reply_to_id"
      case url
    }
  }

  // MARK: - Bluesky

  private func fetchBluesky(account: Account, credential: Credential) async throws -> [RemotePost] {
    guard case .appPassword(let identifier, let password) = credential else {
      throw AdapterError.missingCredential
    }

    var sessionRequest = URLRequest(
      url: account.serverURL.appending(path: "xrpc/com.atproto.server.createSession"))
    sessionRequest.httpMethod = "POST"
    sessionRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    sessionRequest.httpBody = try JSONEncoder().encode(["identifier": identifier, "password": password])
    let session: BlueskySession = try await getJSON(sessionRequest)

    var collected: [RemotePost] = []
    var cursor: String?
    for _ in 0..<Self.maximumPages {
      var components = URLComponents(
        url: account.serverURL.appending(path: "xrpc/app.bsky.feed.getAuthorFeed"),
        resolvingAgainstBaseURL: false
      )!
      components.queryItems = [
        URLQueryItem(name: "actor", value: session.did),
        URLQueryItem(name: "limit", value: "100"),
      ]
      if let cursor {
        components.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
      }
      var pageRequest = URLRequest(url: components.url!)
      pageRequest.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

      let page: AuthorFeed = try await getJSON(pageRequest)
      for item in page.feed where item.reason == nil && item.post.author.did == session.did {
        guard let recordKey = item.post.uri.split(separator: "/").last else { continue }
        collected.append(
          RemotePost(
            createdAt: ISO8601.date(from: item.post.record.createdAt) ?? Date(),
            inReplyTo: (item.post.record.reply?.parent?.uri).flatMap(Self.blueskyWebURL(fromRecordURI:)),
            remoteID: item.post.uri,
            remoteURL: URL(string: "https://bsky.app/profile/\(session.handle)/post/\(recordKey)"),
            text: item.post.record.text
          ))
      }
      onProgress("Fetched \(collected.count) posts…")
      guard let nextCursor = page.cursor, !page.feed.isEmpty else { break }
      cursor = nextCursor
    }
    return collected
  }

  private struct BlueskySession: Decodable {
    var accessJwt: String
    var did: String
    var handle: String
  }

  private struct AuthorFeed: Decodable {
    var cursor: String?
    var feed: [FeedItem]
  }

  private struct FeedItem: Decodable {
    var post: FeedPost
    var reason: ReasonMarker?
  }

  private struct FeedPost: Decodable {
    var author: FeedAuthor
    var record: FeedRecord
    var uri: String
  }

  private struct FeedAuthor: Decodable {
    var did: String
  }

  private struct FeedRecord: Decodable {
    var createdAt: String
    var reply: FeedReply?
    var text: String
  }

  private struct FeedReply: Decodable {
    var parent: FeedReplyRef?
  }

  private struct FeedReplyRef: Decodable {
    var uri: String
  }

  /// `at://did:plc:x/app.bsky.feed.post/rkey` → the public bsky.app permalink.
  /// bsky.app accepts a DID in the profile slot, so no handle lookup is needed.
  static func blueskyWebURL(fromRecordURI uri: String) -> URL? {
    let parts = uri.replacingOccurrences(of: "at://", with: "").split(separator: "/")
    guard parts.count == 3 else { return nil }
    return URL(string: "https://bsky.app/profile/\(parts[0])/post/\(parts[2])")
  }

  private struct ReasonMarker: Decodable {
    var type: String?

    enum CodingKeys: String, CodingKey {
      case type = "$type"
    }
  }

  // MARK: - Shared

  private func getJSON<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await transport.send(request)
    guard (200..<300).contains(response.statusCode) else {
      throw AdapterError.httpError(
        statusCode: response.statusCode,
        message: String(bytes: data, encoding: .utf8) ?? ""
      )
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }
}
