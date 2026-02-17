import Foundation
import SQLite3

struct SectionResolver {
  private let fileManager: FileManager
  private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func resolveSectionNames(for reminderIDs: [String]) -> [String: String] {
    guard !reminderIDs.isEmpty else { return [:] }
    guard let databaseURL = findDatabase() else { return [:] }
    guard let db = openDatabase(at: databaseURL) else { return [:] }
    defer { sqlite3_close(db) }
    return loadSectionNames(from: db, reminderIDs: reminderIDs)
  }

  private func findDatabase() -> URL? {
    guard let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
      return nil
    }

    let candidateRoots: [URL] = [
      libraryURL.appendingPathComponent("Reminders/Container_v1/Stores", isDirectory: true),
      libraryURL.appendingPathComponent("Reminders/Container/Stores", isDirectory: true),
      libraryURL.appendingPathComponent("Reminders/Stores", isDirectory: true),
      libraryURL.appendingPathComponent("Group Containers/group.com.apple.reminders/Container_v1/Stores", isDirectory: true),
      libraryURL.appendingPathComponent("Group Containers/group.com.apple.reminders/Container/Stores", isDirectory: true),
      libraryURL.appendingPathComponent("Group Containers/group.com.apple.reminders/Stores", isDirectory: true),
    ]

    var latestURL: URL?
    var latestDate: Date?

    for root in candidateRoots where fileManager.fileExists(atPath: root.path) {
      guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      ) else { continue }

      for case let fileURL as URL in enumerator {
        guard fileURL.lastPathComponent.hasPrefix("Data-"), fileURL.pathExtension == "sqlite" else { continue }
        guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
              values.isRegularFile == true
        else { continue }
        let modified = values.contentModificationDate ?? .distantPast
        if let latestDate, modified <= latestDate { continue }
        latestDate = modified
        latestURL = fileURL
      }
    }

    return latestURL
  }

  private func openDatabase(at url: URL) -> OpaquePointer? {
    var db: OpaquePointer?
    let flags = SQLITE_OPEN_READONLY
    if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
      if db != nil { sqlite3_close(db) }
      return nil
    }
    sqlite3_busy_timeout(db, 2000)
    return db
  }

  private func loadSectionNames(from db: OpaquePointer, reminderIDs: [String]) -> [String: String] {
    let reminderIDSet = Set(reminderIDs)

    let reminderColumns = columns(in: "ZREMCDREMINDER", db: db)
    guard !reminderColumns.isEmpty else { return [:] }
    guard reminderColumns.contains("ZLIST") else { return [:] }

    let reminderIdentifierCandidates = [
      "ZDACALENDARITEMUNIQUEIDENTIFIER",
      "ZREMINDERIDENTIFIER",
      "ZCKIDENTIFIER",
    ]
    let reminderIdentifierColumns = reminderIdentifierCandidates.filter { reminderColumns.contains($0) }
    guard !reminderIdentifierColumns.isEmpty else { return [:] }

    let selectColumns = reminderIdentifierColumns + ["ZLIST"]
    let reminderIDList = Array(reminderIDSet)
    let placeholders = Array(repeating: "?", count: reminderIDList.count).joined(separator: ", ")
    let whereClauses = reminderIdentifierColumns.map { "\($0) IN (\(placeholders))" }
    let reminderQuery = "SELECT \(selectColumns.joined(separator: ", ")) FROM ZREMCDREMINDER WHERE \(whereClauses.joined(separator: " OR "))"
    guard let reminderStatement = prepare(db: db, query: reminderQuery) else { return [:] }
    defer { sqlite3_finalize(reminderStatement) }

    var bindIndex: Int32 = 1
    for _ in reminderIdentifierColumns {
      for reminderID in reminderIDList {
        sqlite3_bind_text(reminderStatement, bindIndex, reminderID, -1, sqliteTransient)
        bindIndex += 1
      }
    }

    var reminderToMemberID: [String: String] = [:]
    var reminderToListPK: [String: Int64] = [:]
    var listPKs: Set<Int64> = []

    while sqlite3_step(reminderStatement) == SQLITE_ROW {
      var identifiers: [String] = []
      var memberID: String?
      for (index, column) in reminderIdentifierColumns.enumerated() {
        if let rawValue = stringValue(reminderStatement, index: Int32(index)) {
          let value = rawValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if !value.isEmpty {
            identifiers.append(value)
            if column == "ZDACALENDARITEMUNIQUEIDENTIFIER" {
              memberID = value
            }
          }
        }
      }

      guard let matchedIdentifier = identifiers.first(where: { reminderIDSet.contains($0) }) else { continue }
      if memberID == nil {
        memberID = matchedIdentifier
      }

      let listIndex = Int32(reminderIdentifierColumns.count)
      guard sqlite3_column_type(reminderStatement, listIndex) != SQLITE_NULL else { continue }
      let listPK = sqlite3_column_int64(reminderStatement, listIndex)

      guard let memberID else { continue }
      reminderToMemberID[matchedIdentifier] = memberID
      reminderToListPK[matchedIdentifier] = listPK
      listPKs.insert(listPK)
    }

    guard !listPKs.isEmpty else { return [:] }

    let memberIDs = Set(reminderToMemberID.values)
    var memberToGroupID: [String: String] = [:]

    let listPKList = Array(listPKs)
    let listPlaceholders = Array(repeating: "?", count: listPKList.count).joined(separator: ", ")
    let listQuery = "SELECT Z_PK, ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA FROM ZREMCDBASELIST WHERE Z_PK IN (\(listPlaceholders))"
    if let listStatement = prepare(db: db, query: listQuery) {
      defer { sqlite3_finalize(listStatement) }
      var listBindIndex: Int32 = 1
      for listPK in listPKList {
        sqlite3_bind_int64(listStatement, listBindIndex, listPK)
        listBindIndex += 1
      }

      while sqlite3_step(listStatement) == SQLITE_ROW {
        let data: Data?
        if let blob = blobValue(listStatement, index: 1) {
          data = blob
        } else if let text = stringValue(listStatement, index: 1) {
          data = text.data(using: .utf8)
        } else {
          data = nil
        }

        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let memberships = json["memberships"] as? [[String: Any]]
        else { continue }

        for membership in memberships {
          guard let memberID = membership["memberID"] as? String,
                let groupID = membership["groupID"] as? String
          else { continue }
          if memberIDs.contains(memberID) {
            memberToGroupID[memberID] = groupID
          }
        }
      }
    }

    let sectionColumns = columns(in: "ZREMCDBASESECTION", db: db)
    guard sectionColumns.contains("ZCKIDENTIFIER"), sectionColumns.contains("ZDISPLAYNAME") else { return [:] }

    var sectionsByGroupID: [String: String] = [:]
    var sectionQuery = "SELECT ZCKIDENTIFIER, ZDISPLAYNAME FROM ZREMCDBASESECTION"
    if sectionColumns.contains("ZLIST") {
      sectionQuery += " WHERE ZLIST IN (\(listPlaceholders))"
    }

    if let sectionStatement = prepare(db: db, query: sectionQuery) {
      defer { sqlite3_finalize(sectionStatement) }
      if sectionColumns.contains("ZLIST") {
        var sectionBindIndex: Int32 = 1
        for listPK in listPKList {
          sqlite3_bind_int64(sectionStatement, sectionBindIndex, listPK)
          sectionBindIndex += 1
        }
      }

      while sqlite3_step(sectionStatement) == SQLITE_ROW {
        guard let rawGroupID = stringValue(sectionStatement, index: 0),
              let rawName = stringValue(sectionStatement, index: 1)
        else { continue }
        let groupID = rawGroupID.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let name = rawName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !groupID.isEmpty, !name.isEmpty else { continue }
        sectionsByGroupID[groupID] = name
      }
    }

    var results: [String: String] = [:]
    for (reminderID, memberID) in reminderToMemberID {
      if let groupID = memberToGroupID[memberID], let name = sectionsByGroupID[groupID] {
        results[reminderID] = name
      }
    }

    return results
  }

  private func columns(in table: String, db: OpaquePointer) -> Set<String> {
    let query = "PRAGMA table_info(\(table))"
    guard let statement = prepare(db: db, query: query) else { return [] }
    defer { sqlite3_finalize(statement) }

    var columns: Set<String> = []
    while sqlite3_step(statement) == SQLITE_ROW {
      if let name = stringValue(statement, index: 1) {
        columns.insert(name)
      }
    }
    return columns
  }

  private func prepare(db: OpaquePointer, query: String) -> OpaquePointer? {
    var statement: OpaquePointer?
    if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
      return nil
    }
    return statement
  }

  private func stringValue(_ statement: OpaquePointer, index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let cString = sqlite3_column_text(statement, index)
    else { return nil }
    return String(cString: cString)
  }

  private func blobValue(_ statement: OpaquePointer, index: Int32) -> Data? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let bytes = sqlite3_column_blob(statement, index)
    else { return nil }
    let length = Int(sqlite3_column_bytes(statement, index))
    return Data(bytes: bytes, count: length)
  }

}
