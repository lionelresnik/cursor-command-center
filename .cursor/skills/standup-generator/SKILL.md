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

This means even if the user never explicitly says "I work Sun–Thu", if they keep asking for weekly recaps on Sundays or Thursdays, the system will figure it out and adjust.

## Data Sources

Gather information from these locations (in order):

1. **Todos** — `~/.command-center/todos.md`
   - "Done" section: items completed since last standup → **Done**
   - "In Progress" section → **Doing**
   - "Pending" section, highest priority → **Up Next**

2. **Task history** — `~/.command-center/task-history/[workspace]/`
   - Recent task files (last 24h for daily, last 5 work days for weekly)
   - Extract task names, PR links, completion status

3. **Session state** — `~/.command-center/session-state.json`
   - Last session time, last workspace

4. **Previous standup** — `~/.command-center/standups/` (most recent file)
   - Compare to detect carryover items

## Daily Standup Format

```markdown
# Standup — [Day, Month DD, YYYY]

> **TL;DR:** [1-sentence summary: what was done, what's in progress, what's next]

---

## Done
- ✅ Completed [task] in **[workspace]** (PR: [#N](link))
- ✅ Marked done: [todo item]

## In Progress
- 🔄 Working on [task] in **[workspace]**
  > **Note:** [carryover note if item was also in progress yesterday]

## Up Next
- 📌 [highest priority pending todo] (`⚡ high`)
- 📌 [next item]

---

> **Tip:** [optional proactive suggestion based on stale items or patterns]
```

## Weekly Standup Format

```markdown
# Weekly Recap — Week [W], [YYYY]
**[Start date] → [End date]**

> **TL;DR:** [1-sentence summary of the week]

---

## Highlights
- [most impactful items completed this week]

## Completed ([count] items)
- ✅ [task] in **[workspace]** ([day completed])

## Still In Progress
- 🔄 [task] in **[workspace]** (started [day])

## Carried Over
- 📌 [items that were pending all week]

## Next Week
- 📌 [top priority pending items]

---

> **Tip:** [optional proactive suggestion based on patterns]
```

## Generation Logic

### Daily
1. Read `~/.command-center/todos.md`
2. Read recent task files from `task-history/` (modified in last 24h)
3. Read previous standup (if exists) to detect carryovers
4. Build the standup
5. Save to `~/.command-center/standups/YYYY-MM-DD.md`
6. Display to user

### Weekly
1. Determine work week range from `preferences.workWeek` (e.g., Mon–Fri or Sun–Thu)
2. Read all daily standups from that range
3. If daily standups exist, aggregate them
4. If not, fall back to todos + task history for those days
5. Save to `~/.command-center/standups/YYYY-Www.md`
6. Display to user

## Smart Behaviors

- **Carryover detection:** If an item was "In Progress" yesterday and still is, note it
- **Stale item alerts:** In progress for 3+ days → flag in Notes
- **Empty standup:** No activity found → "Quiet day yesterday" — don't fabricate items
- **PR linking:** Task files with PR URLs → include in Done items
- **Cross-workspace:** Standups span all workspaces, grouped within each section

## Auto-Prompt Rules

When `isNewDay: true` in `.cursor/cc-context.json`:
- Mention: "Want me to generate today's standup?"
- Don't auto-generate — always ask first

When `isStartOfWeek: true` (first work day of the week per `preferences.workWeek`):
- Ask: "Start of the week — want a recap of last week?"

These prompts integrate with the daily-recap rule's greeting flow.
