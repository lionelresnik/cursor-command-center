---
name: workspace-manager
description: Create, open, and manage multi-repo workspaces. Scans directories for git repos, creates .code-workspace files, and lets users add or remove repos from workspaces. Use when the user wants to set up a new workspace, add repos, or reorganize their project groups.
---

# Workspace Manager

## Determining the Current Workspace

**ALWAYS read `.cursor/cc-context.json` first** to determine which workspace you're in. The `"workspace"` field tells you the current workspace name (e.g., `"platform"`, `"cspm"`, `"backend"`).

```bash
cat ~/.command-center/.cursor/cc-context.json | grep '"workspace"'
```

**DO NOT guess the workspace from open files** — a user might have `server/go.mod` open but be in the `platform` workspace, not `cspm`. The `cc-context.json` is the source of truth.

When adding repos to "this workspace" or "the current workspace", use the workspace name from `cc-context.json`.

## Finding Repos in the Current Workspace

**DO NOT rely on `user_info.workspace_paths`** — that's a snapshot from when the window opened and may be stale after workspace modifications.

Instead, **read the `.code-workspace` file directly** to see the current repos:

```bash
cat ~/.command-center/workspaces/[workspace-name].code-workspace
```

This shows the actual current state, including any repos added during this session.

## Capabilities

- Create new multi-repo workspaces (.code-workspace files)
- Add repos to existing workspaces
- Remove repos from workspaces
- Open workspaces in Cursor
- List available workspaces and their repos

## Data Location

Command Center stores its data in `~/.command-center/` (create if missing):
- `workspaces/` — .code-workspace files
- `contexts/` — repo lists (.repos files, format: `name|path` per line)
- `task-history/` — work logs by workspace
- `docs/` — reference docs by workspace
- `config.json` — settings and tracked directories

## Creating a Workspace

When user asks to create a workspace:

1. Ask for a workspace name (lowercase, kebab-case, no spaces)
2. Ask where their repos are: "What directory contains your repos?"
3. **Always run a fresh scan** — never reuse results from previous conversations. Execute this command every time:
   ```bash
   find /path/to/dir -maxdepth 5 -name ".git" -type d 2>/dev/null | sort
   ```
4. List ALL found repos with numbers — **never truncate or summarize**. Show every single repo even if the list is long (50, 100+). The user needs the complete list to make their selection. Let user select which ones to include (e.g., "1,3,5", "1-10, 15, 20-25", "all", "all except 2,4")
5. After selection, ask: "Any other directories to scan?" — users often have repos in multiple locations
6. Save the repo list to `contexts/[name].repos` (format: `reponame|/full/path`)
7. Generate the .code-workspace file:

```json
{
  "folders": [
    { "name": "Command Center", "path": "~/.command-center" },
    { "name": "repo-name", "path": "/full/path/to/repo" }
  ],
  "settings": {
    "files.exclude": {
      "**/node_modules": true,
      "**/.git": true,
      "**/vendor": true
    }
  }
}
```

**Always include the Command Center folder first** — this gives users sidebar access to their task history, todos, docs, and configuration. The repo folders follow after it.

8. Save to `workspaces/[name].code-workspace`
9. Update `~/.command-center/session-state.json` with `"lastWorkspace": "[name]"` so the next window picks it up
10. Offer to open it: `cursor ~/.command-center/workspaces/[name].code-workspace`
11. Tell the user: "When the new window opens, just type `@lucius` or `@lu` — I'll know who you are and which workspace you're in."

## First Time in a New Workspace

When the user opens a newly created workspace for the first time (no task history exists for this workspace yet), welcome them and offer next steps:

```
Welcome to your new [workspace-name] workspace, [name]! You've got [N] repos loaded.

Here's what we can do next:

1. **Check git status** — see which repos are up to date, behind, or have changes
2. **Generate an architecture graph** — visualize how your services connect
3. **Start a task** — begin tracking work with optional Jira linking
4. **Add a todo** — set up your task list for this workspace
5. **Explore the code** — use @Codebase to search across all [N] repos at once

What sounds good?
```

## Adding Repos to a Workspace

1. **Read `.cursor/cc-context.json`** to get the current workspace name
2. If user says "add to this workspace" or "add to the current workspace", use that workspace — **don't ask**
3. If user specifies a different workspace, use that one
4. If unclear, ask which workspace to modify (list available from `contexts/*.repos`)
5. Clone or locate the repo (check if it already exists in `~/Projects/`)
6. Append to `contexts/[name].repos`
7. Regenerate the .code-workspace file by reading the current file and adding the new entry
8. Tell user to reload the window (`Cmd+Shift+P` → "Developer: Reload Window")

## Removing Repos

1. Read `contexts/[name].repos`
2. Show numbered list
3. User picks which to remove
4. Rewrite .repos file and regenerate workspace

## Opening a Workspace

```bash
cursor ~/.command-center/workspaces/[name].code-workspace
```

## Listing Workspaces

Read all `contexts/*.repos` files, count lines in each, display:
```
Available workspaces:
  backend (5 repos)
  frontend (3 repos)
  all (8 repos)
```
