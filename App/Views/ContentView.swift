import OutboxKit
import SwiftUI

/// The three-column shell: accounts sidebar, posts list, post detail.
struct ContentView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      AccountsSidebarView()
        .navigationSplitViewColumnWidth(min: 180, ideal: 230)
    } content: {
      PostsListView()
        .searchable(text: $model.searchText, prompt: "Search posts")
        .navigationSplitViewColumnWidth(min: 240, ideal: 320)
    } detail: {
      DetailColumnView()
    }
    .task {
      await model.reloadPosts()
    }
    #if os(macOS)
      .navigationSubtitle(model.selectedAccountLabel)
    #endif
  }
}
