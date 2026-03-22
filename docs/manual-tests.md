# Manual tests

## Scope
Run on a local GUI session (not SSH-only) so the Reminders permission prompt can appear.

## Test data
- Use a dedicated list: `reminders-manual-YYYYMMDD` (create if missing).
- Create 3 reminders with distinct states:
  - `reminders test A` (due today, priority high)
  - `reminders test B` (due tomorrow)
  - `reminders test C` (no due date)

## Checklist
- authorize: `reminders authorize`
- status: `reminders status`
- list lists: `reminders list`
- list list contents: `reminders list "reminders-manual-YYYYMMDD"`
- add reminders (3 variants)
- show filters: `today`, `tomorrow`, `week`, `overdue`, `upcoming`, `completed`, `all`
- edit: update title/notes/priority/due date
- complete: mark one reminder complete
- delete: remove reminders, then delete list

## Results
- Date:
- Machine:
- Permission state before/after:
- Notes:
