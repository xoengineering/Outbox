import Testing

@testable import OutboxKit

@Suite struct HTMLTextTests {
  @Test func stripsTagsAndDecodesEntities() {
    let html = "<p>Original post &amp; a second line.<br>With a break.</p>"
    #expect(HTMLText.plainText(fromHTML: html) == "Original post & a second line.\nWith a break.")
  }

  @Test func separatesParagraphs() {
    let html = "<p>First.</p><p>Second.</p>"
    #expect(HTMLText.plainText(fromHTML: html) == "First.\n\nSecond.")
  }

  @Test func decodesNumericEntities() {
    #expect(HTMLText.plainText(fromHTML: "It&#39;s fine &#128512;") == "It's fine 😀")
  }

  @Test func passesPlainTextThrough() {
    #expect(HTMLText.plainText(fromHTML: "no markup here") == "no markup here")
  }
}
