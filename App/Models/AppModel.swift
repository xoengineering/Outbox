import Foundation
import Observation
import OutboxKit

/// App-wide state: configured accounts, the loaded archive, selection, and the
/// wiring between the archive folder, Keychain, and Publisher.
@MainActor @Observable final class AppModel {
  /// What the sidebar has focused: optionally one account, optionally one status.
  ///
  /// Both nil means "All Posts".
  struct SidebarSelection: Hashable {
    var accountID: UUID?
    /// Distinguishes the account's own row from its "All Posts" child, so both
    /// are selectable — they filter identically.
    var isAccountRow = false
    var status: StoredPost.Status?
  }

  enum DetailMode: Equatable {
    case browse
    case compose(replyTo: URL?)
    case edit(StoredPost)
  }

  /// A one-shot focus request (⌘1/⌘2/⌘3); the target view consumes and clears it.
  enum FocusTarget {
    case accounts
    case form
    case posts
  }

  var accounts: [Account] = []
  var detailMode: DetailMode = .browse
  var focusRequest: FocusTarget?
  var enabledAccountIDs: Set<UUID> = []
  var posts: [StoredPost] = []
  var searchText = ""
  var selectedPostID: URL?
  /// Toolbar toggle filters on the posts list; empty means no status filtering.
  var statusFilters: Set<StoredPost.Status> = []
  var sidebarSelection: SidebarSelection? = SidebarSelection()
  let archiveFolder = ArchiveFolder()

  private let accountsRepository: AccountsRepository
  private let keychain = KeychainStore()

  init(accountsRepository: AccountsRepository = .inApplicationSupport()) {
    self.accountsRepository = accountsRepository
    accounts = accountsRepository.load()
    enabledAccountIDs = Set(accounts.map(\.id))
  }

  // MARK: - Accounts

  var enabledAccounts: [Account] {
    accounts.filter { enabledAccountIDs.contains($0.id) }
  }

  func add(_ account: Account, credential: Credential) throws {
    try keychain.save(credential, for: account.id)
    accounts.append(account)
    enabledAccountIDs.insert(account.id)
    try accountsRepository.save(accounts)
    Task { await refreshProfiles() }
  }

  /// Fills in display names and avatars from each network; failures are ignored.
  func refreshProfiles() async {
    let fetcher = ProfileFetcher()
    var changed = false
    for account in accounts where account.network != .threads {
      guard let credential = keychain.credential(for: account.id),
        let profile = try? await fetcher.profile(for: account, credential: credential),
        let index = accounts.firstIndex(where: { $0.id == account.id })
      else { continue }

      if accounts[index].avatarURL != profile.avatarURL || accounts[index].displayName != profile.displayName {
        accounts[index].avatarURL = profile.avatarURL
        accounts[index].displayName = profile.displayName
        changed = true
      }
    }
    if changed { try? accountsRepository.save(accounts) }
  }

  func remove(_ account: Account) {
    try? keychain.delete(for: account.id)
    accounts.removeAll { $0.id == account.id }
    enabledAccountIDs.remove(account.id)
    if sidebarSelection?.accountID == account.id { sidebarSelection = SidebarSelection() }
    try? accountsRepository.save(accounts)
  }

  func toggle(_ account: Account) {
    if enabledAccountIDs.contains(account.id) {
      enabledAccountIDs.remove(account.id)
    } else {
      enabledAccountIDs.insert(account.id)
    }
  }

  func account(for post: StoredPost) -> Account? {
    accounts.first {
      $0.handle == post.file.metadata.account && $0.network == post.file.metadata.network
    }
  }

  // MARK: - Archive

  func reloadPosts() async {
    let loaded = try? await archiveFolder.withAccess { baseURL in
      try PostStore(baseDirectory: baseURL).allPosts()
    }
    posts = loaded ?? []
  }

  var visiblePosts: [StoredPost] {
    var filtered = posts
    if let accountID = sidebarSelection?.accountID,
      let account = accounts.first(where: { $0.id == accountID })
    {
      filtered = filtered.filter {
        $0.file.metadata.account == account.handle && $0.file.metadata.network == account.network
      }
    }
    if let status = sidebarSelection?.status {
      filtered = filtered.filter { $0.status == status }
    }
    if !statusFilters.isEmpty {
      filtered = filtered.filter { statusFilters.contains($0.status) }
    }
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !query.isEmpty {
      filtered = filtered.filter { $0.file.body.localizedCaseInsensitiveContains(query) }
    }
    return filtered
  }

  var selectedPost: StoredPost? {
    posts.first { $0.id == selectedPostID }
  }

  var selectedAccountLabel: String {
    let scope: String
    if let accountID = sidebarSelection?.accountID,
      let account = accounts.first(where: { $0.id == accountID })
    {
      scope = account.handle
    } else {
      scope = "All Posts"
    }

    switch sidebarSelection?.status {
    case .draft: return "\(scope) — Drafts"
    case .published: return "\(scope) — Published"
    case nil: return scope
    }
  }

  // MARK: - Composing

  func startNewPost() {
    detailMode = .compose(replyTo: nil)
  }

  /// Starts a reply to a published post: targets that post's account and
  /// prefills the reply URL with its permalink.
  func startReply(to post: StoredPost) {
    if let account = account(for: post) {
      enabledAccountIDs = [account.id]
    }
    detailMode = .compose(replyTo: post.file.metadata.remoteURL)
  }

  // MARK: - Publishing

  func publish(body: String, replyTo replyURL: URL?) async -> [Publisher.TargetResult] {
    let targets = enabledTargets
    let results = await archiveFolder.withAccess { baseURL in
      await makePublisher(baseURL: baseURL).publish(body: body, replyTo: replyURL, to: targets)
    }
    await reloadPosts()
    return results
  }

  func saveDrafts(body: String, replyTo replyURL: URL?) async {
    let targets = enabledTargets
    _ = await archiveFolder.withAccess { baseURL in
      makePublisher(baseURL: baseURL).saveDrafts(body: body, replyTo: replyURL, for: targets)
    }
    await reloadPosts()
  }

  func publishExisting(_ post: StoredPost) async -> Publisher.TargetResult? {
    guard let account = account(for: post) else { return nil }
    let target = Publisher.Target(account: account, credential: keychain.credential(for: account.id) ?? .none)
    let result = await archiveFolder.withAccess { baseURL in
      await makePublisher(baseURL: baseURL).publishExisting(post, target: target)
    }
    await reloadPosts()
    return result
  }

  func updateBody(of post: StoredPost, to newBody: String) async throws {
    var file = post.file
    file.body = newBody
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

  private var enabledTargets: [Publisher.Target] {
    enabledAccounts.map { account in
      Publisher.Target(account: account, credential: keychain.credential(for: account.id) ?? .none)
    }
  }

  private func makePublisher(baseURL: URL) -> Publisher {
    Publisher(
      adapters: [
        .bluesky: BlueskyAdapter(),
        .mastodon: MastodonAdapter(),
        .threads: ThreadsAdapter(),
      ],
      store: PostStore(baseDirectory: baseURL)
    )
  }
}
