# reminders

Forget the app, not the task ✅

Fast CLI for Apple Reminders on macOS.

## Install

### Homebrew (Home Pro)
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

## Usage
```bash
reminders                      # show today (default)
reminders today                 # show today
reminders tomorrow              # show tomorrow
reminders week                  # show this week
reminders overdue               # overdue
reminders upcoming              # upcoming
reminders completed             # completed
reminders all                   # all reminders
reminders 2026-01-03            # specific date

reminders list                  # lists
reminders list Work             # show list
reminders list Work --rename Office
reminders list Work --delete
reminders list Projects --create

reminders add "Buy milk"
reminders add --title "Call mom" --list Personal --due tomorrow
reminders edit 1 --title "New title" --due 2026-01-04
reminders complete 1 2 3
reminders delete 4A83 --force
reminders status                # permission status
reminders authorize             # request permissions
```

## Output formats
- `--json` emits JSON arrays/objects.
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
Terminal (or reminders) in System Settings → Privacy & Security → Reminders.
If running over SSH, grant access on the Mac that runs the command.
