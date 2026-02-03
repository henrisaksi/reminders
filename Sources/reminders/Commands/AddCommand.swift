import Commander
import Foundation
import RemindCore

enum AddCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "add",
      abstract: "Add a reminder",
      discussion: "Provide a title as an argument or via --title.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "title", help: "Reminder title", isOptional: true)
          ],
          options: [
            .make(label: "title", names: [.long("title")], help: "Reminder title", parsing: .singleValue),
            .make(label: "list", names: [.short("l"), .long("list")], help: "List name", parsing: .singleValue),
            .make(label: "due", names: [.short("d"), .long("due")], help: "Due date", parsing: .singleValue),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Notes", parsing: .singleValue),
            .make(
              label: "tag",
              names: [.long("tag")],
              help: "Tag name (repeatable or comma-separated)",
              parsing: .singleValue
            ),
            .make(
              label: "priority",
              names: [.short("p"), .long("priority")],
              help: "none|low|medium|high",
              parsing: .singleValue
            ),
            .make(
              label: "location",
              names: [.long("location")],
              help: "Location address for geofence trigger",
              parsing: .singleValue
            ),
            .make(
              label: "radius",
              names: [.long("radius")],
              help: "Geofence radius in meters (default: 100)",
              parsing: .singleValue
            ),
          ],
          flags: [
            .make(label: "leaving", names: [.long("leaving")], help: "Trigger when leaving location (default: arriving)"),
          ]
        )
      ),
      usageExamples: [
        "reminders add \"Buy milk\"",
        "reminders add --title \"Call mom\" --list Personal --due tomorrow",
        "reminders add \"Review docs\" --priority high",
        "reminders add \"Buy milk\" --tag shopping --tag urgent",
        "reminders add \"Buy milk\" --tag shopping,urgent",
        "reminders add \"Check mailbox\" --location \"50 West St, New York, NY\"",
        "reminders add \"Lock up\" --location \"Home\" --leaving",
      ]
    ) { values, runtime in
      let titleOption = values.option("title")
      let titleArg = values.argument(0)
      if titleOption != nil && titleArg != nil {
        throw RemindCoreError.operationFailed("Provide title either as argument or via --title")
      }

      var title = titleOption ?? titleArg
      if title == nil {
        if runtime.noInput || !Console.isTTY {
          throw RemindCoreError.operationFailed("Missing title. Provide it as an argument or via --title.")
        }
        title = Console.readLine(prompt: "Title:")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if title?.isEmpty == true { title = nil }
      }

      guard let title else {
        throw RemindCoreError.operationFailed("Missing title.")
      }

      let listName = values.option("list")
      let notes = values.option("notes")
      let dueValue = values.option("due")
      let priorityValue = values.option("priority")
      let tagValues = values.optionValues("tag")
      let locationValue = values.option("location")
      let isLeaving = values.flag("leaving")
      let radiusValue = values.option("radius")

      let dueDate = try dueValue.map(CommandHelpers.parseDueDate)
      let priority = try priorityValue.map(CommandHelpers.parsePriority) ?? .none
      let tags = try CommandHelpers.parseTags(tagValues)
      let parsedTitle = CommandHelpers.parseTitleTags(title)
      let mergedTags = CommandHelpers.mergeTags(existing: parsedTitle.tags, add: tags, remove: [], clear: false)
      let titleWithTags = CommandHelpers.composeTitle(baseTitle: parsedTitle.baseTitle, tags: mergedTags)

      // Build location trigger if specified
      let locationTrigger: LocationTrigger?
      if let address = locationValue {
        let radius = radiusValue.flatMap { Double($0) } ?? 100.0
        let proximity: LocationProximity = isLeaving ? .leaving : .arriving
        locationTrigger = LocationTrigger(address: address, radius: radius, proximity: proximity)
      } else {
        locationTrigger = nil
      }

      let store = RemindersStore()
      try await store.requestAccess()

      let targetList: String?
      if let listName {
        targetList = listName
      } else {
        targetList = await store.defaultListName()
      }
      guard let targetList else {
        throw RemindCoreError.operationFailed("No default list found. Specify --list.")
      }

      let draft = ReminderDraft(title: titleWithTags, notes: notes, dueDate: dueDate, priority: priority, location: locationTrigger)
      let reminder = try await store.createReminder(draft, listName: targetList)
      OutputRenderer.printReminder(reminder, format: runtime.outputFormat)
    }
  }
}
