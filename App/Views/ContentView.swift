import OutboxKit
import SwiftUI

/// The composer: one text field, endpoint chips with live limits, one Publish button.
struct ContentView: View {
  @Environment(AppModel.self) private var model
  @State private var text = ""
  @State private var isPublishing = false
  @State private var publishRun: PublishRun?
  @State private var showsAccounts = false
  @State private var showsSettings = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        TextEditor(text: $text)
          .font(.title3)
          .scrollContentBackground(.hidden)
          .padding(8)
          .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
          .frame(minHeight: 160)

        endpointChips

        HStack {
          Spacer()
          publishButton
        }
      }
      .padding()
      .navigationTitle("Outbox")
      .toolbar {
        ToolbarItem {
          Button("Accounts", systemImage: "person.crop.circle") {
            showsAccounts = true
          }
        }
        ToolbarItem {
          Button("Settings", systemImage: "gearshape") {
            showsSettings = true
          }
        }
      }
    }
    .sheet(isPresented: $showsAccounts) {
      AccountsView()
    }
    .sheet(isPresented: $showsSettings) {
      SettingsView()
    }
    .sheet(item: $publishRun) { run in
      PublishResultsView(results: run.results)
    }
  }

  private var endpointChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        if model.accounts.isEmpty {
          Button("Add an account to publish to…") {
            showsAccounts = true
          }
          .buttonStyle(.bordered)
        }
        ForEach(model.accounts) { account in
          EndpointChipView(
            account: account,
            isEnabled: model.enabledAccountIDs.contains(account.id),
            remaining: remaining(for: account)
          ) {
            model.toggle(account)
          }
        }
      }
    }
  }

  private var publishButton: some View {
    Button {
      Task { await publish() }
    } label: {
      if isPublishing {
        ProgressView()
      } else {
        Text("Publish")
      }
    }
    .buttonStyle(.borderedProminent)
    .keyboardShortcut(.return, modifiers: .command)
    .disabled(!canPublish)
  }

  private var canPublish: Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isPublishing, !model.enabledAccounts.isEmpty else { return false }
    return model.enabledAccounts.allSatisfy { remaining(for: $0) >= 0 }
  }

  private func remaining(for account: Account) -> Int {
    account.characterLimit - CharacterCount.count(text, for: account.network)
  }

  private func publish() async {
    isPublishing = true
    defer { isPublishing = false }

    let body = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    let results = await model.publish(body: body)
    publishRun = PublishRun(results: results)

    let allSucceeded = results.allSatisfy {
      if case .success = $0.outcome { return true }
      return false
    }
    if allSucceeded { text = "" }
  }
}

struct PublishRun: Identifiable {
  let id = UUID()
  var results: [Publisher.TargetResult]
}
