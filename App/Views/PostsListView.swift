import OutboxKit
import SwiftUI

/// Second column: the archive, newest first, filtered by sidebar selection and search.
struct PostsListView: View {
  @AppStorage("LastFocusedColumn") private var lastFocusedColumn = "accounts"
  @Environment(AppModel.self) private var model
  @FocusState private var isFocused: Bool

  var body: some View {
    @Bindable var model = model
    List(model.visiblePosts, selection: $model.selectedPostID) { post in
      PostRowView(post: post)
    }
    .focused($isFocused)
    #if os(macOS)
      .focusSection()
    #endif
    .onChange(of: isFocused) {
      if isFocused { lastFocusedColumn = "posts" }
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
      HStack(spacing: 6) {
        statusPill("Drafts", status: .draft, color: .orange)
        statusPill("Published", status: .published, color: .green)
        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("New Post", systemImage: "square.and.pencil") {
          model.startNewPost()
        }
        .keyboardShortcut("n", modifiers: .command)
      }
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

  /// A filter pill styled like the Draft badge on post rows.
  private func statusPill(_ title: String, status: StoredPost.Status, color: Color) -> some View {
    let isOn = model.statusFilters.contains(status)
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
        .background(isOn ? AnyShapeStyle(color.opacity(0.2)) : AnyShapeStyle(.quaternary), in: Capsule())
        .foregroundStyle(isOn ? AnyShapeStyle(color) : AnyShapeStyle(.secondary))
    }
    .buttonStyle(.plain)
    .help(status == .draft ? "Show only drafts" : "Show only published posts")
  }
}
