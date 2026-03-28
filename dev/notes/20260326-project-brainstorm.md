# Hub (Claude HQ Dashboard)
*Date: 2026-03-26 | Initial session with Master Claude*

---

## Concept

A local Phoenix LiveView dashboard running at `localhost:9000` that serves as mission control for the entire Claude operation. Displays all active projects as cards, grouped by owner/type, with real-time status pulled directly from each project's STATUS.md. Clicking a card opens a new iTerm2 tab already running `claude --continue` in that project's folder.

Port 9000 chosen deliberately — far from dev ports 4000/4001 used by active Clauderlings.

---

## Core Features

### Project Cards
Each card displays:
- Project name + emoji icon
- Status tag (🟢 Active / 🟡 Planning / 🔴 Paused / ✅ Live)
- Live URL (if deployed)
- Progress bar + percentage (from STATUS.md checklist)
- Task count (e.g. "39 of 48 tasks")
- Next action (one line from STATUS.md)
- Started date + days active
- Stack (one line)
- **[Open in Claude]** button

### Card Layout (visual reference)
```
┌─────────────────────────────────────┐
│ ⚡ EMDR                    🟢 Live  │
│ switch2emdr.com                      │
│                                      │
│ [████████████████░░░░] 81%          │
│ 39 of 48 tasks                       │
│                                      │
│ Next: Legal pages (ToS, Privacy)     │
│                                      │
│ Started Mar 23 · 3 days active       │
│ Stack: Phoenix · Stripe · Fly.io     │
│                                      │
│        [ Open in Claude ]            │
└─────────────────────────────────────┘
```

### Dashboard Header
Always visible at top:
- App name: 🧠 CLAUDE HQ
- Grand total hours (from timesheet)
- Current week hours
- Today's date
- [+ New Group] button

### Groups
- Cards organized into named groups (MY PROJECTS, CLIENT WORK, TOREY, IDEAS, etc.)
- Group management:
  - [+ New Group] button → inline name input → creates empty group
  - [✏️ Rename] and [🗑️ Delete] per group
  - Drag and drop cards between groups
  - Right-click card → "Move to..." context menu (backup for drag)
- **Uncategorized** section auto-catches any new project folder not yet assigned
- Group layout saved to `hub/groups.json`

### Auto-Discovery
- FileSystem watcher scans `~/Desktop/Claude/` continuously
- New folder containing STATUS.md → card appears automatically
- Deleted/moved folder → card disappears
- No manual registration needed
- Excluded folders: `portfolio`, `timesheet`, `hub` (system folders)

---

## The "Open in Claude" Button

Clicking fires an AppleScript that:
1. Opens a new **tab** in the current iTerm2 window (not a new window)
2. Names the tab after the project (e.g. "EMDR")
3. `cd`s to the correct project folder
4. Runs `claude --continue`

Result: iTerm2 builds up named tabs as you open Clauderlings. Switch between them like browser tabs.

AppleScript template:
```applescript
tell application "iTerm2"
  tell current window
    create tab with default profile
    tell current session
      set name to "EMDR"
      write text "cd /Users/pv/Desktop/Claude/EMDR && claude --continue"
    end tell
  end tell
end tell
```

Phoenix calls this via a `System.cmd("osascript", [...])` call from a LiveView event handler.

---

## Data Sources

| Data | Source |
|---|---|
| Project list | Filesystem scan of ~/Desktop/Claude/ |
| Status, progress, next action | Each project's STATUS.md |
| Total hours, week hours | /Users/pv/.claude/memory/project_hours_log.md |
| Group assignments, card order | hub/groups.json |
| Days active | Calculated: today - started date (from STATUS.md) |

STATUS.md is parsed directly — no database needed.

---

## Design Principles

- **VR-friendly:** Large text (16px min body, 20px+ headings), high contrast, generous padding
- **Mouse-first:** Big click targets, drag and drop, right-click menus
- **Always on:** Auto-starts via launchd on Mac login, bookmark localhost:9000
- **Minimal clutter:** Cards breathe, groups are clearly delineated
- **Dark theme:** Easier on eyes in VR headset

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Elixir/Phoenix 1.8 |
| UI | LiveView + Tailwind CSS |
| Realtime updates | Phoenix FileSystem watcher (file_system hex package) |
| iTerm2 integration | AppleScript via System.cmd osascript |
| Data storage | groups.json (flat file, no database) |
| Port | 9000 (hardcoded) |
| Auto-start | launchd plist (Mac login item) |

---

## groups.json Format

```json
{
  "groups": [
    { "name": "MY PROJECTS", "projects": ["EMDR", "pill", "test1", "social", "silence", "verdancy", "ifs"] },
    { "name": "CLIENT WORK", "projects": ["lemonade", "palani"] },
    { "name": "TOREY", "projects": ["security", "spotlight", "teagles"] },
    { "name": "IDEAS", "projects": [] }
  ]
}
```

New folders not in any group appear in auto-generated **Uncategorized** section.

---

## MVP Checklist

### Foundation
- [ ] Initialize Phoenix app (no Ecto, no database)
- [ ] Configure port 9000 in dev.exs and prod config
- [ ] Set up file_system watcher for ~/Desktop/Claude/
- [ ] STATUS.md parser (extract status, progress %, next action, stack, started date)
- [ ] Project card LiveComponent
- [ ] Basic dashboard layout with hard-coded groups

### Groups
- [ ] Load/save groups.json
- [ ] Render groups with cards inside
- [ ] [+ New Group] button with inline form
- [ ] Rename + delete group
- [ ] Uncategorized auto-section for unassigned projects
- [ ] Drag and drop cards between groups (JS hook)
- [ ] Right-click context menu (Move to...)

### iTerm2 Integration
- [ ] AppleScript template for new tab + claude --continue
- [ ] [Open in Claude] button fires LiveView event
- [ ] LiveView event calls osascript via System.cmd
- [ ] Tab named after project

### Header
- [ ] Parse grand total hours from project_hours_log.md
- [ ] Parse current week hours
- [ ] Display today's date
- [ ] [+ New Group] button placement

### Polish
- [ ] Dark theme (VR-friendly)
- [ ] Large text / generous padding
- [ ] Emoji icons per project (configurable)
- [ ] Status color coding
- [ ] Smooth drag animations
- [ ] Auto-start via launchd plist

---

## Open Questions
- Should clicking the card expand it to show full checklist inline?
- Should there be a quick "log hours" button on each card?
- Any projects that should never show (hidden flag in STATUS.md)?
- Should the dashboard show a live terminal output preview when a Clauderling is running?
