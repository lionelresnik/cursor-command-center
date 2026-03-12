---
name: standup-generator
description: Generate daily or weekly standup summaries from daily logs, todos, and task history. Saves summaries to ~/.command-center/standups/. Use when the user asks for a standup, recap, or at start of day/week.
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

**IMPORTANT: ALWAYS regenerate the standup fresh from source data.** Never just display an existing saved standup file. Even if a standup file for today already exists, regenerate it from scratch by reading all sources — then update the file with the fresh content.

Gather information from these locations (in order of priority):

1. **Daily log** — `~/.command-center/daily-log/YYYY-MM-DD.jsonl` **(primary source)**
   - Find the last working day's log: check yesterday, then day before, up to 7 days back
   - Each line is a JSON entry: `{"time":"...","workspace":"...","ticket":"...","action":"..."}`
   - This is the most accurate record of actual work — use it as the primary source for "Done" items
   - Group entries by workspace for the standup
   - De-duplicate similar entries (same workspace + ticket + similar action = one standup item)

2. **Todos** — `~/.command-center/todos.md`
   - "Done" section: items completed since last standup → **Done** (supplement daily log)
   - "In Progress" section → **Doing**
   - "Pending" section, highest priority → **Up Next**

3. **Task history** — `~/.command-center/task-history/` (ALL workspace folders)
   - Scan ALL subdirectories (e.g., `backend/`, `frontend/`, `infra/`, `shared/`, etc.)
   - Recent task files (last 24h for daily, last 5 work days for weekly)
   - Extract task names, PR links, completion status
   - Use to enrich daily log entries with more context (ticket IDs, PR links)

4. **Session state** — `~/.command-center/session-state.json`
   - Last session time, last workspace

5. **Previous standup** — `~/.command-center/standups/` (most recent file)
   - Compare to detect carryover items

## Finding the Right Daily Log

When generating a standup, you need the **last working day's** log — not necessarily yesterday's:

1. Start with yesterday's date
2. Check if `~/.command-center/daily-log/YYYY-MM-DD.jsonl` exists
3. If not, go back one more day. Repeat up to 7 days.
4. Use the first log file found as the basis for "Done" items
5. If no log file is found within 7 days, fall back to todos + task history only

This handles weekends, holidays, and sick days automatically.

## How to Describe Work Items

**NEVER just list ticket IDs.** For each item, always include:
- **What the issue/request was** (1 short sentence — what was the problem or ask?)
- **What was done** (1 short sentence — what action was taken or completed?)

### Example (Good)
```
- **[backend]** Deployment script failing with `sh` vs `bash` syntax error
  → Fixed: Updated script to use `bash`, added retry/backoff logic
- **[frontend]** Dashboard loading stuck due to expired auth tokens
  → In progress: Added proactive token refresh + retry-on-401 in API client
```

### Example (Bad)
```
- Worked on PROJ-123
- PROJ-456 in progress
```

If you don't have enough context about what the issue was, read the task file to get the TL;DR summary from the frontmatter or first paragraph.

## Daily Standup Format

```markdown
# Standup — [Day, Month DD, YYYY]

> **TL;DR:** [1-sentence summary across ALL workspaces: what was done, what's in progress, what's next]

---

## Done
- **[workspace]** [What the issue/request was]
  → [What was done/completed] ([PR #N](link) if available)

## In Progress
- **[workspace]** [What the issue/request was]
  → [Current status / what's being worked on]
  > **Note:** [carryover note if item was also in progress yesterday]

## Up Next
- **[workspace]** [Task description] (high/medium priority)

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

## Completed ([count] items)
- **[workspace]** [What the issue was] → [What was done] ([day completed])

## Still In Progress
- **[workspace]** [What the issue is] → [Current status] (started [day])

## Carried Over
- **[workspace]** [items that were pending all week]

## Next Week
- **[workspace]** [top priority pending items]

---

> **Tip:** [optional proactive suggestion based on patterns]
```

## Generation Logic

### Daily
1. Find the last working day's daily log (yesterday → day before → ... up to 7 days back)
2. Read all entries from that daily log file
3. Read `~/.command-center/todos.md` for in-progress and pending items
4. Scan ALL folders in `task-history/` to enrich with ticket IDs and PR links
5. Read previous standup (if exists) to detect carryovers
6. Group daily log entries by workspace, de-duplicate similar actions
7. Build the standup: daily log → Done, todos in-progress → In Progress, todos pending → Up Next
8. Save to `~/.command-center/standups/YYYY-MM-DD.md`
9. Display to user

### Weekly
1. Determine work week range from `preferences.workWeek` (e.g., Mon–Fri or Sun–Thu)
2. Read all daily log files from that range (`daily-log/YYYY-MM-DD.jsonl` for each work day)
3. If daily logs exist, aggregate them
4. Also read daily standup files from that range if they exist
5. Fall back to todos + ALL task history for days with no daily log
6. Save to `~/.command-center/standups/YYYY-Www.md`
7. Display to user

## Smart Behaviors

- **Cross-workspace always:** Never limit standup to just the current workspace — always scan all
- **Human-readable descriptions:** Always explain what the issue was + what was done, never just ticket IDs
- **Done items appear once:** When building the "Done" section, check the previous standup. If an item already appeared in a previous standup's "Done" section, **do not include it again**. Only show newly completed items — things that transitioned to done since the last standup. This prevents yesterday's completions from cluttering today's standup.
- **Daily log is truth:** When the daily log exists, prefer its entries over task file analysis. The daily log captures real-time work; task files may be stale.
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
