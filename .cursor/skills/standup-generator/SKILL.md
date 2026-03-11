---
name: standup-generator
description: Generate daily or weekly standup summaries from todos and task history. Saves summaries to ~/.command-center/standups/. Use when the user asks for a standup, recap, or at start of day/week.
---

# Standup Generator

## Storage

Standups are saved as markdown files in `~/.command-center/standups/`:

- **Daily:** `YYYY-MM-DD.md`
- **Weekly:** `YYYY-Www.md` (e.g., `2026-W08.md`)

## Work Week Configuration

Not everyone works Monday–Friday. The user's work week is stored in `~/.command-center/profile.json` under `preferences.workWeek`:

- `"mon-fri"` — Monday to Friday (default)
- `"sun-thu"` — Sunday to Thursday

If not set, default to `"mon-fri"`. The **first day** of the work week determines when "start of week" prompts trigger and which days the weekly recap covers.

### Adaptive Learning

When the user asks for a **weekly** standup or recap, append the current day name to `preferences.weeklyRequestDays` in `profile.json`. The personalization rule monitors this array and auto-detects the work week pattern after 2+ requests on the same day (see `personalization.mdc` for details).

## Data Sources

**IMPORTANT: Standups are ALWAYS cross-workspace.** Read ALL workspaces, not just the current one.

**IMPORTANT: ALWAYS regenerate the standup fresh from source data.** Never just display an existing saved standup file. Even if a standup file for today already exists, regenerate it from scratch by reading todos and task history — then update the file with the fresh content.

Gather information from these locations (in order):

1. **Todos** — `~/.command-center/todos.md`
   - "Done" section: items completed since last standup → **Done**
   - "In Progress" section → **Doing**
   - "Pending" section, highest priority → **Up Next**

2. **Task history** — `~/.command-center/task-history/` (ALL workspace folders)
   - Scan ALL subdirectories: `cspm/`, `supply-chain/`, `backend/`, `platform/`, `shared/`, etc.
   - Recent task files (last 24h for daily, last 5 work days for weekly)
   - Extract task names, PR links, completion status

3. **Session state** — `~/.command-center/session-state.json`
   - Last session time, last workspace

4. **Previous standup** — `~/.command-center/standups/` (most recent file)
   - Compare to detect carryover items

## How to Describe Work Items

**NEVER just list ticket IDs.** For each item, always include:
- **What the issue/request was** (1 short sentence — what was the problem or ask?)
- **What was done** (1 short sentence — what action was taken or completed?)

### Example (Good ✅)
```
- ✅ **[cspm]** GCP onboarding script failing with `sh` vs `bash` syntax error
  → Fixed: Updated UI to use `bash` instead of `sh`, added retry/backoff logic
- 🔄 **[supply-chain]** Repos stuck scanning due to expired JWT tokens
  → In progress: Added proactive JWT refresh + retry-on-401 in scanner client
```

### Example (Bad ❌)
```
- ✅ Worked on PROJ-123
- 🔄 PROJ-456 in progress
```

If you don't have enough context about what the issue was, read the task file to get the TL;DR summary from the frontmatter or first paragraph.

## Daily Standup Format

```markdown
# Standup — [Day, Month DD, YYYY]

> **TL;DR:** [1-sentence summary across ALL workspaces: what was done, what's in progress, what's next]

---

## ✅ Done
- **[workspace]** [What the issue/request was]
  → [What was done/completed] ([PR #N](link) if available)

## 🔄 In Progress
- **[workspace]** [What the issue/request was]
  → [Current status / what's being worked on]
  > **Note:** [carryover note if item was also in progress yesterday]

## 📌 Up Next
- **[workspace]** [Task description] (`⚡ high`)

---

> **Tip:** [optional proactive suggestion based on stale items or patterns]
```

## Weekly Standup Format

```markdown
# Weekly Recap — Week [W], [YYYY]
**[Start date] → [End date]**

> **TL;DR:** [1-sentence summary of the week across all workspaces]

---

## Highlights
- [most impactful items completed this week, with brief what/why]

## ✅ Completed ([count] items)
- **[workspace]** [What the issue was] → [What was done] ([day completed])

## 🔄 Still In Progress
- **[workspace]** [What the issue is] → [Current status] (started [day])

## 📌 Carried Over
- **[workspace]** [items that were pending all week]

## Next Week
- **[workspace]** [top priority pending items]

---

> **Tip:** [optional proactive suggestion based on patterns]
```

## Generation Logic

### Daily
1. Read `~/.command-center/todos.md`
2. Scan ALL folders in `task-history/` (not just current workspace)
3. For each recent task file, read the TL;DR and progress to understand what was done
4. Read previous standup (if exists) to detect carryovers
5. Build the standup grouped by workspace within each section
6. Save to `~/.command-center/standups/YYYY-MM-DD.md`
7. Display to user

### Weekly
1. Determine work week range from `preferences.workWeek` (e.g., Mon–Fri or Sun–Thu)
2. Read all daily standups from that range
3. If daily standups exist, aggregate them
4. If not, fall back to todos + ALL task history for those days
5. Save to `~/.command-center/standups/YYYY-Www.md`
6. Display to user

## Smart Behaviors

- **Cross-workspace always:** Never limit standup to just the current workspace — always scan all
- **Human-readable descriptions:** Always explain what the issue was + what was done, never just ticket IDs
- **Done items appear once:** When building the "Done" section, check the previous standup. If an item already appeared in a previous standup's "Done" section, **do not include it again**. Only show newly completed items — things that transitioned to done since the last standup. This prevents yesterday's completions from cluttering today's standup.
- **Carryover detection:** If an item was "In Progress" yesterday and still is, note it
- **Stale item alerts:** In progress for 3+ days → flag in Notes
- **Empty standup:** No activity found → "Quiet day yesterday" — don't fabricate items
- **PR linking:** Task files with PR URLs → include in Done items

## Auto-Prompt Rules

When `isNewDay: true` in `.cursor/cc-context.json`:
- Mention: "Want me to generate today's standup?"
- Don't auto-generate — always ask first

When `isStartOfWeek: true` (first work day of the week per `preferences.workWeek`):
- Ask: "Start of the week — want a recap of last week?"

These prompts integrate with the daily-recap rule's greeting flow.
