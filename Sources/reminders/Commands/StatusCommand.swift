import Commander
import Foundation
import RemindCore

enum StatusCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "status",
      abstract: "Show Reminders authorization status",
      discussion: "Reports the current Reminders permission state without prompting.",
      signature: CommandSignatures.withRuntimeFlags(CommandSignature()),
      usageExamples: [
        "reminders status",
        "reminders status --json",
        "reminders status --plain",
      ]
    ) { _, runtime in
      let status = RemindersStore.authorizationStatus()
      OutputRenderer.printAuthorizationStatus(status, format: runtime.outputFormat)
      if runtime.outputFormat == .standard, !status.isAuthorized {
        for line in PermissionsHelp.guidanceLines(for: status) {
          Swift.print(line)
        }
      }
    }
  }
}
