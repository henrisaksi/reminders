import XCTest
import SQLite3
@testable import RemindCore

final class SectionResolverTests: XCTestCase {
  func testResolvesSectionNameFromPrimaryKey() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let libraryURL = tempRoot.appendingPathComponent("Library", isDirectory: true)
    let storesURL = libraryURL.appendingPathComponent("Reminders/Container/Stores", isDirectory: true)
    try FileManager.default.createDirectory(at: storesURL, withIntermediateDirectories: true)

    let dbURL = storesURL.appendingPathComponent("Data-1.sqlite")
    try createDatabase(at: dbURL, statements: [
      "CREATE TABLE ZREMCDSECTION (Z_PK INTEGER PRIMARY KEY, ZNAME TEXT, ZCKIDENTIFIER TEXT);",
      "CREATE TABLE ZREMCDREMINDER (Z_PK INTEGER PRIMARY KEY, ZDACALENDARITEMUNIQUEIDENTIFIER TEXT, ZSECTION INTEGER, ZLIST INTEGER);",
      "INSERT INTO ZREMCDSECTION (Z_PK, ZNAME, ZCKIDENTIFIER) VALUES (5, 'Work', 'section-ck');",
      "INSERT INTO ZREMCDREMINDER (Z_PK, ZDACALENDARITEMUNIQUEIDENTIFIER, ZSECTION, ZLIST) VALUES (10, 'rem-1', 5, NULL);",
      "INSERT INTO ZREMCDREMINDER (Z_PK, ZDACALENDARITEMUNIQUEIDENTIFIER, ZSECTION, ZLIST) VALUES (11, 'rem-2', NULL, NULL);",
    ])

    let resolver = SectionResolver(fileManager: TestFileManager(libraryURL: libraryURL))
    let results = resolver.resolveSectionNames(for: ["rem-1"])

    XCTAssertEqual(results, ["rem-1": "Work"])
  }

  func testResolvesSectionNameFromCloudKitIdentifier() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let libraryURL = tempRoot.appendingPathComponent("Library", isDirectory: true)
    let storesURL = libraryURL.appendingPathComponent("Reminders/Container/Stores", isDirectory: true)
    try FileManager.default.createDirectory(at: storesURL, withIntermediateDirectories: true)

    let dbURL = storesURL.appendingPathComponent("Data-2.sqlite")
    try createDatabase(at: dbURL, statements: [
      "CREATE TABLE ZREMCDSECTION (Z_PK INTEGER PRIMARY KEY, ZNAME TEXT, ZCKIDENTIFIER TEXT);",
      "CREATE TABLE ZREMCDREMINDER (Z_PK INTEGER PRIMARY KEY, ZDACALENDARITEMUNIQUEIDENTIFIER TEXT, ZSECTION TEXT);",
      "INSERT INTO ZREMCDSECTION (Z_PK, ZNAME, ZCKIDENTIFIER) VALUES (3, 'Home', 'section-home');",
      "INSERT INTO ZREMCDREMINDER (Z_PK, ZDACALENDARITEMUNIQUEIDENTIFIER, ZSECTION) VALUES (20, 'rem-3', 'section-home');",
    ])

    let resolver = SectionResolver(fileManager: TestFileManager(libraryURL: libraryURL))
    let results = resolver.resolveSectionNames(for: ["rem-3"])

    XCTAssertEqual(results, ["rem-3": "Home"])
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
