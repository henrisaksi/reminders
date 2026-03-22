# Skill: reminders

This skill provides instructions for using the `reminders` CLI tool to manage Apple Reminders on macOS.

## Setup
The `reminders` CLI requires macOS permissions. If you receive an authorization error, instruct the user to run `reminders authorize` and accept the prompt in macOS System Settings.

**Note on Sections:** In order to read and display Reminders Sections (e.g., `[Groceries/Produce]`), the terminal emulator running the CLI must be granted **Full Disk Access** in macOS System Settings so it can read the local SQLite database.

## Commands

### Viewing Reminders
Use `reminders show [filter]` to view reminders.
- **Filters**: `today` (default), `tomorrow`, `week`, `overdue`, `upcoming`, `completed`, `all`, or a specific date like `YYYY-MM-DD`.
- **Options**: 
  - `--list <name>` to limit to a specific list.
  - `--tag <name>` to filter by hashtag.
  - `--json` to return machine-readable output.

### Lists
- List all available lists: `reminders list`
- Show items in a specific list: `reminders list <list_name>`

### Adding Reminders
Use `reminders add "<title>" [options]`.
- **Options**:
  - `--list <name>` to assign to a list.
  - `--due <date>` to set a due date (e.g., `tomorrow`, `YYYY-MM-DD`).
  - `--priority <level>` to set priority (`none`, `low`, `medium`, `high`).
  - `--tag <name>` to add a hashtag (e.g., `--tag urgent`). Repeatable.
  - `--location "<address>"` to set a geofence trigger. **Must be a real, searchable address or city.** It cannot resolve Apple Maps pins or Address Book entries like the word "Home".
  - `--leaving` to trigger when leaving the location instead of arriving.
  - `--radius <meters>` to customize geofence size.
  - `--notes "<text>"` to add notes/description.

### Editing Reminders
Use `reminders edit <id> [options]`.
- The `<id>` is the prefix (e.g., `1`, `2`, `4A83`) found in the output of the `show` command.
- **Options**:
  - `--title "<new_title>"` to rename.
  - `--list <name>` to move to a different list.
  - `--due <date>` or `--clear-due` to modify the due date.
  - `--complete` or `--incomplete` to toggle status.
  - `--tag <name>`, `--remove-tag <name>`, or `--clear-tags` to modify tags.

### Completing & Deleting
- Mark complete: `reminders complete <id> [<id> ...]`
- Delete: `reminders delete <id> [--force]`
