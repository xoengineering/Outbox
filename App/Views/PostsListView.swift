import OutboxKit
import SwiftUI

/// Second column: the archive, newest first, filtered by sidebar selection and search.
struct PostsListView: View {
  @AppStorage("LastFocusedColumn") private var lastFocusedColumn = "accounts"
  @Environment(AppModel.self) private var model
  @FocusState private var isFocused: Bool

  var body: some View {
    @Bindable var model = model
    ScrollViewReader { proxy in
      List(model.visiblePosts, selection: $model.selectedPostID) { post in
        PostRowView(
          isEmphasized: isFocused && model.selectedPostID == post.id,
          pairs: model.endpointPairs(for: post),
          post: post
        )
        .listRowSeparator(.hidden)
      }
      .focused($isFocused)
      // macOS routes ⌃D (the text system's deleteForward:) into the list, where it
      // strangely moves selection. Swallow it; text views keep their native ⌃D.
      .onKeyPress { press in
        if press.key == "d" && press.modifiers.contains(.control) { return .handled }
        if press.key == .tab {
          if press.modifiers.contains(.shift) {
            model.focusRequest = .accounts
          } else {
            model.focusRequest = model.detailMode != .browse ? .form : .accounts
          }
          return .handled
        }
        guard press.modifiers.isEmpty else { return .ignored }
        switch press.key {
        case "j":
          model.moveSelection(1)
          proxy.scrollTo(model.selectedPostID)
          return .handled
        case "k":
          model.moveSelection(-1)
          proxy.scrollTo(model.selectedPostID)
          return .handled
        case ".":
          if let post = model.selectedPost {
            Task { await model.toggleFavorite(post) }
            return .handled
          }
          return .ignored
        default:
          return .ignored
        }
      }
    }
    #if os(macOS)
      .focusSection()
    #endif
    .onChange(of: isFocused) {
      if isFocused {
        lastFocusedColumn = "posts"
        model.focusedColumn = .posts
      }
    }
    .onChange(of: model.focusRequest) {
      guard model.focusRequest == .posts else { return }
      isFocused = true
      model.focusRequest = nil
    }
    .task {
      if lastFocusedColumn == "posts" { isFocused = true }
    }
    .navigationTitle(model.selectedAccountLabel)
    .safeAreaInset(edge: .top, spacing: 0) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          allPill
          statusPill("Drafts", status: .draft)
          statusPill("Published", status: .published)
          favoritesPill
          Divider()
            .frame(height: 14)
          ForEach(Network.allCases) { network in
            networkPill(network)
          }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
      }
      .background(.bar)
    }
    .onChange(of: model.selectedPostID) {
      model.detailMode = .browse
    }
    .overlay {
      if model.visiblePosts.isEmpty {
        ContentUnavailableView(
          "No Posts",
          systemImage: "tray",
          description: Text("Press ⌘N to write your first post.")
        )
      }
    }
  }

  /// A star pill filtering to favorited posts.
  private var favoritesPill: some View {
    let isOn = model.favoritesFilter
    let tint = AnyShapeStyle(Palette.favorite)
    return Button {
      model.favoritesFilter.toggle()
    } label: {
      Image(systemName: isOn ? "star.fill" : "star")
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Palette.capsuleFill(tint, isOn: isOn), in: Capsule())
        .foregroundStyle(Palette.capsuleContent(tint, isOn: isOn))
    }
    .buttonStyle(.plain)
    .help("Show only favorites")
  }

  /// Clears every pill filter; highlighted when nothing is filtered.
  private var allPill: some View {
    let isOn = model.statusFilters.isEmpty && model.networkFilters.isEmpty && !model.favoritesFilter
    return Button {
      model.favoritesFilter = false
      model.statusFilters.removeAll()
      model.networkFilters.removeAll()
    } label: {
      Text("All")
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Palette.capsuleFill(AnyShapeStyle(.tint), isOn: isOn), in: Capsule())
        .foregroundStyle(Palette.capsuleContent(AnyShapeStyle(.tint), isOn: isOn))
    }
    .buttonStyle(.plain)
    .help("Clear all filters")
  }

  /// A filter pill styled like the Draft badge on post rows.
  private func statusPill(_ title: String, status: StoredPost.Status) -> some View {
    let isOn = model.statusFilters.contains(status)
    let tint = AnyShapeStyle(status.color)
    return Button {
      if isOn {
        model.statusFilters.remove(status)
      } else {
        model.statusFilters.insert(status)
      }
    } label: {
      Text(title)
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Palette.capsuleFill(tint, isOn: isOn), in: Capsule())
        .foregroundStyle(Palette.capsuleContent(tint, isOn: isOn))
    }
    .buttonStyle(.plain)
    .help(status == .draft ? "Show only drafts" : "Show only published posts")
  }

  /// A filter pill per network, in its brand color when active.
  private func networkPill(_ network: Network) -> some View {
    let isOn = model.networkFilters.contains(network)
    return Button {
      if isOn {
        model.networkFilters.remove(network)
      } else {
        model.networkFilters.insert(network)
      }
    } label: {
      HStack(spacing: 3) {
        NetworkIconView(
          network: network,
          size: 9,
          tint: isOn ? network.brandContrastColor : AnyShapeStyle(.secondary)
        )
        Text(network.displayName)
          .font(.caption2.weight(.semibold))
      }
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(isOn ? network.brandColor : Palette.inactiveFill, in: Capsule())
      .foregroundStyle(isOn ? network.brandContrastColor : AnyShapeStyle(.secondary))
    }
    .buttonStyle(.plain)
    .help("Show only \(network.displayName) posts")
  }
}
