import AuthenticationServices
import OutboxKit
import SwiftUI

/// Re-runs the Mastodon OAuth flow for an already-connected account, swapping in a fresh token.
///
/// Needed when Outbox starts asking for scopes the old token doesn't carry.
struct MastodonReconnectButton: View {
  @Environment(AppModel.self) private var model
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var errorMessage: String?
  @State private var isWorking = false
  var account: Account

  var body: some View {
    Group {
      if isWorking {
        ProgressView()
          .controlSize(.small)
      } else {
        Button("Reconnect") {
          Task { await reconnect() }
        }
        .help("Re-authorize this account to grant Outbox's current permissions")
      }
    }
    .alert("Couldn't reconnect", isPresented: .constant(errorMessage != nil)) {
      Button("OK") { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func reconnect() async {
    isWorking = true
    defer { isWorking = false }

    do {
      let oauth = MastodonOAuth()
      let pkce = PKCE()
      let registration = try await oauth.registerApp(on: account.serverURL)
      let authorizationURL = oauth.authorizationURL(
        on: account.serverURL,
        clientID: registration.clientID,
        pkce: pkce
      )
      let callback = try await webAuthenticationSession.authenticate(
        using: authorizationURL,
        callbackURLScheme: "outbox",
        preferredBrowserSession: .shared
      )
      let queryItems = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems
      guard let code = queryItems?.first(where: { $0.name == "code" })?.value else {
        errorMessage = "The instance didn't return an authorization code."
        return
      }

      let token = try await oauth.exchangeCode(
        code,
        on: account.serverURL,
        pkce: pkce,
        registration: registration
      )
      try model.updateCredential(.accessToken(token), for: account)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
