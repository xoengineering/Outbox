import OutboxKit
import SwiftUI

/// The three-column shell: accounts sidebar, posts list, post detail.
struct ContentView: View {
  @Environment(AppModel.self) private var model
  @State private var showsAccounts = false
  @State private var showsSettings = false

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      AccountsSidebarView(showsAccounts: $showsAccounts, showsSettings: $showsSettings)
        .navigationSplitViewColumnWidth(min: 180, ideal: 230)
    } content: {
      PostsListView()
        .searchable(text: $model.searchText, prompt: "Search posts")
        .navigationSplitViewColumnWidth(min: 240, ideal: 320)
    } detail: {
      DetailColumnView()
    }
    .sheet(isPresented: $showsAccounts) {
      AccountsView()
    }
    .sheet(isPresented: $showsSettings) {
      SettingsView()
    }
    .task {
      await model.reloadPosts()
    }
    #if os(macOS)
      .navigationSubtitle(model.selectedAccountLabel)
    #endif
  }
}
