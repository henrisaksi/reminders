import Foundation
import SQLite3

struct SectionResolver {
  private let fileManager: FileManager

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

    let sectionColumns = columns(in: "ZREMCDSECTION", db: db)
    guard !sectionColumns.isEmpty else { return [:] }

    let sectionNameColumn = firstExistingColumn(
      in: sectionColumns,
      candidates: ["ZNAME", "ZNAME1", "ZTITLE", "ZTITLE1"]
    )

    guard let sectionNameColumn else { return [:] }

    let sectionCKColumn = sectionColumns.contains("ZCKIDENTIFIER") ? "ZCKIDENTIFIER" : nil

    var sectionsByPK: [Int64: String] = [:]
    var sectionsByCK: [String: String] = [:]

    var sectionQueryColumns = ["Z_PK", sectionNameColumn]
    if let sectionCKColumn {
      sectionQueryColumns.insert(sectionCKColumn, at: 1)
    }

    let sectionQuery = "SELECT \(sectionQueryColumns.joined(separator: ", ")) FROM ZREMCDSECTION"
    if let statement = prepare(db: db, query: sectionQuery) {
      defer { sqlite3_finalize(statement) }
      while sqlite3_step(statement) == SQLITE_ROW {
        let pk = sqlite3_column_int64(statement, 0)
        let ckIndex = sectionCKColumn == nil ? nil : Int32(1)
        let nameIndex: Int32 = sectionCKColumn == nil ? 1 : 2

        let name = stringValue(statement, index: nameIndex)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let name, !name.isEmpty else { continue }
        sectionsByPK[pk] = name

        if let ckIndex, let ckValue = stringValue(statement, index: ckIndex) {
          let ck = ckValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if !ck.isEmpty {
            sectionsByCK[ck] = name
          }
        }
      }
    }

    let listOrdering = loadSectionOrdering(from: db)

    let reminderColumns = columns(in: "ZREMCDREMINDER", db: db)
    guard !reminderColumns.isEmpty else { return [:] }

    let reminderIdentifierCandidates = [
      "ZDACALENDARITEMUNIQUEIDENTIFIER",
      "ZREMINDERIDENTIFIER",
      "ZCKIDENTIFIER",
    ]
    let reminderIdentifierColumns = reminderIdentifierCandidates.filter { reminderColumns.contains($0) }
    guard !reminderIdentifierColumns.isEmpty else { return [:] }

    let sectionRefColumn = firstExistingColumn(
      in: reminderColumns,
      candidates: ["ZSECTION", "ZSECTION1", "ZSECTIONID"]
    )
    let listRefColumn = reminderColumns.contains("ZLIST") ? "ZLIST" : nil

    var selectColumns = reminderIdentifierColumns
    if let sectionRefColumn {
      selectColumns.append(sectionRefColumn)
    }
    if let listRefColumn {
      selectColumns.append(listRefColumn)
    }

    let reminderQuery = "SELECT \(selectColumns.joined(separator: ", ")) FROM ZREMCDREMINDER"
    guard let reminderStatement = prepare(db: db, query: reminderQuery) else { return [:] }
    defer { sqlite3_finalize(reminderStatement) }

    var results: [String: String] = [:]
    while sqlite3_step(reminderStatement) == SQLITE_ROW {
      var identifiers: [String] = []
      for index in 0..<reminderIdentifierColumns.count {
        if let rawValue = stringValue(reminderStatement, index: Int32(index)) {
          let value = rawValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if !value.isEmpty {
            identifiers.append(value)
          }
        }
      }

      guard let matchedIdentifier = identifiers.first(where: { reminderIDSet.contains($0) }) else { continue }

      var sectionName: String?
      var sectionRef: SectionReference?
      if sectionRefColumn != nil {
        let sectionIndex = Int32(reminderIdentifierColumns.count)
        sectionRef = sectionReference(from: reminderStatement, index: sectionIndex)
      }

      let listIndexOffset = reminderIdentifierColumns.count + (sectionRefColumn == nil ? 0 : 1)
      var listPK: Int64?
      if listRefColumn != nil {
        listPK = sqlite3_column_int64(reminderStatement, Int32(listIndexOffset))
      }

      if let sectionRef {
        switch sectionRef {
        case .pk(let pk):
          sectionName = sectionsByPK[pk]
          if sectionName == nil, let listPK, let ordered = listOrdering[listPK], pk >= 0 {
            let index = Int(pk)
            if index < ordered.count {
              sectionName = sectionsByCK[ordered[index]]
            }
          }
        case .ck(let ck):
          sectionName = sectionsByCK[ck]
        }
      }

      if let sectionName {
        results[matchedIdentifier] = sectionName
      }
    }

    return results
  }

  private func loadSectionOrdering(from db: OpaquePointer) -> [Int64: [String]] {
    let listColumns = columns(in: "ZREMCDLIST", db: db)
    guard listColumns.contains("ZSECTIONIDSORDERINGASDATA") else { return [:] }

    let query = "SELECT Z_PK, ZSECTIONIDSORDERINGASDATA FROM ZREMCDLIST"
    guard let statement = prepare(db: db, query: query) else { return [:] }
    defer { sqlite3_finalize(statement) }

    var ordering: [Int64: [String]] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
      let pk = sqlite3_column_int64(statement, 0)
      guard let data = blobValue(statement, index: 1) else { continue }
      if let list = decodeStringArray(from: data), !list.isEmpty {
        ordering[pk] = list
      }
    }
    return ordering
  }

  private func decodeStringArray(from data: Data) -> [String]? {
    if let object = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSString.self], from: data) {
      if let strings = object as? [String] {
        let filtered = strings.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
      }
      if let anyArray = object as? [Any] {
        let strings = anyArray.compactMap { $0 as? String }.filter { !$0.isEmpty }
        if !strings.isEmpty { return strings }
      }
    }

    if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
      if let strings = plist as? [String] {
        let filtered = strings.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
      }
      if let anyArray = plist as? [Any] {
        let strings = anyArray.compactMap { $0 as? String }.filter { !$0.isEmpty }
        if !strings.isEmpty { return strings }
      }
    }

    return nil
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

  private func firstExistingColumn(in columns: Set<String>, candidates: [String]) -> String? {
    candidates.first(where: { columns.contains($0) })
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

  private enum SectionReference {
    case pk(Int64)
    case ck(String)
  }

  private func sectionReference(from statement: OpaquePointer, index: Int32) -> SectionReference? {
    switch sqlite3_column_type(statement, index) {
    case SQLITE_INTEGER:
      return .pk(sqlite3_column_int64(statement, index))
    case SQLITE_TEXT:
      if let rawValue = stringValue(statement, index: index) {
        let value = rawValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !value.isEmpty {
          return .ck(value)
        }
      }
      return nil
    default:
      return nil
    }
  }
}
