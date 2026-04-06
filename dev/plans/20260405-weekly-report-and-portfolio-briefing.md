# Plan: Weekly Report Redesign + Portfolio Briefing Integration
**Date:** 2026-04-05  
**For:** HQ Claude (hub project)  
**From:** The Claude who worked on the portfolio briefing and had this planning conversation with pv

Read this fully before touching anything. There are two separate workstreams here and important context behind both.

---

## Context: What Was Discussed

pv wants two things:

1. **Redesign the weekly report** at `/weekly-report` — simplify the timesheet, filter the progress bars to this-week-only projects, and add a Portfolio Briefing button.
2. **Understand the Portfolio Briefing** so you can eventually integrate it into HQ cleanly — but NOT regenerate it yet. pv wants to review it for errors in the morning before it goes to Torey.

These were discussed as a handoff to you because you own the `hub` codebase and touch all projects. The portfolio briefing itself is cross-project by nature, which is why it makes sense to surface it from HQ.

---

## Part 1: Weekly Report Redesign

### What to change

The weekly report lives at:
- `hub/lib/hub/weekly_report.ex` — data builder
- `hub/lib/hub_web/controllers/weekly_report_controller.ex` — thin controller
- `hub/lib/hub_web/controllers/weekly_report_html/show.html.heex` — the template
- `hub/lib/hub_web/controllers/weekly_report_html.ex` — helper functions

### Page 1 — Timesheet (simplify)

**Current:** Date · Day · Project · Description · Hours (with day subtotals and week total)  
**Desired:** Date · Project · Hours only — no description column at all

- Remove the `Description` column from the `<thead>` and all `<td>` cells in `show.html.heex`
- Keep the day subtotal rows and week total — pv specifically said "summarized by date and by week"
- The `build_timesheet/2` in `weekly_report.ex` already groups by day with totals — no backend changes needed, just the template

### Page 2 — Progress Bars (filter to this week only)

**Current:** Shows ALL non-live projects regardless of whether they were touched this week  
**Desired:** Only show projects that had STATUS.md committed to git during the report week

The `changed_projects` logic in `weekly_report.ex` already does git-based detection via `status_changed_in_git?/3`. Reuse that same function to filter the progress bar list.

Change `build_projects_progress/0` to accept `week_start` and `week_end` parameters and filter using the same `status_changed_in_git?` check:

```elixir
# Before:
defp build_projects_progress do
  Hub.ProjectScanner.scan()
  |> Enum.reject(&(&1.status_key == :live))
  |> Enum.sort_by(&(-&1.progress))
end

# After:
defp build_projects_progress(week_start, week_end) do
  since = Date.to_iso8601(week_start)
  until = Date.to_iso8601(Date.add(week_end, 1))

  Hub.ProjectScanner.scan()
  |> Enum.filter(&status_changed_in_git?(&1, since, until))
  |> Enum.sort_by(&(-&1.progress))
end
```

Then update `build/1` to pass `week_start` and `week_end` to `build_projects_progress`.

### Page 3+ — Changed Projects

No changes needed. The existing `changed_projects` section (one page per project, checklist items, next action) is exactly what pv wants. Leave it as-is.

### New Button: Portfolio Briefing

Add a button to the nav bar in `show.html.heex` alongside the existing "Save as PDF" button:

```html
<a
  href="/portfolio-briefing"
  target="_blank"
  class="text-sm bg-emerald-600 hover:bg-emerald-500 text-white px-4 py-1.5 rounded-lg transition-colors font-medium"
>📋 Portfolio Briefing</a>
```

This button should open the portfolio briefing in a new tab. For now, it serves a static file (see Part 2 below). Route TBD based on how you wire it up.

---

## Part 2: Portfolio Briefing — Full Context

### What it is

The Portfolio Briefing (`portfolio/project-briefing.md` and `portfolio/project-briefing.html`) is a **director/investor-facing document** written for Torey — pv's business contact who needs a high-level view of why each project exists, what it's worth, who it's for, and what makes it defensible. It is NOT a dev status report. It is a pitch document + portfolio overview.

### File locations

```
~/Desktop/Claude/portfolio/project-briefing.md   ← source (Markdown)
~/Desktop/Claude/portfolio/project-briefing.html  ← rendered (HTML, styled)
~/Desktop/Claude/portfolio/PROJECTS.md            ← internal progress tracking (different doc)
```

The `portfolio/` directory is its own git repo. The briefing was created on 2026-04-05 in a separate Claude session.

### How it was built

This was NOT auto-generated from templates. It was written manually by reading:
- Each project's `STATUS.md` (current state, checklist, stack)
- `portfolio/PROJECTS.md` (internal progress tracking, revenue estimates, audience descriptions)
- The actual source code for several projects (to confirm features were really built, not just planned)
- Market research applied per-project (competitor pricing, TAM estimates, clinical stats for EMDR, etc.)

The reason it required judgment: facts in STATUS.md are feature-lists, not business narratives. The briefing translates "magic link auth built" into "no login required for clients — they click a link, that's it." That translation requires understanding the product.

### Why the structure was chosen — important

**Value Index table first:** Torey needs to scan the portfolio at a glance before reading anything. The table gives him status, revenue model, tier, and ARR range for all 16 projects in seconds. Sorted by tier (Commercial → Growth → Service → Infrastructure), not alphabetically, because that's how an investor thinks about a portfolio.

**Tiered structure:**
- Tier 1 Commercial: Switch2EMDR, DocuForge, Silence, Security Auditor — these have real revenue models, real markets, and are closest to generating meaningful ARR
- Tier 2 Growth: Social, Safe, Pill, Mileage Tracker, IFS Parts Mapper, Verdancy — real ideas, real markets, earlier stage or lower ARR ceiling
- Tier 3 Service/Client: Teagles, Lemon-aid, Palani, Spotlight — client work and templates, indirect revenue
- Infrastructure: Claude HQ — internal only

This tiering was deliberate. It lets Torey focus attention where it matters most without dismissing service work.

**Per-project template (in this order):**
1. What It Is — one paragraph, plain English, no jargon
2. The End User Experience — concrete walkthrough of what a real user does step by step (this is the most important section for non-technical readers)
3. Market & Competitors — table format, always ends with our product in bold for visual contrast
4. Differentiation — the genuine moat, not marketing fluff
5. Revenue / ROI — specific numbers with specific assumptions, not vague ranges
6. Current State — honest about what's built vs. what's planned

The competitor tables were structured to highlight our specific differentiators as columns. For example, the EMDR table columns are "Haptics" and "Real-time therapist control" because those are exactly what we have and competitors don't. The Security table columns are "SMB-friendly" and "Pi-deployable" for the same reason. Each table was designed to make the competitor comparison feel inevitable rather than cherry-picked.

### Known errors / things to review before sending to Torey

pv specifically said: "I believe it still has errors in it. Something I want to research in the morning before sending it off to Torey."

Here are the specific areas most likely to need correction:

1. **EMDR — PS4/PS5 support**: Added today (2026-04-05). The briefing mentions PS4 (DualShock 4) and PS5 (DualSense) as supported. Verify the exact wording matches what's actually live and tested vs. in development. "Xbox — in development" is in the briefing but double-check this is still accurate.

2. **Security Auditor**: Major work done today — SSDP, mDNS, SNMP multi-method discovery, scan progress UI, cross-platform laptop agent. The briefing's "Current State" section may not fully reflect today's session. Worth updating.

3. **DocuForge progress "~90% complete"**: The STATUS.md has a long active checklist and the Teams/Permissions v1.6 work just wrapped. Verify the percentage feels right. There's also "one real-world end-to-end test remaining" — confirm that's still the only blocker.

4. **Share "~40% complete"**: STATUS.md marks it as 🟡 Planning. The briefing says ~40% complete. That may be overstated. Check PROJECTS.md to reconcile.

5. **Revenue projections**: The ARR numbers are estimates built from public data (therapist counts, market research, comparable SaaS pricing). They're defensible but pv should review each one to make sure he's comfortable stating them to Torey. Particularly: Silence's $400K–$5M range is wide and based on a hardware product that hasn't shipped Phase 2 yet.

6. **DocuForge timesheet entries show 0.0 hours**: This is a timesheet tracking issue, not a briefing error, but worth noting for context.

7. **PROJECTS.md is outdated**: The internal `portfolio/PROJECTS.md` shows progress bars last updated 2026-03-26 with wrong percentages. The briefing was written from a newer read of STATUS.md files, not PROJECTS.md. Don't use PROJECTS.md as the source of truth for the briefing — use STATUS.md directly.

### What NOT to do with the briefing (yet)

- **Do not auto-regenerate it from a template.** The prose quality matters for a Torey-facing document. A templated regeneration would produce flat, mechanical output. When/if you build a regeneration feature, it needs to preserve the narrative quality — or just regenerate the "Current State" and stats sections while leaving the prose intact.
- **Do not overwrite `project-briefing.html` without pv's approval.** He wants to review it for errors first.

### Future: making the briefing regeneratable

When pv is ready, the right approach is probably:
- A route in HQ: `GET /portfolio-briefing` that serves `portfolio/project-briefing.html` as a static file (simple, immediate)
- A separate `GET /portfolio-briefing/regenerate` or a button that runs a Mix task / GenServer job that: reads PROJECTS.md + all STATUS.md files, fills in a pre-written template for each project, and outputs fresh HTML
- The template approach works for "Current State" and progress numbers, but the competitive analysis and revenue projections need human review each time — flag that in the UI

### The Torey Send Feature (future, don't build yet)

pv eventually wants a button that emails the weekly report + portfolio briefing to Torey. Rules:
- Initially: send everything, every week
- Later: filter to only send if there's new functionality or new pricing/revenue comparisons since the last send
- This requires: an email integration (Resend would be consistent with what other projects use), a "last sent" timestamp, and a diff mechanism on the briefing content

Do not build this yet. Just understand it's coming so you can architect cleanly.

---

## Build order recommendation

1. Weekly report: simplify timesheet columns (template only, 10 min)
2. Weekly report: filter progress bars to this-week projects (backend + template, 20 min)
3. Add `/portfolio-briefing` static file route that serves `portfolio/project-briefing.html`
4. Add "Portfolio Briefing" button to weekly report nav

Do NOT build the send-to-Torey feature or briefing regeneration until pv explicitly asks.

---

## What pv said about who owns what

- Weekly report changes → HQ Claude (you). Clearly in your codebase.
- Portfolio Briefing integration (button, static route) → HQ Claude (you). You scan all projects already and HQ is the right home.
- Briefing regeneration → TBD. May require a dedicated session. The briefing requires judgment, not just scanning.
- Send to Torey → Future feature, separate conversation.
