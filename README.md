# 🚀 Cursor Command Center

> **Your AI-Powered Multi-Repo Development Hub**

A central hub for managing AI-assisted development across multiple repositories with Cursor.

<p align="center">
  <img src="https://img.shields.io/badge/Made%20for-Cursor-blue?style=for-the-badge" alt="Made for Cursor">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
</p>

<p align="center">

https://github.com/user-attachments/assets/5455e674-f622-4ffa-bec8-d25aa0d38b19

</p>

---

## ✨ What It Does

| Feature | Description |
|---------|-------------|
| 🤖 **@lu AI Assistant** | Full-featured AI assistant with todos, standups, personalization, task tracking |
| 🔍 **Super-fast @Codebase** | All your repos indexed together for instant AI search |
| 📁 **Project Groups** | Organize repos into contexts (Backend, Frontend, etc.) |
| 🔄 **Deep Scanning** | Finds nested repos (5 levels deep) |
| 📊 **Repo Status** | See git status across all repos at a glance |
| 📝 **Knowledge Base** | Task history + docs organized by workspace — auto-updated as you work |
| 🔗 **PR Auto-Linking** | PRs automatically linked to task files |
| 🗺️ **Dependency Graph** | Visualize service architecture (no tokens!) |
| 🚀 **Quick Re-open** | Jump back to your last workspace instantly |
| ✅ **Todo List** | Persistent todos with priorities, workspace tagging, ticket linking (`#PROJ-123`) |
| 📋 **Standups** | Cross-workspace daily/weekly summaries — always fresh, human-readable |
| 🎭 **Personalization** | Remembers your name, work schedule, greets you based on time of day |
| 📦 **Export/Import** | Backup and transfer your full setup (including todos + standups) |
| 📖 **Auto-Doc Updates** | Findings from investigations auto-saved to `docs/` with confidence levels |
| 🔀 **PR Merge Detection** | Detects merged PRs and offers to switch to main + pull |

---

## 💡 Why Command Center?

<p align="center">
  <img src="assets/overview.png" alt="Command Center Overview" width="800">
</p>

> **Real example:** A typical "find and fix across repos" task went from ~15 prompts to 3.

---

## 🎬 Quick Start

### 📋 Requirements

| Platform | Support |
|----------|---------|
| **macOS** | ✅ Full support |
| **Linux** | ✅ Full support |
| **Windows** | ⚠️ Requires [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) or [Git Bash](https://gitforwindows.org/) |

> **Note:** This project uses bash scripts. Windows users should run it inside WSL (recommended) or Git Bash.

### 1️⃣ Clone & Setup

```bash
# Clone the repo
git clone https://github.com/lionelresnik/cursor-command-center.git

# Run setup
cd cursor-command-center
./setup.sh
```

> **Note:** All @lu / @lucius AI assistant features are built-in (todos, standups, personalization, task tracking, PR linking, easter eggs).

### 2️⃣ The Setup Wizard

The wizard walks you through everything:

```
╔═══════════════════════════════════════════════════════════════╗
║  📁 Directory Browser                                         ║
╠═══════════════════════════════════════════════════════════════╣
║    ls        - List directories here                          ║
║    cd <dir>  - Go to directory                                ║
║    select    - ✓ Pick repos from this directory               ║
║    done      - ✓ Finish this project group                    ║
╚═══════════════════════════════════════════════════════════════╝

📍 /Users/you/Projects
browse> select

Found 5 repos in /Users/you/Projects:

  1) ✓ api-service
  2) ✓ web-frontend
  3) ✓ mobile-app
  4) ✓ shared-utils
  5) ✓ legacy-code

Commands: 1,3,5 (select) | all | none | except 1,2 | confirm | cancel

select> except 5          # Select all EXCEPT repo 5
select> confirm

📋 Final Selection (4 repos):
  ✓ api-service
  ✓ web-frontend
  ✓ mobile-app
  ✓ shared-utils

? Confirm and create project? [Y/n]: y
✓ Added 4 repos
```

> 💡 **Pro tips:**
> - Type just numbers: `5,10,15` to toggle specific repos
> - Use `except 5,10` to select all EXCEPT those
> - Scans 5 levels deep (finds nested repos like `company/projects/...`)
> - **Workspace names:** letters, numbers, hyphens, underscores only (no spaces)

### 3️⃣ Open Your Workspace

```bash
./open.sh
```

```
Select a project to open:

  1) all (all projects combined)
  2) none (command center only)
  3) backend (5 repos)
  4) frontend (3 repos)
  5) ➕ Add new project group...
  6) ❌ Cancel

? Enter number: 3

▶ Opening backend workspace...

┌─────────────────────────────────────────────────────────────────────────┐
│  💡 Tip: Use @Codebase in your prompts to search all repos at once!    │
│                                                                         │
│  Example: "@Codebase where is the auth logic?"                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

---

## 🔄 Upgrading & Syncing

Already have Command Center installed? Get the latest features without recreating workspaces:

```bash
cd cursor-command-center
git pull
./sync.sh
```

**What `sync.sh` does:**
- ✅ Cleans up stale duplicate directories from old installs
- ✅ Syncs assets (easter egg art, etc.)
- ✅ Initializes new data files (profile.json, session-state.json, standups/)
- ✅ Fixes workspace files (e.g., tilde path issues)
- ✅ Works for existing setups — no need to recreate workspaces

**Partial sync options:**
```bash
./sync.sh --plugin      # Developer only: sync from local plugin repo into CLI's .cursor/
./sync.sh --data        # Only initialize data files
./sync.sh --workspaces  # Only fix workspace files
```

---

## 📖 Daily Usage

### Quick Command Reference

| Command | Description |
|---------|-------------|
| `./cc open` | Open workspace menu |
| `./cc open --last` | Re-open last workspace |
| `./cc status` | Check git status across repos |
| `./cc graph` | Generate service dependency graph |
| `./cc add` | Add repos to a project |
| `./cc remove` | Remove repos from a project |
| `./cc rename <old> <new>` | Rename a workspace |
| `./cc todo` | Manage your persistent todo list |
| `./cc todo add <desc>` | Add a todo (with `-w workspace`, `-p priority`) |
| `./cc todo start [n]` | Move item to In Progress |
| `./cc todo done [n]` | Mark item as done |
| `./cc todo next` | Show what's next |
| `./cc standup` | Generate today's standup |
| `./cc standup weekly` | Generate weekly recap |
| `./cc standup view` | View most recent standup |
| `./cc export` | Backup configuration |
| `./cc import <file>` | Restore from backup |
| `./cc manage` | Rescan, regenerate workspaces |
| `./cc help` | Show all commands |

### Open a workspace

```bash
./open.sh              # Show menu
./open.sh backend      # Open 'backend' directly
./open.sh --last       # Re-open last workspace (fastest!)
```

### Check repo status

```bash
./status.sh            # All repos
./status.sh backend    # Just backend repos
```

```
📊 Repository Status

backend:

  ✓ api-service (main)
  ⚠ auth-service (main) - 3 uncommitted
  ⚠ db-migrations (main) - ↓ 2 behind

───────────────────────────────────────────────────────────────
Total: 3 repos checked
```

### Add repos to a workspace

```bash
./cc add               # Interactive: pick workspace, browse, select repos
```

```
Select a workspace to add repos to:
  1) backend (5 repos)
  2) frontend (3 repos)

? Enter number: 1

╔═══════════════════════════════════════════════════════════════╗
║  📁 Directory Browser                                        ║
╠═══════════════════════════════════════════════════════════════╣
║    ls        - List directories here                         ║
║    cd <dir>  - Enter a directory                             ║
║    select    - ✓ Pick repos from this dir                    ║
║    done      - ✓ Finish adding repos                         ║
╚═══════════════════════════════════════════════════════════════╝

📍 /Users/you/Projects
browse> select

Found 8 repos:
  1) ✓ api-service
  2) ✓ shared-utils
  3) auth-service              (already in backend)
  ...

select> confirm
✓ Added 2 repos to backend

  ✓ contexts/backend.repos (7 repos)
  ✓ workspaces/backend.code-workspace
  ✓ workspaces/all.code-workspace
```

You can also create new project groups via `./open.sh` → "➕ Add new project group..."

### Remove repos from a project

```bash
./cc remove            # Interactive repo removal
```

```
Select a project:
  1) backend
  2) frontend

? Enter number: 1

Repos in backend (5 total):

  1) ✓ api-service
  2) ✓ auth-service
  3) ✓ db-migrations
  4) ✗ old-monolith (will be removed)
  5) ✓ shared-utils

Commands: toggle 1,3,5 | save | cancel
remove> save
✓ Kept 4 repos, removed 1
```

### Rename a workspace

```bash
./cc rename mobile mobile-app    # Direct rename
./cc rename                      # Interactive (shows menu)
```

```
Available workspaces:
  1) mobile
  2) backend
  3) frontend

? Select workspace to rename (number): 1
? New name for 'mobile': mobile-app

  ✓ contexts/mobile.repos → mobile-app.repos
  ✓ contexts/mobile.dirs → mobile-app.dirs
  ✓ workspaces/mobile.code-workspace → mobile-app.code-workspace
  ✓ task-history/mobile/ → mobile-app/
  ✓ docs/mobile/ → mobile-app/

✓ Renamed 'mobile' → 'mobile-app'
```

### Generate dependency graph

```bash
./cc graph                    # Current workspace
./cc graph backend            # Specific workspace
./cc graph --open             # Generate and open in browser
```

Generates a visual service dependency graph by parsing:
- `*.tf` files - Terraform (auto-detects AWS/GCP/Azure)
- `docker-compose.yml` - Services, databases, Redis, RabbitMQ
- `serverless.yml` / `template.yaml` - Lambda, SQS, SNS, DynamoDB
- `go.mod` / `package.json` - Go and Node.js services

**Output:** `docs/[workspace]/architecture.html` (interactive) + `.md` (Mermaid)

**Example output:**
```
┌─────────────────────┐
│  🐳 Docker Services │
│  ┌───────────────┐  │
│  │  api-gateway  │  │
│  └───────┬───────┘  │
└──────────┼──────────┘
           │
   ┌───────┼───────┬──────────┐
   ▼       ▼       ▼          │
┌─────┐ ┌─────┐ ┌─────┐       │
│ AWS │ │ GCP │ │Azure│       │
│ 🏗️  │ │ 🏗️  │ │ 🏗️  │       │
└─────┘ └─────┘ └─────┘       │
```

> 💡 **Zero tokens!** Uses static file parsing, no AI calls.

---

## 🔗 PR Auto-Linking

When working on a task, PRs are automatically tracked:

1. **You ask the AI to create a PR** → URL captured and added to task file
2. **You mention a PR** (paste link or say "opened PR #123") → Added to task file

**Task file gets updated:**

```markdown
## 📦 Pull Requests

| Repo | PR | Description | Status |
|------|-----|-------------|--------|
| api-gateway | [#142](url) | Add retry logic | 🔄 Open |
| auth-service | [#87](url) | Update validation | ✅ Merged |
```

---

## 🤖 @Codebase vs Regular Chat

Understanding when to use `@Codebase` will save you time AND tokens (money!):

### When to Use `@Codebase` 🔍

| Use Case | Example Prompt |
|----------|----------------|
| **Find code location** | `@Codebase where is authentication implemented?` |
| **Understand patterns** | `@Codebase how do we handle errors across services?` |
| **Find all usages** | `@Codebase find all places that call UserService` |
| **Cross-repo search** | `@Codebase which repos import the shared utils?` |
| **Architecture questions** | `@Codebase how do the frontend and backend communicate?` |

### When to Skip `@Codebase` 💬

| Use Case | Why Skip |
|----------|----------|
| **Working in one file** | AI already sees your open file |
| **General questions** | `"What's a good naming convention?"` - no codebase needed |
| **After finding code** | Once you've located it, chat directly about that file |
| **Simple edits** | `"Add a try-catch here"` - context is already there |

### 💰 Token Savings Tip

```
❌ Expensive: "@Codebase add a new endpoint to the API"
   (Searches entire codebase unnecessarily)

✅ Cheaper: "@Codebase where are API endpoints defined?"
   Then: "Add a new endpoint here" (in the found file)
```

**Rule of thumb:** Use `@Codebase` to **find**, then regular chat to **modify**.

---

## 📁 Project Structure

```
cursor-command-center/
├── cc                # Main command wrapper (./cc open, ./cc status, etc.)
├── setup.sh          # First-time setup wizard
├── sync.sh           # Sync/upgrade existing installs
├── open.sh           # Workspace launcher
├── status.sh         # Git status checker
├── manage.sh         # Add/remove repos, export/import
├── graph.sh          # Service dependency graph generator
├── todo.sh           # Persistent todo manager
├── standup.sh        # Daily/weekly standup generator
├── help.sh           # Central help command
├── start.sh          # Quick start (opens 'all')
│
├── workspaces/       # Generated .code-workspace files
├── contexts/         # Project group definitions
│
├── task-history/     # Work logs (by workspace) — auto-created by @lu
│   ├── frontend/
│   ├── backend/
│   └── shared/
│
├── docs/             # Reference docs (by workspace) — auto-updated by @lu
│   ├── frontend/
│   ├── backend/
│   └── shared/
│
├── todos.md          # Persistent todo list (In Progress / Pending / Done)
├── standups/         # Daily and weekly standup summaries
├── assets/           # Static assets (easter egg art, etc.)
│
└── .cursor/
    ├── rules/        # Always-on AI rules (@lu, task tracking, standups, etc.)
    └── skills/       # @lu capabilities (workspace, graph, todos, standups, etc.)
```

---

## 📝 Knowledge Base (Task History + Docs)

Your local knowledge base is organized by workspace and **grows automatically as you work**:

```
task-history/                    # Work logs (what you did on specific tasks)
├── frontend/
│   └── PROJ-123-fix-auth.md
├── backend/
│   └── PROJ-456-add-api.md
└── shared/                      # Cross-workspace tasks
    └── general-refactor.md

docs/                            # Reference guides (general knowledge)
├── frontend/
│   └── api-integration.md
├── backend/
│   └── deployment-guide.md
└── shared/
    └── setup-guide.md
```

**All content is local-only** (gitignored) — safe for internal info.

| Type | Purpose | Example | Auto-created? |
|------|---------|---------|---------------|
| `task-history/` | Work logs, decisions | "What I did on ticket X" | ✅ Yes |
| `docs/` | Reference guides, findings | "How service Y works" | ✅ Yes |
| `todos.md` | Persistent todo list | "What's next" | ✅ Yes |
| `standups/` | Standup summaries | "What did I do this week" | ✅ Yes |

### Auto-Doc Updates

When `@lu` investigates something by reading source code, it automatically documents the finding in `docs/[workspace]/` — not in the task file. Findings are tagged with confidence levels:

- *(no tag)* — ✅ Confirmed — verified in source code or tested
- `> ⚠️ Assumed` — inferred, not yet verified
- `> 🔍 Investigating` — partially known, contradictory evidence

Assumed findings are automatically upgraded to confirmed when later verified.

**Backup:** `./cc export` includes your knowledge base, todos, and standups
**Reference:** `@task-history "What did we decide about auth?"`

---

## 💡 Tips

| Tip | Description |
|-----|-------------|
| **Smaller = Faster** | Use project-specific workspaces for faster @Codebase |
| **First open is slow** | Indexing takes a few minutes, then it's instant |
| **Install cursor CLI** | `Cmd+Shift+P` → "Install cursor command" |
| **Pretty UI** | Install [gum](https://github.com/charmbracelet/gum) for nicer menus |

---

## 🔌 Also Available: Cursor Plugin

For a marketplace plugin with the same features (and more) installed directly through Cursor, check out **Command Center**:

- [GitHub: cursor-command-center-plugin](https://github.com/lionelresnik/cursor-command-center-plugin)
<!-- - [Cursor Marketplace](marketplace-link-pending) -->

The plugin provides the same capabilities as this CLI, installed through the Cursor Marketplace with no git cloning required. If both are installed, prefer the plugin — it integrates deeper with Cursor's tooling.

**Migrating from CLI to plugin?** Once you install the plugin from the Marketplace, use `@lu migrate from CLI` and Lucius will guide you through removing CLI files while preserving all your data (`task-history/`, `docs/`, `todos.md`, `standups/`).

---

## 🤝 Sharing

This repo is designed to be shared:

| Share ✅ | Local Only ❌ |
|----------|---------------|
| Scripts (*.sh) | `config.json` |
| AI rules | `workspaces/` |
| README files | `contexts/*.repos` |
| | `task-history/**/*.md` |
| | `docs/**/*.md` |
| | `todos.md` |
| | `standups/` |

Each user runs `./setup.sh` to configure for their system.

**Transfer your setup:** `./cc export` → `./cc import`

### Export/Import Details

| Content | Included |
|---------|----------|
| Configuration | ✅ Always |
| Workspace definitions | ✅ Always |
| Todos | ✅ Always (if exists) |
| Standups | ✅ Always (if exists) |
| Task history | ✅ Optional (prompted) |
| Docs | ✅ Optional (prompted) |

**Moving to a new machine?** Import auto-detects different paths:

```
./cc import backup.tar.gz

⚠  Detected paths from a different machine:
   Old path: /Users/olduser/Projects

? Enter your projects directory: ~/code

Remapping paths:
  /Users/olduser/Projects → /Users/newuser/code

✓ Remapped 15 repo paths
```

---

## 👤 Author

**Lionel M. Resnik**

[![GitHub](https://img.shields.io/badge/GitHub-lionelresnik-181717?style=flat&logo=github)](https://github.com/lionelresnik)

---

## 📜 License

[MIT License](LICENSE) - Use it, share it, improve it!

---

<p align="center">
  <i>Made with ❤️ for developers who juggle many repos</i>
</p>
