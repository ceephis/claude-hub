# Hub (Claude HQ Dashboard)
**Status:** ✅ Live
**Started:** 2026-03-26
**Stack:** Elixir/Phoenix · LiveView · Tailwind · file_system watcher · AppleScript · launchd

## Next Action
Running live at localhost:9000 — auto-starts on login via launchd.

## Checklist
### Foundation
- [x] Initialize Phoenix app (no Ecto, no database)
- [x] Configure port 9000
- [x] Set up file_system watcher for ~/Desktop/Claude/
- [x] STATUS.md parser (status, progress %, next action, stack, started date)
- [x] Project card component
- [x] Basic dashboard layout with groups

### Groups
- [x] Load/save groups.json
- [x] Render groups with cards
- [x] [+ New Group] button with inline form
- [x] Rename + delete group
- [x] Infinite nesting (unlimited depth)
- [x] Uncategorized auto-section
- [x] Move cards between groups (dropdown)

### iTerm2 Integration
- [x] AppleScript template for new tab + claude --continue
- [x] [Open in Claude] button → LiveView event → osascript
- [x] Project name badge (persistent watermark in terminal)

### Header
- [x] Total hours from timesheet.md
- [x] Current week hours
- [x] Today's date
- [x] [+ New Group] button

### Polish
- [x] Dark theme (VR-friendly)
- [x] Status color coding + emoji dots
- [x] Filter pills by status
- [x] Search bar
- [x] Mini cards at intermediate group levels
- [x] Expand mini card → scroll to full card
- [x] Live reload on STATUS.md changes
- [x] launchd plist — auto-starts on login

### Deploy Buttons
- [x] ↑ Push button on every card (opens iTerm tab, runs git push)
- [x] ⚡ Deploy button — shown when STATUS.md has **Deploy:** field
- [x] Deploy field parsed from STATUS.md (e.g. `**Deploy:** fly deploy`)
