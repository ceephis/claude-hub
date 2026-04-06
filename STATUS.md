# Hub (Claude HQ Dashboard)
**Status:** ✅ Live
**Started:** 2026-03-26
**Stack:** Elixir/Phoenix · LiveView · Tailwind · file_system watcher · AppleScript · launchd

## Next Action
Fix daily_sync.ex pull-before-push to prevent push failures when remote has new commits.

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
- [x] ↑ Commit & Push button — inline commit message input on card, runs git add -A && git commit && git push
- [x] 🚀 fly.io button — auto-detected from fly.toml (searches 2 levels deep), shows app name on hover
- [x] ⚡ Deploy button — shown when STATUS.md has **Deploy:** field (custom deploy cmd)
- [x] Commit message written to temp file to handle spaces + special characters
- [x] Auto-detect git root in subdirectories (fixes projects where .git lives one level deep)
- [x] Auto git init + gh repo create --private on first commit if no repo exists

### Sync & Filters
- [x] ↑ Sync Today button — commits & pushes all projects with uncommitted changes (git dirty), async with results panel
- [x] 📅 Today filter pill — shows projects with STATUS.md modified today
- [x] ⬆ Needs Git filter pill — shows projects with uncommitted git changes
- [x] Weekly report changed_projects — uses git log to find STATUS.md commits in date range

### Card UI
- [x] ⇄ move icon in header row (replaces full-width dropdown, transparent select overlay)
- [x] Open in Claude + 📄 PDF side-by-side half-buttons
- [x] PDF download — GET /status-pdf/:folder → pandoc generates PDF (falls back to HTML → .md), browser downloads natively, cross-platform

### Weekly Report & Portfolio
- [x] Weekly report: timesheet simplified (Date · Project · Hours, no Description)
- [x] Weekly report: progress bars filtered to this-week-only projects (git-based)
- [x] Portfolio briefing route: GET /portfolio-briefing serves ~/Desktop/Claude/portfolio/project-briefing.html
- [x] Portfolio Briefing button in weekly report nav (opens new tab)
- [x] Portfolio briefing — dynamic est_block per project (hours from timesheet, rate, remaining items, next steps)
- [x] Portfolio briefing — all 15 project pages editorially rewritten + products renamed
- [x] Portfolio briefing — week filter dropdown: client-side JS, week→token map injected as JSON from timesheet, filters pages + cover table rows instantly with no page reload
