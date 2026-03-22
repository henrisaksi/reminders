import Foundation
import Testing
@testable import reminders

@Suite
struct TagsTests {
  @Test("Parse tags correctly")
  func testParseTags() throws {
    let parsed = try CommandHelpers.parseTags(["shopping", "#urgent", "home,work"])
    #expect(parsed == ["shopping", "urgent", "home", "work"])
  }

  @Test("Parse tags ignores empty")
  func testParseEmptyTags() throws {
    #expect(throws: Error.self) {
      try CommandHelpers.parseTags(["#"])
    }
  }

  @Test("Parse tags removes duplicates case-insensitively")
  func testParseTagsDeduplicate() throws {
    let parsed = try CommandHelpers.parseTags(["shopping", "Shopping", "WORK"])
    #expect(parsed == ["shopping", "WORK"])
  }

  @Test("Extract tags from title")
  func testExtractTags() {
    let parsed = CommandHelpers.parseTitleTags("Buy milk #shopping #urgent")
    #expect(parsed.baseTitle == "Buy milk")
    #expect(parsed.tags == ["shopping", "urgent"])
  }

  @Test("Extract tags handles only tags")
  func testExtractOnlyTags() {
    let parsed = CommandHelpers.parseTitleTags("#shopping #urgent")
    #expect(parsed.baseTitle.isEmpty)
    #expect(parsed.tags == ["shopping", "urgent"])
  }

  @Test("Extract tags ignores non-trailing tags")
  func testExtractNonTrailingTags() {
    let parsed = CommandHelpers.parseTitleTags("Buy #milk today #urgent")
    #expect(parsed.baseTitle == "Buy #milk today")
    #expect(parsed.tags == ["urgent"])
  }

  @Test("Compose title")
  func testComposeTitle() {
    let composed = CommandHelpers.composeTitle(baseTitle: "Buy milk", tags: ["shopping", "urgent"])
    #expect(composed == "Buy milk #shopping #urgent")
  }
}
