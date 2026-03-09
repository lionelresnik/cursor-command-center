---
name: todo-manager
description: Manage a persistent todo list across workspaces and sessions. Add, complete, prioritize, and query todos. Stores in ~/.command-center/todos.md. Use when the user asks about tasks, what's next, what's done, or wants to track work items.
---

# Todo Manager

## Storage

All todos are stored in `~/.command-center/todos.md` as a markdown file with this format:

```markdown
# Todos

## In Progress
- [ ] **[workspace]** Task description `#priority-high` `#TICKET-123` `#user`
- [ ] **[workspace]** Another task `#priority-medium` `#lucius`

## Pending
- [ ] **[backend]** Implement retry logic for API calls `#priority-high` `#ABC-456` `#user`
- [ ] **[frontend]** Fix responsive layout on mobile `#priority-medium` `#lucius`
- [ ] **[shared]** Update deployment docs `#priority-low` `#user`

## Done
- [x] **[backend]** Add health check endpoint _(completed 2025-02-18)_ `#ABC-456` `#user`
- [x] **[platform]** Fix auth token refresh _(completed 2025-02-17)_ `#lucius`
```

### Ticket/Task Tagging

Todos can be optionally tagged with a ticket ID (e.g., `#PROJ-123`, `#ABC-1234`) to link them to specific tasks or Jira tickets. This allows filtering todos by ticket.

Format: `#TICKET-ID` (uppercase, placed before source tag)

## Todo Sources

Every todo is tagged with its origin:

- **`#user`** — The user explicitly asked to add it ("add this to my list", "remind me to", "don't forget")
- **`#lucius`** — Lucius detected it and suggested it (e.g., noticed a failing test, spotted a TODO comment, saw a PR needs follow-up, detected a repo is behind main)

When showing todos, always indicate the source so the user knows what they asked for vs what Lucius noticed.

## Auto-Completion

Lucius must actively track and auto-complete `#lucius` todos when the underlying issue is resolved:
- PR was merged → mark the related todo done
- Test was fixed → mark the related todo done
- Repo was pulled/synced → mark "repo behind" todo done
- Task file was completed → mark related todo done

For `#user` todos, always **ask** before marking done: "Looks like [task] might be done — should I mark it complete?"

## Operations

### Add a todo
When the user says "add todo", "remind me to", "I need to", "don't forget":
1. Detect the workspace using these methods (in order):
   - Check `.cursor/cc-context.json` for `"workspace"` field
   - Check the open `.code-workspace` filename (e.g., `platform.code-workspace` → workspace is `platform`)
   - Ask the user
   - **Never default to "shared"** unless the user explicitly says the todo spans multiple workspaces
2. Detect ticket ID from context:
   - Check if user is working on a task file (e.g., `task-history/backend/PROJ-123-auth-retry-fix.md`)
   - Check task file frontmatter for `ticket:` field
   - Check if user mentions a ticket in the todo request
   - If found, add `#TICKET-ID` tag
   - If no ticket, skip this tag
3. Ask priority if not obvious (high/medium/low, default: medium)
4. Tag as `#user`
5. Add to the Pending section of `~/.command-center/todos.md`
6. Confirm: "Added to your list: [task] ([workspace], priority: [level], ticket: [TICKET-ID])"

### Lucius-initiated todo
When Lucius detects something that needs attention:
1. Tag as `#lucius`
2. Add to Pending with appropriate priority
3. Tell the user: "I added a todo: [task] — I noticed [reason]"

### Complete a todo
When the user says "done with", "finished", "completed", "mark as done":
1. Move from In Progress/Pending to Done section
2. Add completion date
3. Confirm: "Marked as done: [task]"

### Start working on a todo
When the user says "working on", "starting", "picking up":
1. Move from Pending to In Progress
2. Confirm: "Moved to in progress: [task]"

### Query todos
- **"What's next?"** → Show highest priority pending item
- **"What am I working on?"** → Show In Progress items
- **"What's done?"** → Show recent Done items
- **"What's left?"** / **"What still needs to be done?"** → Show Pending + In Progress counts and list
- **"Have I forgotten something?"** → Show all pending items, highlight any older than 7 days
- **"Show all todos"** → Full list grouped by status
- **"Show todos for [workspace]"** → Filter by workspace
- **"What's left for [TICKET-ID]?"** / **"Show todos for [TICKET-ID]"** → Filter by ticket ID
- **"What tickets do I have todos for?"** → List all unique ticket IDs with todo counts

### Display format (chat)

When displaying todos in chat (e.g., "what's next?", "what's left?", "show all todos"), use this Confluence-like format. Do **not** change the storage format in `todos.md` — only how todos are presented in the response:

```markdown
## Your Todos

### 🔄 In Progress
- **[workspace]** Task description `⚡ high` `#TICKET-123` `#user`

### 📌 Pending
- **[workspace]** Task description `⚡ high` `#ABC-456` `#user`
- **[workspace]** Task description `#lucius`

### ✅ Recently Done
- ~~Task description~~ _(completed Feb 26)_ `#TICKET-123` `#user`
```

When filtering by ticket (e.g., "what's left for PROJ-123?"), show:
```markdown
## Todos for PROJ-123

### 🔄 In Progress (2)
- **[backend]** Fix auth retry logic `⚡ high` `#user`
- **[backend]** Update API docs `#lucius`

### 📌 Pending (1)
- **[backend]** Test in staging environment `⚡ medium` `#user`

### ✅ Done (3)
- ~~Investigate root cause~~ _(completed Feb 22)_ `#user`
```

### Prioritize
- **"This is urgent"** → Set priority-high
- **"Reprioritize"** → Show all pending, ask user to reorder

### Clean up
- **"Clean up done items"** → Archive Done items older than 30 days to `~/.command-center/todos-archive.md`

## Cross-Workspace View

Todos span all workspaces. Each todo is tagged with its workspace name in bold brackets. When showing todos, group by workspace if the user asks, or show flat list sorted by priority by default.

## Integration with Task Tracking

When a task file is created in `task-history/`, suggest adding a corresponding todo if one doesn't exist. Automatically tag the todo with the ticket ID from the task file's frontmatter.

When a todo is completed, check if there's a related task file to update. If the task file's status is `in-progress` and all todos for that ticket are done, suggest updating the task file status to `complete`.

When filtering todos by ticket (e.g., "what's left for PROJ-123?"), also show a link to the task file if it exists:
```
📄 Task file: task-history/backend/PROJ-123-auth-retry-fix.md
```

## Proactive Behavior

- At session start (after greeting), if there are in-progress items, mention them briefly
- If a todo has been pending for more than 7 days, gently remind the user
- When the user finishes a PR or task, ask if the related todo should be marked done
