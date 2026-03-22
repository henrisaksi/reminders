import Commander
import Foundation
import RemindCore

enum AuthorizeCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "authorize",
      abstract: "Request Reminders access",
      discussion: "Triggers the Reminders permission prompt when available.",
      signature: CommandSignatures.withRuntimeFlags(CommandSignature()),
      usageExamples: [
        "reminders authorize",
        "reminders authorize --json",
        "reminders authorize --quiet",
      ]
    ) { _, runtime in
      let store = RemindersStore()
      let current = RemindersStore.authorizationStatus()
      let status: RemindersAuthorizationStatus
      if current == .notDetermined {
        status = try await store.requestAuthorization()
      } else {
        status = current
      }

      OutputRenderer.printAuthorizationStatus(status, format: runtime.outputFormat)

      switch status {
      case .fullAccess:
        return
      case .writeOnly:
        throw RemindCoreError.writeOnlyAccess
      case .notDetermined, .denied, .restricted:
        throw RemindCoreError.accessDenied
      }
    }
  }
}
