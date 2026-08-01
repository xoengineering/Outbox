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

  @Environment(AppModel.self) var model
  @State var attachments: [ComposerAttachment] = []
  @State var removedFileNames: [String] = []
  @State var errorMessage: String?
  @State var isWorking = false
  @State var publishRun: PublishRun?
  @State var selectedTargetIDs: Set<UUID>?
  @State var text: String
  @State private var isConfirmingDiscard = false
  @FocusState private var isContentFocused: Bool
  @FocusState private var isReplyFieldFocused: Bool
  @State private var replyURLText: String
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
        .padding(.horizontal)

      fields

      PostFormMediaField(attachments: $attachments, removedFileNames: $removedFileNames)
        .padding(.horizontal)

      if let errorMessage {
        Text(errorMessage)
          .foregroundStyle(Palette.danger)
          .textSelection(.enabled)
          .padding(.horizontal)
      }

      actionButtons
        .padding(.horizontal)

      if case .edit(let post) = mode {
        PostFormDangerZoneView(post: post)
          .padding(.horizontal)
      }
    }
    .padding(.vertical)
    .navigationTitle(isNew ? "New Post" : "Edit Post")
    .task {
      isContentFocused = true
      if case .edit(let post) = mode { attachments = loadStoredAttachments(from: post) }
      await refreshUpstreamPreview()
    }
    .tabHopsBetweenFields(
      contentFocus: $isContentFocused,
      isEnabled: hasReplyField,
      replyFocus: $isReplyFieldFocused
    )
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

  /// The reply context and writing fields: unbounded, with hairline rules
  /// running edge to edge across the column.
  @ViewBuilder
  private var fields: some View {
    VStack(alignment: .leading, spacing: 0) {
      if case .new(.thread(let parent)) = mode {
        ThreadParentPreviewView(parent: parent)
          .padding(.horizontal)
          .padding(.bottom, 12)
      } else if isNew || isEditableDraft {
        if let upstreamSnapshot {
          SnapshotCardView(snapshot: upstreamSnapshot)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        Divider()
        TextField("In reply to (paste a Mastodon or Bluesky post URL)", text: $replyURLText)
          .textFieldStyle(.plain)
          .font(.title3)
          .focused($isReplyFieldFocused)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
      }
      Divider()
      TextEditor(text: $text)
        .font(.title3)
        .focused($isContentFocused)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(minHeight: 200)
      Divider()
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
        if hasUnsavedContent {
          isConfirmingDiscard = true
        } else {
          model.detailMode = .browse
        }
      }
      .keyboardShortcut(.cancelAction)
      .confirmationDialog(
        isNew ? "Discard this post?" : "Discard unsaved changes?",
        isPresented: $isConfirmingDiscard,
        titleVisibility: .visible
      ) {
        Button("Discard", role: .destructive) {
          model.detailMode = .browse
        }
        Button("Keep Editing", role: .cancel) {}
      }

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

  func editTargetIDs(for post: StoredPost) -> Set<UUID> {
    if let selectedTargetIDs { return selectedTargetIDs }
    let targetIDs = post.file.metadata.targets.compactMap { model.account(for: $0)?.id }
    return Set(targetIDs)
  }

  // MARK: - State helpers

  private var isNew: Bool {
    if case .new = mode { return true }
    return false
  }

  /// True when cancelling would throw away something the user typed.
  private var hasUnsavedContent: Bool {
    switch mode {
    case .new:
      return !trimmedText.isEmpty || !replyURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .edit(let post):
      return trimmedText != post.file.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  /// The reply URL field exists for new posts and drafts, but not thread continuations.
  private var hasReplyField: Bool {
    if case .new(.thread) = mode { return false }
    return isNew || isEditableDraft
  }

  private var isEditableDraft: Bool {
    if case .edit(let post) = mode { return post.status == .draft }
    return false
  }

  var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var replyContext: AppModel.ReplyContext? {
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

}
