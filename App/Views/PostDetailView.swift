import OutboxKit
import SwiftUI

#if os(macOS)
  import AppKit
#endif

/// The "show" view for one Post: canonical content, its copies on networks,
/// pending targets, and extracted tokens.
struct PostDetailView: View {
  @AppStorage(DateFormatChoice.defaultsKey) private var dateFormat = DateFormatChoice.monthDayYear
  @AppStorage(PostContentSize.defaultsKey) private var contentSize = PostContentSize.medium
  @Environment(AppModel.self) private var model
  var post: StoredPost

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(AutoLink.attributed(post.file.body.trimmingCharacters(in: .whitespacesAndNewlines)))
          .font(contentSize.font)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 32)

        replyLinks

        VStack(alignment: .leading, spacing: 8) {
          metaLine
          copies
          filePath
        }

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

  /// The post's file on disk, clickable to reveal in Finder.
  @ViewBuilder
  private var filePath: some View {
    let relativePath = post.fileURL.path.replacingOccurrences(
      of: model.archiveFolder.url.path + "/", with: "")
    #if os(macOS)
      Button {
        NSWorkspace.shared.activateFileViewerSelecting([post.fileURL])
      } label: {
        Label {
          Text(relativePath)
            .font(.caption.monospaced())
        } icon: {
          Image(systemName: "doc.text")
        }
        .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Show in Finder")
    #else
      Label {
        Text(relativePath)
          .font(.caption.monospaced())
          .textSelection(.enabled)
      } icon: {
        Image(systemName: "doc.text")
      }
      .foregroundStyle(.secondary)
    #endif
  }

  private var metaLine: some View {
    HStack {
      Text("Created \(dateFormat.dayAndTimeString(from: post.file.metadata.createdAt))")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      if post.status == .draft {
        Text("Draft")
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(post.status.color.opacity(Palette.tintedCapsuleOpacity), in: Capsule())
          .foregroundStyle(post.status.color)
      }
    }
  }

  @ViewBuilder
  private var replyLinks: some View {
    if let snapshot = post.file.metadata.inReplyToSnapshot {
      SnapshotCardView(snapshot: snapshot)
    }
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
        Text(dateFormat.dayAndTimeString(from: copy.publishedAt))
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
      VStack(alignment: .leading, spacing: 10) {
        if !extracted.hashtags.isEmpty {
          tokenRow(title: "Hashtags", tokens: extracted.hashtags, color: Palette.hashtag) { tag in
            model.searchText = tag
          }
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

  private func tokenRow(
    title: String,
    tokens: [String],
    color: Color,
    action: ((String) -> Void)? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(tokens, id: \.self) { token in
            if let action {
              Button {
                action(token)
              } label: {
                tokenChip(token, color: color)
              }
              .buttonStyle(.plain)
              .help("Show posts containing \(token)")
            } else {
              tokenChip(token, color: color)
            }
          }
        }
      }
    }
  }

  private func tokenChip(_ token: String, color: Color) -> some View {
    Text(token)
      .font(.callout)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(Palette.tintedCapsuleOpacity), in: Capsule())
      .foregroundStyle(color)
  }
}
