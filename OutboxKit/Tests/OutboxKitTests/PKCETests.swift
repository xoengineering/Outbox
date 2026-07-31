import Testing

@testable import OutboxKit

@Suite struct PKCETests {
  @Test func computesRFC7636KnownAnswerChallenge() {
    let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  @Test func generatesURLSafeRandomVerifiers() {
    let first = PKCE()
    let second = PKCE()

    #expect(first.verifier != second.verifier)
    let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    #expect(first.verifier.allSatisfy { allowed.contains($0) })
    #expect(first.verifier.count >= 43)
  }
}
