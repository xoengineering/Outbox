import OutboxKit
import SwiftUI

/// The "show" view for one Post: canonical content, its copies on networks,
/// pending targets, and extracted tokens.
struct PostDetailView: View {
  @Environment(AppModel.self) private var model
  var post: StoredPost

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header

        Text(post.file.body.trimmingCharacters(in: .whitespacesAndNewlines))
          .font(.title3)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)

        replyLinks

        copies

        extractedTokens
      }
      .padding()
    }
    .navigationTitle("")
    .toolbar {
      ToolbarItem {
        Button(
          post.file.metadata.isFavorite ? "Unfavorite" : "Favorite",
          systemImage: post.file.metadata.isFavorite ? "star.fill" : "star"
        ) {
          Task { await model.toggleFavorite(post) }
        }
        .help(post.file.metadata.isFavorite ? "Remove from favorites" : "Add to favorites")
      }
      ToolbarItem {
        Button("Reply", systemImage: "arrowshape.turn.up.left") {
          model.startReply(to: post)
        }
        .disabled(!post.file.metadata.isPublished)
        .help("Continue this thread")
      }
      ToolbarItem {
        Button("Edit", systemImage: "pencil") {
          model.detailMode = .edit(post)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Written \(post.file.metadata.createdAt, format: .dateTime)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        statusBadge
      }
      Divider()
    }
  }

  private var statusBadge: some View {
    Text(post.status == .published ? "Published" : "Draft")
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(post.status.color.opacity(Palette.tintedCapsuleOpacity), in: Capsule())
      .foregroundStyle(post.status.color)
  }

  @ViewBuilder
  private var replyLinks: some View {
    if let inReplyTo = post.file.metadata.inReplyTo {
      Label {
        Link(destination: inReplyTo) {
          Text("In reply to \(inReplyTo.absoluteString)")
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } icon: {
        Image(systemName: "arrowshape.turn.up.left")
      }
      .font(.callout)
    }
    if let parentPath = post.file.metadata.inReplyToPost {
      Label {
        Text("Continues thread from \(parentPath)")
          .foregroundStyle(.secondary)
      } icon: {
        Image(systemName: "text.append")
      }
      .font(.callout)
    }
  }

  @ViewBuilder
  private var copies: some View {
    let syndication = post.file.metadata.syndication
    let pending = post.file.metadata.targets
    if !syndication.isEmpty || !pending.isEmpty {
      Divider()
      VStack(alignment: .leading, spacing: 8) {
        Text("Copies")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        ForEach(syndication, id: \.remoteID) { copy in
          copyRow(copy)
        }
        ForEach(pending, id: \.self) { endpoint in
          HStack(spacing: 6) {
            NetworkIconView(network: endpoint.network, size: 12)
            Text(endpoint.account)
            Text("pending")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .font(.callout)
        }
      }
    }
  }

  @ViewBuilder
  private func copyRow(_ copy: Syndication) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 6) {
        NetworkIconView(network: copy.network, size: 12)
        Text(copy.account)
        Spacer()
        Text(copy.publishedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .font(.callout)
      if let remoteURL = copy.remoteURL {
        Link(destination: remoteURL) {
          Text(remoteURL.absoluteString)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .padding(.leading, 18)
      }
      if let text = copy.text {
        DisclosureGroup {
          Text(text)
            .font(.callout)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Text("Sent text differed")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.leading, 18)
      }
    }
  }

  @ViewBuilder
  private var extractedTokens: some View {
    let extracted = ContentExtractor.extract(from: post.file.body)
    if extracted != ContentExtractor.Extracted() {
      Divider()
      VStack(alignment: .leading, spacing: 10) {
        if !extracted.hashtags.isEmpty {
          tokenRow(title: "Hashtags", tokens: extracted.hashtags, color: Palette.hashtag)
        }
        if !extracted.mentions.isEmpty {
          tokenRow(title: "Mentions", tokens: extracted.mentions, color: Palette.mention)
        }
        if !extracted.urls.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text("Links")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(extracted.urls, id: \.absoluteString) { url in
              Link(url.absoluteString, destination: url)
                .font(.callout)
                .lineLimit(1)
            }
          }
        }
      }
    }
  }

  private func tokenRow(title: String, tokens: [String], color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(tokens, id: \.self) { token in
            Text(token)
              .font(.callout)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(color.opacity(Palette.tintedCapsuleOpacity), in: Capsule())
              .foregroundStyle(color)
          }
        }
      }
    }
  }
}
