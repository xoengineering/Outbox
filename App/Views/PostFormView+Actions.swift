import OutboxKit
import SwiftUI

/// Publish, draft, and edit actions for the post form.
extension PostFormView {
  func publishNew() async {
    isWorking = true
    defer { isWorking = false }
    let results = await model.publish(
      attachments: attachments.compactMap(\.pendingAttachment),
      body: trimmedText + "\n",
      reply: replyContext
    )
    publishRun = PublishRun(results: results)
  }

  func saveDraft() async {
    isWorking = true
    defer { isWorking = false }
    await model.saveDraft(
      attachments: attachments.compactMap(\.pendingAttachment),
      body: trimmedText + "\n",
      reply: replyContext
    )
    model.detailMode = .browse
  }

  func saveEdits(to post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.update(post, body: trimmedText + "\n", targetAccountIDs: editTargetIDs(for: post))
      try await saveAttachmentChanges(to: post)
      model.detailMode = .browse
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func updateCopies(of post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.update(post, body: trimmedText + "\n", targetAccountIDs: editTargetIDs(for: post))
      try await saveAttachmentChanges(to: post)
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

  func publishExisting(_ post: StoredPost) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await model.update(post, body: trimmedText + "\n", targetAccountIDs: editTargetIDs(for: post))
      try await saveAttachmentChanges(to: post)
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

  func finishAfterPublish() {
    model.detailMode = .browse
  }
}

struct PublishRun: Identifiable {
  let id = UUID()
  var results: [Publisher.TargetResult]
}
