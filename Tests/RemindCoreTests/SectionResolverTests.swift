import XCTest
import SQLite3
@testable import RemindCore

final class SectionResolverTests: XCTestCase {
  func testResolvesSectionNameFromMembershipData() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let libraryURL = tempRoot.appendingPathComponent("Library", isDirectory: true)
    let storesURL = libraryURL.appendingPathComponent("Reminders/Container/Stores", isDirectory: true)
    try FileManager.default.createDirectory(at: storesURL, withIntermediateDirectories: true)

    let dbURL = storesURL.appendingPathComponent("Data-1.sqlite")
    let membershipsJSON = """
    {"minimumSupportedVersion":20230430,"memberships":[{"memberID":"rem-1","groupID":"section-ck"}]}
    """

    try createDatabase(at: dbURL, statements: [
      "CREATE TABLE ZREMCDBASELIST (Z_PK INTEGER PRIMARY KEY, ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA TEXT);",
      "CREATE TABLE ZREMCDBASESECTION (Z_PK INTEGER PRIMARY KEY, ZCKIDENTIFIER TEXT, ZDISPLAYNAME TEXT, ZLIST INTEGER);",
      "CREATE TABLE ZREMCDREMINDER (Z_PK INTEGER PRIMARY KEY, ZDACALENDARITEMUNIQUEIDENTIFIER TEXT, ZLIST INTEGER);",
      "INSERT INTO ZREMCDBASELIST (Z_PK, ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA) VALUES (1, '\(membershipsJSON)');",
      "INSERT INTO ZREMCDBASESECTION (Z_PK, ZCKIDENTIFIER, ZDISPLAYNAME, ZLIST) VALUES (5, 'section-ck', 'Work', 1);",
      "INSERT INTO ZREMCDREMINDER (Z_PK, ZDACALENDARITEMUNIQUEIDENTIFIER, ZLIST) VALUES (10, 'rem-1', 1);",
      "INSERT INTO ZREMCDREMINDER (Z_PK, ZDACALENDARITEMUNIQUEIDENTIFIER, ZLIST) VALUES (11, 'rem-2', 1);",
    ])

    let resolver = SectionResolver(fileManager: TestFileManager(libraryURL: libraryURL))
    let results = resolver.resolveSectionNames(for: ["rem-1"])

    XCTAssertEqual(results, ["rem-1": "Work"])
  }

  func testResolvesSectionNameWhenMatchingNonMemberIdentifier() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let libraryURL = tempRoot.appendingPathComponent("Library", isDirectory: true)
    let storesURL = libraryURL.appendingPathComponent("Reminders/Container/Stores", isDirectory: true)
    try FileManager.default.createDirectory(at: storesURL, withIntermediateDirectories: true)

    let dbURL = storesURL.appendingPathComponent("Data-2.sqlite")
    let membershipsJSON = """
    {"minimumSupportedVersion":20230430,"memberships":[{"memberID":"rem-4","groupID":"section-home"}]}
    """

    try createDatabase(at: dbURL, statements: [
      "CREATE TABLE ZREMCDBASELIST (Z_PK INTEGER PRIMARY KEY, ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA TEXT);",
      "CREATE TABLE ZREMCDBASESECTION (Z_PK INTEGER PRIMARY KEY, ZCKIDENTIFIER TEXT, ZDISPLAYNAME TEXT, ZLIST INTEGER);",
      "CREATE TABLE ZREMCDREMINDER (Z_PK INTEGER PRIMARY KEY, ZDACALENDARITEMUNIQUEIDENTIFIER TEXT, ZCKIDENTIFIER TEXT, ZLIST INTEGER);",
      "INSERT INTO ZREMCDBASELIST (Z_PK, ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA) VALUES (2, '\(membershipsJSON)');",
      "INSERT INTO ZREMCDBASESECTION (Z_PK, ZCKIDENTIFIER, ZDISPLAYNAME, ZLIST) VALUES (7, 'section-home', 'Home', 2);",
      "INSERT INTO ZREMCDREMINDER (Z_PK, ZDACALENDARITEMUNIQUEIDENTIFIER, ZCKIDENTIFIER, ZLIST) VALUES (20, 'rem-4', 'ck-rem-4', 2);",
    ])

    let resolver = SectionResolver(fileManager: TestFileManager(libraryURL: libraryURL))
    let results = resolver.resolveSectionNames(for: ["ck-rem-4"])

    XCTAssertEqual(results, ["ck-rem-4": "Home"])
  }
}

private final class TestFileManager: FileManager {
  private let libraryURL: URL

  init(libraryURL: URL) {
    self.libraryURL = libraryURL
    super.init()
  }

  override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
    if directory == .libraryDirectory {
      return [libraryURL]
    }
    return super.urls(for: directory, in: domainMask)
  }
}

private func createDatabase(at url: URL, statements: [String]) throws {
  var db: OpaquePointer?
  if sqlite3_open(url.path, &db) != SQLITE_OK {
    defer { sqlite3_close(db) }
    throw DatabaseError.openFailed
  }
  defer { sqlite3_close(db) }

  for statement in statements {
    if sqlite3_exec(db, statement, nil, nil, nil) != SQLITE_OK {
      let message = String(cString: sqlite3_errmsg(db))
      throw DatabaseError.execFailed(message)
    }
  }
}

private enum DatabaseError: Error {
  case openFailed
  case execFailed(String)
}
