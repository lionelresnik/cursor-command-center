---
name: export-import
description: Export and import Command Center configurations for backup or sharing. Bundles workspace definitions, repo lists, task history, and docs into a portable JSON file. Use when the user wants to back up, transfer, or restore their setup.
---

# Export / Import

## Export Configuration

When user asks to export or back up their setup:

1. Read all workspace definitions from `~/.command-center/contexts/*.repos`
2. Read `~/.command-center/profile.json` for name, preferences, and settings
3. Read `~/.command-center/todos.md` and `~/.command-center/todos-archive.md` if they exist
4. Read `~/.command-center/standups/` directory if it exists
5. Ask if they want to include knowledge base (task-history + docs + standups)
7. Bundle into a JSON file:

```json
{
  "version": "2.0",
  "exported": "2026-02-18T10:30:00Z",
  "profile": { "name": "...", "preferences": { "workWeek": "..." } },
  "workspaces": {
    "backend": {
      "repos": [
        { "name": "api-service", "path": "/Users/me/Projects/api-service" },
        { "name": "auth-service", "path": "/Users/me/Projects/auth-service" }
      ],
      "dirs": ["/Users/me/Projects"]
    }
  },
  "todos": "... (raw markdown content of todos.md) ...",
  "todos_archive": "... (raw markdown of todos-archive.md if exists) ...",
  "task_history": { ... },
  "docs": { ... },
  "standups": { ... }
}
```

8. Save to `command-center-export-[date].json`
9. Tell the user the file path

## Import Configuration

When user provides an export file or asks to import/restore:

1. Read and parse the JSON file
2. Check if paths exist on this machine
3. If paths don't exist (different machine), ask user for their projects directory and remap:
   - Detect old base path from repo paths
   - Ask: "Your repos are at a different path. Where are your projects?"
   - Replace old base path with new one in all repo paths
4. Write workspace definitions to `~/.command-center/contexts/*.repos`
5. Restore `~/.command-center/profile.json` (ask first: "Found a profile for [name] — restore it?")
6. Restore `~/.command-center/todos.md` (ask first: "Found [N] todos — restore them?")
7. Optionally restore task-history, docs, and standups to `~/.command-center/`
8. Regenerate .code-workspace files in `~/.command-center/workspaces/`
9. Confirm what was imported

## Path Remapping Example

```
Detected paths from export: /Users/olduser/Projects
These don't exist on this machine.

Where are your projects? ~/code

Remapping:
  /Users/olduser/Projects/api → /Users/newuser/code/api
  /Users/olduser/Projects/auth → /Users/newuser/code/auth

Remapped 12 repo paths.
```
