import AuthenticationServices
import OutboxKit
import SwiftUI

/// Connects a Threads account.
///
/// Threads has no dynamic app registration, so you supply the client ID and
/// secret from an app you registered at developers.facebook.com.
struct ThreadsAccountFormView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var clientID = ""
  @State private var clientSecret = ""
  @State private var errorMessage: String?
  @State private var isWorking = false

  var body: some View {
    TextField("Threads app ID", text: $clientID)
      #if os(iOS)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      #endif
    SecureField("Threads app secret", text: $clientSecret)

    if let errorMessage {
      Text(errorMessage)
        .foregroundStyle(Palette.danger)
    }

    HStack {
      Text(
        "Register an app at developers.facebook.com with the Threads API and redirect URI "
          + "outbox://oauth/threads, then paste its credentials here. Photos and videos can't be "
          + "sent to Threads yet — its API only takes media from a public URL."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      Spacer()
      if isWorking {
        ProgressView()
          .controlSize(.small)
      }
      Button("Connect") {
        Task { await connect() }
      }
      .disabled(clientID.isEmpty || clientSecret.isEmpty || isWorking)
    }
  }

  private func connect() async {
    isWorking = true
    defer { isWorking = false }
    errorMessage = nil

    do {
      let oauth = ThreadsOAuth()
      let callback = try await webAuthenticationSession.authenticate(
        using: oauth.authorizationURL(clientID: clientID.trimmingCharacters(in: .whitespaces)),
        callbackURLScheme: "outbox",
        preferredBrowserSession: .shared
      )
      let queryItems = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems
      guard let code = queryItems?.first(where: { $0.name == "code" })?.value else {
        errorMessage = "Threads didn't return an authorization code."
        return
      }

      let credential = try await oauth.exchangeCode(
        code,
        clientID: clientID.trimmingCharacters(in: .whitespaces),
        clientSecret: clientSecret.trimmingCharacters(in: .whitespaces)
      )
      let username = try await oauth.profile(credential: credential)
      let account = Account(
        handle: "@\(username)",
        network: .threads,
        serverURL: URL(string: "https://www.threads.net")!
      )
      try model.add(account, credential: credential)
      clientID = ""
      clientSecret = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
