import Testing

@testable import OutboxKit

@Suite struct SlugTests {
  @Test func slugifiesSimpleText() {
    #expect(Slug.from("Happy bday to me") == "happy-bday-to-me")
  }

  @Test func dropsEmojiAndPunctuation() {
    #expect(Slug.from("Happy bday to me. 🎂") == "happy-bday-to-me")
  }

  @Test func takesOnlyLeadingWords() {
    let text = "One two three four five six seven eight nine ten"
    #expect(Slug.from(text) == "one-two-three-four-five-six")
  }

  @Test func usesFirstLineOnly() {
    #expect(Slug.from("First line here\n\nSecond paragraph ignored") == "first-line-here")
  }

  @Test func fallsBackWhenNothingSluggable() {
    #expect(Slug.from("🎂🎂🎂") == "post")
    #expect(Slug.from("") == "post")
  }

  @Test func keepsNumbers() {
    #expect(Slug.from("Ruby 3.4 is out") == "ruby-3-4-is-out")
  }
}
