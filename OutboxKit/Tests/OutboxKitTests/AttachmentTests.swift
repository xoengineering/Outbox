import Foundation
import Testing

@testable import OutboxKit

@Suite struct AttachmentTests {
  let baseDirectory: URL
  let store: PostStore

  init() {
    baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AttachmentTests-\(UUID().uuidString)", isDirectory: true)
    store = PostStore(baseDirectory: baseDirectory, timeZone: TimeZone(identifier: "UTC")!)
  }

  @Test func roundTripsMediaFrontmatter() throws {
    let text = try #require(
      Bundle.module.url(forResource: "post-with-media.md", withExtension: nil, subdirectory: "Fixtures")
        .map { try String(contentsOf: $0, encoding: .utf8) })
    let file = try PostFile.parse(text)

    #expect(file.metadata.media.count == 2)
    #expect(file.metadata.media[0].fileName == "01-happy-bday-to-me-1.jpg")
    #expect(file.metadata.media[0].alt == "A chocolate birthday cake with candles")
    #expect(file.metadata.media[0].mimeType == "image/jpeg")
    #expect(file.metadata.media[1].alt == nil)
    #expect(file.metadata.media[1].mimeType == "image/png")
    #expect(try file.serialized() == text)
  }

  @Test func storesAttachmentsBesideThePostFile() throws {
    let postURL = try store.save(
      PostFile(body: "Look at this\n", metadata: PostMetadata(createdAt: Date.iso8601("2026-09-18T12:00:00Z")))
    )

    let first = try store.addAttachment(
      PendingAttachment(alt: "A cake", data: Data("fake-jpeg".utf8), fileExtension: "jpg"),
      to: postURL
    )
    let second = try store.addAttachment(
      PendingAttachment(data: Data("fake-png".utf8), fileExtension: "png"),
      to: postURL
    )

    #expect(first == "01-look-at-this-1.jpg")
    #expect(second == "01-look-at-this-2.png")
    #expect(FileManager.default.fileExists(atPath: store.attachmentURL(named: first, for: postURL).path))

    // Media files aren't posts.
    #expect(try store.allPosts().count == 1)
  }

  @Test func loadsOutgoingAttachmentsAndDeletesWithThePost() throws {
    var file = PostFile(
      body: "Look at this\n",
      metadata: PostMetadata(createdAt: Date.iso8601("2026-09-18T12:00:00Z"))
    )
    let postURL = try store.save(file)
    let fileName = try store.addAttachment(
      PendingAttachment(alt: "A cake", data: Data("fake-jpeg".utf8), fileExtension: "jpg"),
      to: postURL
    )
    file.metadata.media = [Attachment(alt: "A cake", fileName: fileName)]
    try store.save(file, to: postURL)

    let stored = StoredPost(file: file, fileURL: postURL)
    let outgoing = store.outgoingAttachments(for: stored)
    #expect(outgoing.count == 1)
    #expect(outgoing[0].alt == "A cake")
    #expect(outgoing[0].mimeType == "image/jpeg")
    #expect(outgoing[0].data == Data("fake-jpeg".utf8))

    try store.delete(stored)
    #expect(!FileManager.default.fileExists(atPath: store.attachmentURL(named: fileName, for: postURL).path))
  }

  @Test func publishingWritesAttachmentsAndSendsThemToAdapters() async throws {
    let adapter = RecordingAdapter()
    let publisher = Publisher(
      adapters: [.bluesky: adapter],
      now: { Date.iso8601("2026-09-18T12:00:00Z") },
      replyResolver: NoReplyResolver(),
      store: store
    )
    let target = Publisher.Target(
      account: Account(
        handle: "@veganstraightedge.com",
        network: .bluesky,
        serverURL: URL(string: "https://bsky.social")!
      ),
      credential: .appPassword(identifier: "veganstraightedge.com", password: "pw")
    )

    let output = await publisher.publish(
      attachments: [PendingAttachment(alt: "A cake", data: Data("fake-jpeg".utf8), fileExtension: "jpg")],
      body: "Look at this\n",
      to: [target]
    )

    let fileURL = try #require(output.fileURL)
    let saved = try PostFile.parse(String(contentsOf: fileURL, encoding: .utf8))
    #expect(saved.metadata.media.map(\.fileName) == ["01-look-at-this-1.jpg"])
    #expect(saved.metadata.media[0].alt == "A cake")
    #expect(adapter.receivedPosts.first?.attachments.first?.mimeType == "image/jpeg")
    #expect(adapter.receivedPosts.first?.attachments.first?.alt == "A cake")
  }
}

private final class RecordingAdapter: SocialServiceAdapter, @unchecked Sendable {
  let network = Network.bluesky
  private(set) var receivedPosts: [OutgoingPost] = []

  func publish(_ post: OutgoingPost, account: Account, credential: Credential) async throws -> PublishOutcome {
    receivedPosts.append(post)
    return .published(
      PublishReceipt(publishedAt: Date.iso8601("2026-09-18T12:00:01Z"), remoteID: "at://did/post/1"))
  }
}

private struct NoReplyResolver: ReplyResolving {
  func resolve(_ url: URL, account: Account, credential: Credential) async throws -> ResolvedReply? {
    nil
  }
}
