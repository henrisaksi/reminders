import Testing

@testable import reminders

@MainActor
struct HelpPrinterTests {
  @Test("Root help includes commands")
  func rootHelp() {
    let specs = [
      ShowCommand.spec,
      ListCommand.spec,
      AddCommand.spec,
      StatusCommand.spec,
      AuthorizeCommand.spec,
    ]
    let lines = HelpPrinter.renderRoot(version: "0.0.0", rootName: "reminders", commands: specs)
    let joined = lines.joined(separator: "\n")
    #expect(joined.contains("show"))
    #expect(joined.contains("list"))
    #expect(joined.contains("add"))
    #expect(joined.contains("status"))
    #expect(joined.contains("authorize"))
  }
}
