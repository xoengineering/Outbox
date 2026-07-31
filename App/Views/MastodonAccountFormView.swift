import AuthenticationServices
import OutboxKit
import SwiftUI

/// Inline Mastodon connect form: instance domain → OAuth in a web sheet → token in Keychain.
struct MastodonAccountFormView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var domain = ""
  @State private var errorMessage: String?
  @State private var isWorking = false

  var body: some View {
    TextField("Instance domain", text: $domain, prompt: Text("ruby.social"))
      .textContentType(.URL)
      #if os(iOS)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      #endif

    if let errorMessage {
      Text(errorMessage)
        .foregroundStyle(Palette.danger)
    }

    HStack {
      Text("You'll sign in on your instance's own website. Outbox never sees your password.")
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
      .disabled(domain.isEmpty || isWorking)
    }
  }

  private func connect() async {
    isWorking = true
    defer { isWorking = false }
    errorMessage = nil

    let cleanedDomain =
      domain
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "https://", with: "")
    guard let serverURL = URL(string: "https://\(cleanedDomain)") else {
      errorMessage = "That doesn't look like a domain."
      return
    }

    do {
      let oauth = MastodonOAuth()
      let pkce = PKCE()
      let registration = try await oauth.registerApp(on: serverURL)
      let authorizationURL = oauth.authorizationURL(
        on: serverURL,
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

      let token = try await oauth.exchangeCode(code, on: serverURL, pkce: pkce, registration: registration)
      let verified = try await oauth.verifyCredentials(on: serverURL, token: token)
      let maximumCharacters = await MastodonInstance().maximumCharacters(on: serverURL)
      let account = Account(
        handle: "@\(verified.username)@\(cleanedDomain)",
        maximumCharacters: maximumCharacters,
        network: .mastodon,
        serverURL: serverURL
      )
      try model.add(account, credential: .accessToken(token))
      domain = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
