---
name: repo-status
description: Check git status across all repos in a workspace. Shows which repos are behind, have uncommitted changes, or need attention. Can auto-pull repos that are clean and behind. Use when the user wants to check the state of their repos or sync them.
---

# Repo Status

## What It Does

Runs `git status` across all repos in a workspace (or all workspaces) and summarizes the results. Optionally auto-pulls repos that are behind but have a clean working tree.

## How to Check Status

When user asks to check repo status:

1. Identify workspace(s) using these methods (in order):
   - Check `.cursor/cc-context.json` for `"workspace"` field
   - Check the open `.code-workspace` filename (e.g., `backend.code-workspace` → workspace is `backend`)
   - Ask the user
2. Read repo paths from `contexts/[workspace].repos`
3. For each repo, run:

```bash
cd /path/to/repo
git fetch origin 2>/dev/null

# Get current branch
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Check for uncommitted changes
changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Check commits behind
behind=$(git rev-list --count HEAD..origin/$branch 2>/dev/null || echo 0)

# Check commits ahead
ahead=$(git rev-list --count origin/$branch..HEAD 2>/dev/null || echo 0)
```

4. Display results grouped by workspace:

```
backend:
  ok   api-service (main)
  warn auth-service (main) - 3 uncommitted changes
  warn db-migrations (main) - 2 behind

Total: 3 repos checked
```

## Auto-Pull (Safe)

When user asks to pull or sync:

- If repo has NO uncommitted changes AND is behind → `git pull`
- If repo has uncommitted changes → skip, show warning
- Report what was pulled and what was skipped

```bash
if [ "$changes" = "0" ] && [ "$behind" -gt 0 ]; then
    git pull origin "$branch"
fi
```

## Status Categories

| Status | Meaning |
|--------|---------|
| ok | Clean, up to date |
| behind | Clean but behind remote — safe to pull |
| uncommitted | Has local changes — skip pull |
| ahead | Has unpushed commits |
| diverged | Both ahead and behind — needs manual resolution |
