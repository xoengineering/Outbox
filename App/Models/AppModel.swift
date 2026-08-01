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
    var onlyFavorites = false
    var status: StoredPost.Status?
  }

  /// What a new post replies to: someone else's post by URL, or one of our own.
  enum ReplyContext: Equatable {
    case external(URL)
    case thread(StoredPost)
  }

  enum DetailMode: Equatable {
    case browse
    case compose(reply: ReplyContext?)
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
  var enabledAccountIDs: Set<UUID> = []
  /// Which column currently owns keyboard focus, as reported by the views.
  var focusedColumn: FocusTarget?
  var focusRequest: FocusTarget?
  var posts: [StoredPost] = []
  var searchText = ""
  var selectedPostID: URL?
  var sidebarSelection: SidebarSelection? = SidebarSelection()
  /// Pill toggle filters on the posts list; empty/false means no filtering.
  var favoritesFilter = false
  var networkFilters: Set<Network> = []
  var statusFilters: Set<StoredPost.Status> = []
  let archiveFolder = ArchiveFolder()

  let keychain = KeychainStore()

  private let accountsRepository: AccountsRepository

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

  /// Replaces an account's stored credential in place — used when re-authorizing
  /// an existing connection (e.g. after Outbox asks for broader scopes).
  func updateCredential(_ credential: Credential, for account: Account) throws {
    try keychain.save(credential, for: account.id)
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

  func account(for endpoint: Endpoint) -> Account? {
    accounts.first { $0.handle == endpoint.account && $0.network == endpoint.network }
  }

  /// The avatar + network pairs shown on a post row, copies first.
  func endpointPairs(for post: StoredPost) -> [EndpointPair] {
    post.file.metadata.endpoints.map { endpoint in
      EndpointPair(
        id: "\(endpoint.network.rawValue)|\(endpoint.account)",
        avatarURL: account(for: endpoint)?.avatarURL,
        network: endpoint.network
      )
    }
  }

  // MARK: - Archive

  func reloadPosts() async {
    let loaded = try? await archiveFolder.withAccess { baseURL -> [StoredPost] in
      let store = PostStore(baseDirectory: baseURL)
      try? ArchiveMigrator(baseDirectory: baseURL, store: store).migrateIfNeeded()
      return try store.allPosts()
    }
    posts = loaded ?? []
  }

  var visiblePosts: [StoredPost] {
    var filtered = posts
    if let accountID = sidebarSelection?.accountID,
      let account = accounts.first(where: { $0.id == accountID })
    {
      let endpoint = Endpoint(account: account.handle, network: account.network)
      filtered = filtered.filter { $0.file.metadata.endpoints.contains(endpoint) }
    }
    if let status = sidebarSelection?.status {
      filtered = filtered.filter { $0.status == status }
    }
    if sidebarSelection?.onlyFavorites == true {
      filtered = filtered.filter(\.file.metadata.isFavorite)
    }
    if !statusFilters.isEmpty {
      filtered = filtered.filter { statusFilters.contains($0.status) }
    }
    if !networkFilters.isEmpty {
      filtered = filtered.filter { post in
        post.file.metadata.endpoints.contains { networkFilters.contains($0.network) }
      }
    }
    if favoritesFilter {
      filtered = filtered.filter(\.file.metadata.isFavorite)
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

    if sidebarSelection?.onlyFavorites == true { return "\(scope) — Favorites" }
    switch sidebarSelection?.status {
    case .draft: return "\(scope) — Drafts"
    case .published: return "\(scope) — Published"
    case nil: return scope
    }
  }

  func toggleFavorite(_ post: StoredPost) async {
    var file = post.file
    file.metadata.isFavorite.toggle()
    try? await archiveFolder.withAccess { baseURL in
      try PostStore(baseDirectory: baseURL).save(file, to: post.fileURL)
    }
    // Patch the loaded post instead of rescanning the archive — this runs on
    // a single keypress and should feel instant.
    if let index = posts.firstIndex(where: { $0.id == post.id }) {
      posts[index].file = file
    }
  }

  /// Moves keyboard focus one column left (-1) or right (+1).
  func moveFocus(_ delta: Int) {
    var columns: [FocusTarget] = [.accounts, .posts]
    if detailMode != .browse { columns.append(.form) }
    let current = focusedColumn ?? .accounts
    guard let index = columns.firstIndex(of: current) else {
      focusRequest = columns.first
      return
    }
    focusRequest = columns[min(max(index + delta, 0), columns.count - 1)]
  }

  /// Moves the posts-list selection down (+1) or up (-1) through visible posts.
  func moveSelection(_ delta: Int) {
    let visible = visiblePosts
    guard !visible.isEmpty else { return }
    guard let current = selectedPostID, let index = visible.firstIndex(where: { $0.id == current })
    else {
      selectedPostID = delta > 0 ? visible.first?.id : visible.last?.id
      return
    }
    selectedPostID = visible[min(max(index + delta, 0), visible.count - 1)].id
  }

  /// Clears every pill filter (the "All" pill).
  func clearFilters() {
    favoritesFilter = false
    networkFilters.removeAll()
    statusFilters.removeAll()
  }

  func toggleStatusFilter(_ status: StoredPost.Status) {
    if !statusFilters.insert(status).inserted {
      statusFilters.remove(status)
    }
  }

  // MARK: - Composing

  func startNewPost() {
    detailMode = .compose(reply: nil)
  }

  /// Starts a thread continuation of one of our own published posts: targets
  /// the accounts it was syndicated to, threading per network at publish time.
  func startReply(to post: StoredPost) {
    let syndicatedAccountIDs = post.file.metadata.syndication.compactMap { copy in
      account(for: copy.endpoint)?.id
    }
    if !syndicatedAccountIDs.isEmpty {
      enabledAccountIDs = Set(syndicatedAccountIDs)
    }
    detailMode = .compose(reply: .thread(post))
  }

}
