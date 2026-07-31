import OutboxKit
import SwiftUI

/// Post-publish report: one row per endpoint with its receipt, skip reason, or error.
struct PublishResultsView: View {
  @Environment(\.dismiss) private var dismiss
  var results: [Publisher.TargetResult]

  var body: some View {
    NavigationStack {
      List {
        ForEach(results.indices, id: \.self) { index in
          row(for: results[index])
        }
      }
      .textSelection(.enabled)
      .navigationTitle("Published")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    #if os(macOS)
      .frame(minWidth: 480, minHeight: 280)
    #endif
  }

  @ViewBuilder
  private func row(for result: Publisher.TargetResult) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        icon(for: result)
        Text(result.account.handle)
          .font(.headline)
      }
      detail(for: result)
      if let fileURL = result.fileURL {
        Text(fileURL.path)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private func icon(for result: Publisher.TargetResult) -> some View {
    switch result.outcome {
    case .success(.published):
      Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
    case .success(.skipped):
      Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
    case .failure:
      Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.danger)
    }
  }

  @ViewBuilder
  private func detail(for result: Publisher.TargetResult) -> some View {
    switch result.outcome {
    case .success(.published(let receipt)):
      if let remoteURL = receipt.remoteURL {
        Link(remoteURL.absoluteString, destination: remoteURL)
          .font(.callout)
      }
    case .success(.skipped(let reason)):
      Text(reason)
        .font(.callout)
        .foregroundStyle(.secondary)
    case .failure(let error):
      Text(error.localizedDescription)
        .font(.callout)
        .foregroundStyle(Palette.danger)
    }
  }
}
