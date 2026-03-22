# reminders

Forget the app, not the task ✅

Fast CLI for Apple Reminders on macOS.

> [!NOTE]
> This project is an active continuation and fork of the unmaintained [steipete/remindctl](https://github.com/steipete/remindctl) project, adding powerful new features like Reminders Sections support and Tags (hashtags) management.

## Install

### Homebrew (macOS)
```bash
brew install henrisaksi/tap/reminders
```

### From source
```bash
pnpm install
pnpm build
# binary at ./bin/reminders
```

## Development
```bash
make reminders ARGS="status"   # clean build + run
make check                     # lint + test + coverage gate
```

## Requirements
- macOS 14+ (Sonoma or later)
- Swift 6.2+
- Reminders permission (System Settings → Privacy & Security → Reminders)
- *Optional:* Full Disk Access for your terminal app (required to display Reminders Sections)

## Usage
```bash
reminders                       # show today (default)
reminders today                 # show today
reminders tomorrow              # show tomorrow
reminders week                  # show this week
reminders overdue               # overdue
reminders upcoming              # upcoming
reminders completed             # completed
reminders all                   # all reminders
reminders 2026-01-03            # specific date

# Lists and Sections
reminders list                  # lists
reminders list Work             # show list (will display sections if terminal has Full Disk Access)
reminders list Work --rename Office
reminders list Work --delete
reminders list Projects --create

# Tags
reminders tags                  # list all unique tags with counts
reminders tags shopping         # show reminders matching a tag
reminders show --tag shopping   # filter any view by tag

# Manage
reminders add "Buy milk"
reminders add --title "Call mom" --list Personal --due tomorrow
reminders add "Fix bug" --tag urgent --tag work
reminders edit 1 --title "New title" --due 2026-01-04
reminders edit 2 --tag done --remove-tag urgent
reminders complete 1 2 3
reminders delete 4A83 --force
reminders status                # permission status
reminders authorize             # request permissions
```

## Output formats
- `--json` emits JSON arrays/objects (including tags and section metadata).
- `--plain` emits tab-separated lines.
- `--quiet` emits counts only.

## Date formats
Accepted by `--due` and filters:
- `today`, `tomorrow`, `yesterday`
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm`
- ISO 8601 (`2026-01-03T12:34:56Z`)

## Permissions
Run `reminders authorize` to trigger the system prompt. If access is denied, enable
Terminal (or your terminal emulator) in System Settings → Privacy & Security → Reminders.
If running over SSH, grant access on the Mac that runs the command.

**Note on Sections:** To display Reminders Sections (e.g. `[Groceries/Produce]`), your terminal emulator must be granted **Full Disk Access** in System Settings to allow the CLI to read the internal Reminders database.
