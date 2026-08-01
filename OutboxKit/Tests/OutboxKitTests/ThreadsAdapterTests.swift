import Foundation
import Testing

@testable import OutboxKit

@Suite struct ThreadsAdapterTests {
  let account = Account(
    handle: "@veganstraightedge",
    network: .threads,
    serverURL: URL(string: "https://www.threads.net")!
  )

  let credential = Credential.threads(userID: "78910", accessToken: "TH-token")

  @Test func createsContainerThenPublishesIt() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "threads-container.json", statusCode: 200),
      .init(fixtureName: "threads-published.json", statusCode: 200),
      .init(fixtureName: "threads-permalink.json", statusCode: 200),
    ])
    let adapter = ThreadsAdapter(transport: transport)

    let outcome = try await adapter.publish(
      OutgoingPost(body: "Hello Threads"),
      account: account,
      credential: credential
    )

    guard case .published(let receipt) = outcome else {
      Issue.record("Expected .published, got \(outcome)")
      return
    }
    #expect(receipt.remoteID == "17924418472999999")
    #expect(
      receipt.remoteURL
        == URL(string: "https://www.threads.net/@veganstraightedge/post/C8xYzAbCdEf"))

    let container = transport.requests[0]
    #expect(container.httpMethod == "POST")
    #expect(container.url!.path == "/v1.0/78910/threads")
    let containerQuery = container.url!.query()!
    #expect(containerQuery.contains("media_type=TEXT"))
    #expect(containerQuery.contains("access_token=TH-token"))

    #expect(transport.requests[1].url!.path == "/v1.0/78910/threads_publish")
    #expect(transport.requests[1].url!.query()!.contains("creation_id=17924418472000001"))
  }

  @Test func sendsReplyToIDWhenReplying() async throws {
    let transport = FixtureTransport(stubs: [
      .init(fixtureName: "threads-container.json", statusCode: 200),
      .init(fixtureName: "threads-published.json", statusCode: 200),
      .init(fixtureName: "threads-permalink.json", statusCode: 200),
    ])
    let adapter = ThreadsAdapter(transport: transport)

    _ = try await adapter.publish(
      OutgoingPost(body: "Replying", replyTo: .threads(parentID: "17111111111")),
      account: account,
      credential: credential
    )

    #expect(transport.requests[0].url!.query()!.contains("reply_to_id=17111111111"))
  }

  @Test func skipsPostsWithAttachmentsUntilMediaCanBeHosted() async throws {
    let adapter = ThreadsAdapter(transport: FixtureTransport(stubs: []))

    let outcome = try await adapter.publish(
      OutgoingPost(
        attachments: [OutgoingAttachment(data: Data("jpeg".utf8), mimeType: "image/jpeg")],
        body: "With a photo"
      ),
      account: account,
      credential: credential
    )

    guard case .skipped(let reason) = outcome else {
      Issue.record("Expected .skipped, got \(outcome)")
      return
    }
    #expect(reason.contains("public URL"))
  }

  @Test func requiresAThreadsCredential() async {
    let adapter = ThreadsAdapter(transport: FixtureTransport(stubs: []))

    await #expect(throws: AdapterError.missingCredential) {
      try await adapter.publish(OutgoingPost(body: "hi"), account: account, credential: .none)
    }
  }

  @Test func cannotEditPublishedPosts() async {
    let adapter = ThreadsAdapter(transport: FixtureTransport(stubs: []))

    await #expect(throws: AdapterError.editingUnsupported) {
      try await adapter.edit(body: "new", remoteID: "1", account: account, credential: credential)
    }
  }
}
