# Changelog

## 1.0.0 - 2026-03-22
- **Project Fork & Rename:** Officially forked `steipete/remindctl` to `henrisaksi/reminders`.
- **Feature:** Added read-only support for Apple Reminders sections via SQLite database parsing. Sections are automatically appended to list names (e.g., `[Groceries/Produce]`) when the terminal app has Full Disk Access.
- **Feature:** Added first-class Tags (hashtag) support.
  - `reminders tags` command to list tags and filter by tags.
  - `--tag` flag added to `add`, `edit`, and `show` commands.
  - New `--remove-tag` and `--clear-tags` flags in `edit`.
  - Tags array properly exposed in JSON output.
- **Feature:** Added location-based (geofence) reminder triggers.
  - `--location <address>` flag added to `add` command.
  - `--leaving` flag to trigger when departing instead of arriving.
  - `--radius <meters>` flag for geofence size customization.
- **Docs:** Updated README to feature homebrew tap instructions (`brew install henrisaksi/tap/reminders`) and added `SKILL.md` for AI agent instructions.

## 0.1.1 - 2026-01-11
- Fix Swift 6 strict concurrency crash when fetching reminders

## 0.1.0 - 2026-01-03
- Reminders CLI with Commander-based command router
- Show reminders with filters (today/tomorrow/week/overdue/upcoming/completed/all/date)
- Manage lists (list, create, rename, delete)
- Add, edit, complete, and delete reminders
- Authorization status and permission prompt command
- JSON and plain output modes for scripting
- Flexible date parsing (relative, ISO 8601, and common formats)
- GitHub Actions CI with lint, tests, and coverage gate
