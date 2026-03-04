# Task History

> **TL;DR:** Your development journal organized by workspace. Use `task-history/<workspace>/` for workspace-specific tasks, `task-history/shared/` for cross-workspace work. Export/import via `./cc export` and `./cc import`.

---

## Structure

```
task-history/
├── frontend/               ← Frontend workspace tasks
│   ├── ABC-123-fix-auth.md
│   └── DEF-456-add-api.md
├── backend/                ← Backend workspace tasks
│   └── GHI-789-refactor.md
├── shared/                 ← Cross-workspace tasks
│   └── general-cleanup.md
└── README.md
```

---

## Which Folder?

| Scenario | Folder |
|----------|--------|
| Working in `<name>.code-workspace` | `task-history/<name>/` |
| Task spans multiple workspaces | `task-history/shared/` |
| General / not workspace-specific | `task-history/shared/` |

---

## Naming Convention

```
[TICKET]-description.md
```

**Examples:**
- `ABC-1234-add-user-auth.md` (with Jira ticket)
- `fix-login-bug.md` (no ticket)

---

## File Format

```yaml
---
date: 2026-02-09 14:30
workspace: <workspace-name>
ticket: ABC-1234
repos: [api-service, auth-service]
tags: [auth, security]
status: complete
type: task
---

# Task Title

Content...
```

---

## Using Past Context

| Method | Example |
|--------|---------|
| Reference in chat | `@task-history What did we do for auth?` |
| Find by ticket | Search for `ABC-1234` |
| Find by workspace | Browse `task-history/<workspace>/` |

---

## Export/Import

```bash
./cc export    # Choose specific workspace or all
./cc import    # Imports workspace folders
```

