import OutboxKit
import SwiftUI

/// The post form, hosted in the third column: composing a new Post
/// (optionally as a reply or thread continuation) or editing an existing one.
struct PostFormView: View {
  enum Mode: Equatable {
    case edit(StoredPost)
    case new(reply: AppModel.ReplyContext?)
  }

  let mode: Mode

  @Environment(AppModel.self) private var model
  @FocusState private var isContentFocused: Bool
  @State private var confirmingDelete = false
  @State private var errorMessage: String?
  @State private var isWorking = false
  @State private var publishRun: PublishRun?
  @State private var replyURLText: String
  @State private var selectedTargetIDs: Set<UUID>?
  @State private var text: String
  @State private var upstreamSnapshot: ReplySnapshot?

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case .edit(let post):
      _text = State(initialValue: post.file.body.trimmingCharacters(in: .whitespacesAndNewlines))
      _replyURLText = State(initialValue: post.file.metadata.inReplyTo?.absoluteString ?? "")
    case .new(let reply):
      _text = State(initialValue: "")
      if case .external(let url) = reply {
        _replyURLText = State(initialValue: url.absoluteString)
      } else {
        _replyURLText = State(initialValue: "")
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      formHeader

      replyField

      TextEditor(text: $text)
        .font(.title3)
        .focused($isContentFocused)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(Palette.editorFill, in: RoundedRectangle(cornerRadius: 12))
        .frame(minHeight: 180)

      if let errorMessage {
        Text(errorMessage)
          .foregroundStyle(Palette.danger)
          .textSelection(.enabled)
      }

      actionButtons

      if case .edit(let post) = mode {
        dangerZone(for: post)
      }
    }
    .padding()
    .navigationTitle(isNew ? "New Post" : "Edit Post")
    .task {
      isContentFocused = true
      await refreshUpstreamPreview()
    }
    .task(id: replyURLText) {
      try? await Task.sleep(for: .milliseconds(600))
      guard !Task.isCancelled else { return }
      await refreshUpstreamPreview()
    }
    .onChange(of: model.focusRequest) {
      guard model.focusRequest == .form else { return }
      isContentFocused = true
      model.focusRequest = nil
    }
    .onChange(of: isContentFocused) {
      if isContentFocused { model.focusedColumn = .form }
    }
    .sheet(item: $publishRun, onDismiss: finishAfterPublish) { run in
      PublishResultsView(results: run.results)
    }
  }

  // MARK: - Sections

  @ViewBuilder
  private var formHeader: some View {
    if model.accounts.isEmpty {
      Text("Add an account in Settings to publish anywhere.")
        .foregroundStyle(.secondary)
    } else {
      FlowLayout(spacing: 8) {
        ForEach(selectableAccounts) { account in
          EndpointChipView(
            account: account,
            isEnabled: isTargeted(account),
            remaining: remaining(for: account)
          ) {
            toggleTarget(account)
          }
        }
      }
      if case .edit(let post) = mode, !post.file.metadata.syndication.isEmpty {
        Text("Already published to \(post.file.metadata.syndication.map(\.account).joined(separator: ", ")).")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var replyField: some View {
    if case .new(.thread(let parent)) = mode {
      Label {
        Text("Continuing thread: \(parent.file.body.trimmingCharacters(in: .whitespacesAndNewlines))")
          .lineLimit(1)
          .foregroundStyle(.secondary)
      } icon: {
        Image(systemName: "text.append")
      }
      .font(.callout)
    } else if isNew || isEditableDraft {
      TextField("In reply to (paste a Mastodon or Bluesky post URL)", text: $replyURLText)
        .textFieldStyle(.roundedBorder)
      if let upstreamSnapshot {
        SnapshotCardView(snapshot: upstreamSnapshot)
      }
    }
  }

  private func refreshUpstreamPreview() async {
    guard case .external(let url) = replyContext else {
      upstreamSnapshot = nil
      return
    }
    if case .edit(let post) = mode, let saved = post.file.metadata.inReplyToSnapshot {
      upstreamSnapshot = saved
      return
    }
    upstreamSnapshot = await model.fetchSnapshot(for: url)
  }

  @ViewBuilder
  private var actionButtons: some View {
    HStack {
      Button("Cancel") {
        model.detailMode = .browse
      }
      .keyboardShortcut(.cancelAction)

      Spacer()

      if isWorking {
        ProgressView()
          .controlSize(.small)
      }

      switch mode {
      case .edit(let post):
        Button("Save") {
          Task { await saveEdits(to: post) }
        }
        .disabled(trimmedText.isEmpty || isWorking)
        if post.file.metadata.isPublished {
          Button("Update Copies") {
            Task { await updateCopies(of: post) }
          }
          .buttonStyle(.borderedProminent)
          .disabled(trimmedText.isEmpty || isWorking)
          .help("Save, then push the edit to networks that allow it")
        }
        if post.status == .draft || post.hasPendingTargets {
          Button("Publish") {
            Task { await publishExisting(post) }
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.return, modifiers: .command)
          .disabled(trimmedText.isEmpty || isWorking)
        }
      case .new:
        Button("Save Draft") {
          Task { await saveDraft() }
        }
        .disabled(trimmedText.isEmpty || model.enabledAccounts.isEmpty || isWorking)
        Button("Publish") {
          Task { await publishNew() }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!canPublishNew)
      }
    }
  }

  private func dangerZone(for post: StoredPost) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Divider()
      HStack {
        Label("Danger Zone", systemImage: "exclamationmark.triangle")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Button("Delete Post…", role: .destructive) {
          confirmingDelete = true
        }
      }
    }
    .confirmationDialog(
      "Delete this post file?",
      isPresented: $confirmingDelete,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await model.deletePost(post) }
      }
    } message: {
      Text("This removes the local file only. Copies already on networks stay published.")
    }
  }

  // MARK: - Target selection

  /// New posts toggle the app-wide enabled set; edits toggle a local set
  /// seeded from the post's pending targets.
  private var selectableAccounts: [Account] {
    guard case .edit(let post) = mode else { return model.accounts }
    let syndicated = Set(post.file.metadata.syndication.map(\.endpoint))
    return model.accounts.filter {
      !syndicated.contains(Endpoint(account: $0.handle, network: $0.network))
    }
  }

  private func isTargeted(_ account: Account) -> Bool {
    switch mode {
    case .new:
      return model.enabledAccountIDs.contains(account.id)
    case .edit(let post):
      return editTargetIDs(for: post).contains(account.id)
    }
  }

  private func toggleTarget(_ account: Account) {
    switch mode {
    case .new:
      model.toggle(account)
    case .edit(let post):
      var selected = editTargetIDs(for: post)
      if !selected.insert(account.id).inserted {
        selected.remove(account.id)
      }
      selectedTargetIDs = selected
    }
  }

  private func editTargetIDs(for post: StoredPost) -> Set<UUID> {
    if let selectedTargetIDs { return selectedTargetIDs }
    let targetIDs = post.file.metadata.targets.compactMap { model.account(for: $0)?.id }
    return Set(targetIDs)
  }

  // MARK: - State helpers

  private var isNew: Bool {
    if case .new = mode { return true }
    return false
  }

  private var isEditableDraft: Bool {
    if case .edit(let post) = mode { return post.status == .draft }
    return false
  }

  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var replyContext: AppModel.ReplyContext? {
    if case .new(.thread(let parent)) = mode { return .thread(parent) }
    let trimmed = replyURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
    return .external(url)
  }

  private var canPublishNew: Bool {
    guard !trimmedText.isEmpty, !isWorking, !model.enabledAccounts.isEmpty else { return false }
    return model.enabledAccounts.allSatisfy { remaining(for: $0) >= 0 }
  }

  private func remaining(for account: Account) -> Int {
    account.characterLimit - CharacterCount.count(text, for: account.network)
  }

  // MARK: - Actions

  private func publishNew() async {
    isWorking = true
    defer { isWorking = false }
    let results = await model.publish(body: trimmedText + "\n", reply: replyContext)
    publishRun = PublishRun(results: results)
  }

  private func saveDraft() async {
    isWorking = true
    defer { isWorking = false }
    await model.saveDraft(body: trimmedText + "\n", reply: replyContext)
    model.detailMode = .browse
  }

  private func saveEdits(to post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.update(post, body: trimmedText + "\n", targetAccountIDs: editTargetIDs(for: post))
      model.detailMode = .browse
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func updateCopies(of post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.update(post, body: trimmedText + "\n", targetAccountIDs: editTargetIDs(for: post))
    } catch {
      errorMessage = error.localizedDescription
      return
    }
    guard let updated = model.posts.first(where: { $0.id == post.id }) else {
      errorMessage = "Couldn't reload the post after saving."
      return
    }
    let results = await model.editPublished(updated, body: trimmedText + "\n")
    publishRun = PublishRun(results: results)
  }

  private func publishExisting(_ post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.update(post, body: trimmedText + "\n", targetAccountIDs: editTargetIDs(for: post))
    } catch {
      errorMessage = error.localizedDescription
      return
    }
    guard let updated = model.posts.first(where: { $0.id == post.id }) else {
      errorMessage = "Couldn't reload the post after saving."
      return
    }
    let results = await model.publishExisting(updated)
    guard !results.isEmpty else {
      errorMessage = "No pending targets with a matching account — check Settings."
      return
    }
    publishRun = PublishRun(results: results)
  }

  private func finishAfterPublish() {
    model.detailMode = .browse
  }
}

struct PublishRun: Identifiable {
  let id = UUID()
  var results: [Publisher.TargetResult]
}
