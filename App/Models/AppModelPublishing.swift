import Foundation
import OutboxKit

/// Publishing, drafting, and target construction for `AppModel`.
extension AppModel {
  func publish(
    attachments: [PendingAttachment] = [],
    body: String,
    reply: ReplyContext?
  ) async -> [Publisher.TargetResult] {
    let targets = targets(for: enabledAccounts, reply: reply)
    let externalReply: URL? =
      if case .external(let url) = reply { url } else { nil }
    let snapshot = await fetchSnapshot(for: externalReply)

    let results = await archiveFolder.withAccess { baseURL -> [Publisher.TargetResult] in
      let store = PostStore(baseDirectory: baseURL)
      var threadPath: String?
      if case .thread(let parent) = reply {
        threadPath = store.relativePath(of: parent.fileURL)
      }
      let output = await self.makePublisher(store: store).publish(
        attachments: attachments,
        body: body,
        inReplyTo: externalReply,
        inReplyToPost: threadPath,
        inReplyToSnapshot: snapshot,
        to: targets
      )
      return output.results
    }
    await reloadPosts()
    return results
  }

  func saveDraft(attachments: [PendingAttachment] = [], body: String, reply: ReplyContext?) async {
    let targets = targets(for: enabledAccounts, reply: reply)
    let externalReply: URL? =
      if case .external(let url) = reply { url } else { nil }
    let snapshot = await fetchSnapshot(for: externalReply)

    _ = await archiveFolder.withAccess { baseURL -> [Publisher.TargetResult] in
      let store = PostStore(baseDirectory: baseURL)
      var threadPath: String?
      if case .thread(let parent) = reply {
        threadPath = store.relativePath(of: parent.fileURL)
      }
      return self.makePublisher(store: store).saveDraft(
        attachments: attachments,
        body: body,
        inReplyTo: externalReply,
        inReplyToPost: threadPath,
        inReplyToSnapshot: snapshot,
        for: targets
      ).results
    }
    await reloadPosts()
  }

  /// Fetches a keepable copy of an upstream post, using any account on its network.
  func fetchSnapshot(for url: URL?) async -> ReplySnapshot? {
    guard let url else { return nil }
    let network = inferredNetwork(of: url)
    guard let account = accounts.first(where: { $0.network == network }) else { return nil }
    return await ReplyResolver().snapshot(url, account: account, credential: credential(for: account))
  }

  /// Publishes a post's pending targets, threading replies per network.
  func publishExisting(_ post: StoredPost) async -> [Publisher.TargetResult] {
    let results = await archiveFolder.withAccess { baseURL -> [Publisher.TargetResult] in
      let store = PostStore(baseDirectory: baseURL)
      let parentPost = post.file.metadata.inReplyToPost.flatMap { path in
        self.posts.first { store.relativePath(of: $0.fileURL) == path }
      }
      let targets = post.file.metadata.targets.compactMap { endpoint -> Publisher.Target? in
        guard let account = self.account(for: endpoint) else { return nil }
        var parentURL: URL?
        if let external = post.file.metadata.inReplyTo,
          self.inferredNetwork(of: external) == account.network
        {
          parentURL = external
        }
        if let parentPost,
          let copy = parentPost.file.metadata.syndication.first(where: { $0.network == account.network })
        {
          parentURL = copy.remoteURL
        }
        return Publisher.Target(
          account: account,
          credential: self.credential(for: account),
          replyParentURL: parentURL
        )
      }
      return await self.makePublisher(store: store).publishExisting(post, to: targets).results
    }
    await reloadPosts()
    return results
  }

  /// Edits the canonical body and pushes the change to copies whose network
  /// supports edits (Mastodon); others record their live text as divergence.
  func editPublished(_ post: StoredPost, body: String) async -> [Publisher.TargetResult] {
    let targets = post.file.metadata.syndication.compactMap { copy -> Publisher.Target? in
      guard let account = account(for: copy.endpoint) else { return nil }
      return Publisher.Target(account: account, credential: credential(for: account))
    }
    let results = await archiveFolder.withAccess { baseURL -> [Publisher.TargetResult] in
      let store = PostStore(baseDirectory: baseURL)
      return await self.makePublisher(store: store)
        .editSyndicated(post, newBody: body, to: targets).results
    }
    await reloadPosts()
    return results
  }

  /// Updates a post's canonical body and (for unsyndicated endpoints) its targets.
  func update(_ post: StoredPost, body: String, targetAccountIDs: Set<UUID>) async throws {
    var file = post.file
    file.body = body
    let syndicated = Set(file.metadata.syndication.map(\.endpoint))
    file.metadata.targets =
      accounts
      .filter { targetAccountIDs.contains($0.id) }
      .map { Endpoint(account: $0.handle, network: $0.network) }
      .filter { !syndicated.contains($0) }
    try await archiveFolder.withAccess { baseURL in
      try PostStore(baseDirectory: baseURL).save(file, to: post.fileURL)
    }
    await reloadPosts()
  }

  func deletePost(_ post: StoredPost) async {
    try? await archiveFolder.withAccess { baseURL in
      try PostStore(baseDirectory: baseURL).delete(post)
    }
    if selectedPostID == post.id { selectedPostID = nil }
    detailMode = .browse
    await reloadPosts()
  }

  /// Moves an unpublished draft and its media to the Trash.
  ///
  /// Only drafts with no copies anywhere can be trashed — a published Post is
  /// the local record of something that exists on a network.
  func trashPost(_ post: StoredPost) async {
    guard post.file.metadata.syndication.isEmpty else { return }
    try? await archiveFolder.withAccess { baseURL in
      try PostStore(baseDirectory: baseURL).trash(post)
    }
    if selectedPostID == post.id { selectedPostID = nil }
    detailMode = .browse
    await reloadPosts()
  }

  // MARK: - Attachments

  /// The on-disk URL of a stored attachment, for previews.
  func attachmentURL(_ attachment: Attachment, for post: StoredPost) -> URL {
    PostStore(baseDirectory: archiveFolder.url)
      .attachmentURL(named: attachment.fileName, for: post.fileURL)
  }

  /// Adds newly picked media to an existing post, writing the files beside it.
  func addAttachments(_ pending: [PendingAttachment], to post: StoredPost) async throws {
    var file = post.file
    try await archiveFolder.withAccess { baseURL in
      let store = PostStore(baseDirectory: baseURL)
      for attachment in pending {
        let fileName = try store.addAttachment(attachment, to: post.fileURL)
        file.metadata.media.append(Attachment(alt: attachment.alt, fileName: fileName))
      }
      try store.save(file, to: post.fileURL)
    }
    await reloadPosts()
  }

  /// Replaces a post's media list — used when alt text is edited or media removed.
  func updateAttachments(_ media: [Attachment], removing removed: [String], on post: StoredPost) async throws {
    var file = post.file
    file.metadata.media = media
    try await archiveFolder.withAccess { baseURL in
      let store = PostStore(baseDirectory: baseURL)
      for fileName in removed {
        try? store.deleteAttachment(named: fileName, for: post.fileURL)
      }
      try store.save(file, to: post.fileURL)
    }
    await reloadPosts()
  }

  // MARK: - Tools

  /// Backfills one account's published posts from its network into the archive,
  /// reporting progress as it fetches and merges.
  func importPosts(
    for account: Account,
    onProgress: @escaping @Sendable (String) -> Void = { _ in }
  ) async throws -> ImportReport {
    let report = try await archiveFolder.withAccess { baseURL in
      try await PostImporter(onProgress: onProgress, store: PostStore(baseDirectory: baseURL))
        .importPosts(for: account, credential: self.credential(for: account))
    }
    await reloadPosts()
    return report
  }

  func dupeGroups() async -> [DupeGroup] {
    let groups = try? await archiveFolder.withAccess { baseURL in
      try Deduper(store: PostStore(baseDirectory: baseURL)).candidateGroups()
    }
    return groups ?? []
  }

  func mergeDupes(_ group: DupeGroup) async {
    _ = try? await archiveFolder.withAccess { baseURL in
      try Deduper(store: PostStore(baseDirectory: baseURL)).merge(group)
    }
    await reloadPosts()
  }

  // MARK: - Target building

  private func targets(for accounts: [Account], reply: ReplyContext?) -> [Publisher.Target] {
    switch reply {
    case nil:
      return accounts.map { Publisher.Target(account: $0, credential: credential(for: $0)) }
    case .external(let url):
      // A reply to someone's post only makes sense on that post's own network.
      let network = inferredNetwork(of: url)
      return accounts.filter { $0.network == network }.map {
        Publisher.Target(account: $0, credential: credential(for: $0), replyParentURL: url)
      }
    case .thread(let parent):
      return accounts.compactMap { account in
        let copies = parent.file.metadata.syndication
        guard
          let copy = copies.first(where: { $0.network == account.network && $0.account == account.handle })
            ?? copies.first(where: { $0.network == account.network })
        else { return nil }
        return Publisher.Target(
          account: account,
          credential: credential(for: account),
          replyParentURL: copy.remoteURL
        )
      }
    }
  }

  /// Which network a pasted post URL belongs to.
  ///
  /// Mastodon is the fallback, since any fediverse host can serve a status.
  private func inferredNetwork(of url: URL) -> Network {
    let host = url.host() ?? ""
    if host.contains("bsky.app") { return .bluesky }
    if host.contains("threads.net") || host.contains("threads.com") { return .threads }
    return .mastodon
  }

  private func credential(for account: Account) -> Credential {
    keychain.credential(for: account.id) ?? .none
  }

  private func makePublisher(store: PostStore) -> Publisher {
    Publisher(
      adapters: [
        .bluesky: BlueskyAdapter(),
        .mastodon: MastodonAdapter(),
        .threads: ThreadsAdapter(),
      ],
      store: store
    )
  }
}
