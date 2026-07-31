import OutboxKit
import SwiftUI

/// The "show" view for one post: content, status, permalinks, and extracted tokens.
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

        links

        extractedTokens
      }
      .padding()
    }
    .navigationTitle("")
    .toolbar {
      ToolbarItem {
        Button("Reply", systemImage: "arrowshape.turn.up.left") {
          model.startReply(to: post)
        }
        .disabled(post.file.metadata.remoteURL == nil)
        .help("Write a reply to this post")
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
        Label {
          Text(post.file.metadata.account)
        } icon: {
          NetworkIconView(network: post.file.metadata.network, size: 16)
        }
        .font(.headline)
        Spacer()
        statusBadge
      }
      HStack(spacing: 12) {
        Text("Written \(post.file.metadata.createdAt, format: .dateTime)")
        if let publishedAt = post.file.metadata.publishedAt {
          Text("Published \(publishedAt, format: .dateTime)")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      Divider()
    }
  }

  private var statusBadge: some View {
    Text(post.status == .published ? "Published" : "Draft")
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(badgeColor.opacity(0.15), in: Capsule())
      .foregroundStyle(badgeColor)
  }

  private var badgeColor: Color {
    post.status == .published ? .green : .orange
  }

  @ViewBuilder
  private var links: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let remoteURL = post.file.metadata.remoteURL {
        Label {
          Link(remoteURL.absoluteString, destination: remoteURL)
            .multilineTextAlignment(.leading)
        } icon: {
          Image(systemName: "link")
        }
      }
      if let inReplyTo = post.file.metadata.inReplyTo {
        Label {
          Link("In reply to \(inReplyTo.absoluteString)", destination: inReplyTo)
            .multilineTextAlignment(.leading)
        } icon: {
          Image(systemName: "arrowshape.turn.up.left")
        }
      }
    }
    .font(.callout)
  }

  @ViewBuilder
  private var extractedTokens: some View {
    let extracted = ContentExtractor.extract(from: post.file.body)
    if extracted != ContentExtractor.Extracted() {
      Divider()
      VStack(alignment: .leading, spacing: 10) {
        if !extracted.hashtags.isEmpty {
          tokenRow(title: "Hashtags", tokens: extracted.hashtags, color: .blue)
        }
        if !extracted.mentions.isEmpty {
          tokenRow(title: "Mentions", tokens: extracted.mentions, color: .purple)
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
              .background(color.opacity(0.12), in: Capsule())
              .foregroundStyle(color)
          }
        }
      }
    }
  }
}
