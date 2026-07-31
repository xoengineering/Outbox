import OutboxKit
import SwiftUI

/// The post form, hosted in the third column: composing a new post
/// (optionally as a reply) or editing an existing one.
struct PostFormView: View {
  enum Mode: Equatable {
    case edit(StoredPost)
    case new(replyTo: URL?)
  }

  let mode: Mode

  @Environment(AppModel.self) private var model
  @FocusState private var isContentFocused: Bool
  @State private var confirmingDelete = false
  @State private var errorMessage: String?
  @State private var isWorking = false
  @State private var publishRun: PublishRun?
  @State private var replyURLText: String
  @State private var text: String

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case .edit(let post):
      _text = State(initialValue: post.file.body.trimmingCharacters(in: .whitespacesAndNewlines))
      _replyURLText = State(initialValue: post.file.metadata.inReplyTo?.absoluteString ?? "")
    case .new(let replyTo):
      _text = State(initialValue: "")
      _replyURLText = State(initialValue: replyTo?.absoluteString ?? "")
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      formHeader

      TextField("In reply to (paste a Mastodon or Bluesky post URL)", text: $replyURLText)
        .textFieldStyle(.roundedBorder)
        .disabled(isEditingPublished)

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
    }
    .onChange(of: model.focusRequest) {
      guard model.focusRequest == .form else { return }
      isContentFocused = true
      model.focusRequest = nil
    }
    .sheet(item: $publishRun, onDismiss: finishAfterPublish) { run in
      PublishResultsView(results: run.results)
    }
  }

  // MARK: - Sections

  @ViewBuilder
  private var formHeader: some View {
    switch mode {
    case .edit(let post):
      Label {
        Text(post.file.metadata.account)
      } icon: {
        NetworkIconView(network: post.file.metadata.network, size: 16)
      }
      .font(.headline)
    case .new:
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          if model.accounts.isEmpty {
            Text("Add an account in Settings to publish anywhere.")
              .foregroundStyle(.secondary)
          }
          ForEach(model.accounts) { account in
            EndpointChipView(
              account: account,
              isEnabled: model.enabledAccountIDs.contains(account.id),
              remaining: remaining(for: account)
            ) {
              model.toggle(account)
            }
          }
        }
      }
    }
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
        if post.status == .draft {
          Button("Publish") {
            Task { await publishDraft(post) }
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
      Text("This removes the local file only. Anything already published stays published.")
    }
  }

  // MARK: - State helpers

  private var isNew: Bool {
    if case .new = mode { return true }
    return false
  }

  private var isEditingPublished: Bool {
    if case .edit(let post) = mode { return post.status == .published }
    return false
  }

  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var replyURL: URL? {
    let trimmed = replyURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return URL(string: trimmed)
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
    let results = await model.publish(body: trimmedText + "\n", replyTo: replyURL)
    publishRun = PublishRun(results: results)
  }

  private func saveDraft() async {
    isWorking = true
    defer { isWorking = false }
    await model.saveDrafts(body: trimmedText + "\n", replyTo: replyURL)
    model.detailMode = .browse
  }

  private func saveEdits(to post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.updateBody(of: post, to: trimmedText + "\n")
      model.detailMode = .browse
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func publishDraft(_ post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.updateBody(of: post, to: trimmedText + "\n")
    } catch {
      errorMessage = error.localizedDescription
      return
    }
    guard let updated = model.posts.first(where: { $0.id == post.id }),
      let result = await model.publishExisting(updated)
    else {
      errorMessage = "No matching account for this post — add it in the sidebar first."
      return
    }
    publishRun = PublishRun(results: [result])
  }

  private func finishAfterPublish() {
    model.detailMode = .browse
  }
}

struct PublishRun: Identifiable {
  let id = UUID()
  var results: [Publisher.TargetResult]
}
