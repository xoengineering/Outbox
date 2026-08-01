import OutboxKit
import SwiftUI

/// Tools inside Settings: import published posts from networks, and review
/// duplicate candidates Photos-style.
struct ToolsSettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var dupeGroups: [DupeGroup]?
  @State private var importReports: [UUID: String] = [:]
  @State private var importingAccountID: UUID?
  @State private var isImporting = false
  @State private var progressMessage = ""

  var body: some View {
    Form {
      Section {
        ForEach(model.accounts.filter { $0.network != .threads }) { account in
          HStack {
            Label {
              Text(account.handle)
            } icon: {
              NetworkIconView(network: account.network)
            }
            Spacer()
            if importingAccountID == account.id {
              Text(progressMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
              ProgressView()
                .controlSize(.small)
            } else if let report = importReports[account.id] {
              Text(report)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Button("Import") {
              Task { await runImport(for: [account]) }
            }
            .disabled(isImporting)
          }
        }
        Button("Import All") {
          Task { await runImport(for: model.accounts.filter { $0.network != .threads }) }
        }
        .disabled(isImporting || model.accounts.isEmpty)
      } header: {
        Text("Import")
      } footer: {
        Text(
          "Pulls your published posts from each network into the archive. Posts matching an "
            + "archived Post merge into it; anything uncertain is kept as its own file for the de-duper.")
      }

      Section {
        Button("Find Duplicates") {
          Task { dupeGroups = await model.dupeGroups() }
        }
        if let dupeGroups {
          if dupeGroups.isEmpty {
            Text("No duplicate candidates found.")
              .foregroundStyle(.secondary)
          }
          ForEach(dupeGroups) { group in
            dupeRow(group)
          }
        }
      } header: {
        Text("De-dupe")
      } footer: {
        Text("Nothing merges without your say-so. Merging unions the copies and deletes the extra files.")
      }
    }
    .formStyle(.grouped)
  }

  private func dupeRow(_ group: DupeGroup) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(group.posts[0].file.body.trimmingCharacters(in: .whitespacesAndNewlines))
        .lineLimit(2)
      ForEach(group.posts) { post in
        HStack(spacing: 6) {
          Text(post.fileURL.lastPathComponent)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
          ForEach(post.file.metadata.endpoints, id: \.self) { endpoint in
            NetworkIconView(network: endpoint.network, size: 10)
          }
        }
      }
      HStack {
        Spacer()
        Button("Keep All") {
          dupeGroups?.removeAll { $0.id == group.id }
        }
        Button("Merge") {
          Task {
            await model.mergeDupes(group)
            dupeGroups = await model.dupeGroups()
          }
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(.vertical, 4)
  }

  private func runImport(for accounts: [Account]) async {
    isImporting = true
    defer {
      isImporting = false
      importingAccountID = nil
    }

    for account in accounts {
      importingAccountID = account.id
      progressMessage = "Connecting…"
      do {
        let report = try await model.importPosts(for: account) { message in
          Task { @MainActor in progressMessage = message }
        }
        importReports[account.id] =
          "\(report.created) new, \(report.merged) merged, \(report.skipped) already tracked"
      } catch {
        importReports[account.id] = error.localizedDescription
      }
    }
  }
}
