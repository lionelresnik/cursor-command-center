# 🔄 Sync & Upgrade Guide

## For Existing Users

Already have Command Center installed? Get all the new features without recreating your workspaces!

### Quick Upgrade

```bash
cd cursor-command-center
git pull
./sync.sh
```

That's it! Your workspaces stay intact, and you get:

- ✅ **@lu / @lucius** — Full AI assistant with plugin capabilities
- ✅ **Enhanced Todos** — Priorities, workspace tags, source tracking (`#user` / `#lucius`)
- ✅ **Smart Standups** — Daily/weekly with work week awareness (Mon-Fri or Sun-Thu)
- ✅ **Personalization** — Remembers your name, work schedule, greets you by time of day
- ✅ **Daily Recap** — Session recaps after idle, standup prompts at start of day/week
- ✅ **Task Tracking** — Auto-creates task files with Jira integration
- ✅ **PR Linking** — Auto-captures PR URLs from git commands
- ✅ **Easter Egg** — Say "batman" to @lu 🦇

---

## What `sync.sh` Does

### 1. Syncs Plugin Components

Copies the latest hooks, rules, skills, and agents from the plugin repo into `~/.command-center/.cursor/`:

- **Rules** — task-tracking, PR linking, personalization, daily recap, easter egg
- **Skills** — workspace-manager, todo-manager, standup-generator, graph-generator, repo-status, export-import
- **Agents** — @lu and @lucius
- **Hooks** — session-start, session-end, after-shell-execution
- **Assets** — easter egg art

### 2. Initializes Data Files

Creates new data files if they don't exist:

- `profile.json` — Your name, work week preference
- `session-state.json` — Last workspace, session timestamps
- `todos.md` — Persistent todo list
- `standups/` — Daily and weekly standup summaries

### 3. Fixes Workspace Files

Automatically fixes known issues in existing `.code-workspace` files:

- Replaces `~/.command-center` with absolute path (fixes terminal launch errors)

---

## Partial Sync Options

Run only specific parts of the sync:

```bash
./sync.sh --plugin      # Only sync plugin components
./sync.sh --data        # Only initialize data files
./sync.sh --workspaces  # Only fix workspace files
```

---

## For New Users

If you're setting up Command Center for the first time:

```bash
# Clone both repos
git clone https://github.com/lionelresnik/cursor-command-center.git
git clone https://github.com/lionelresnik/cursor-command-center-plugin.git

# Run setup (automatically calls sync.sh)
cd cursor-command-center
./setup.sh
```

The setup wizard will:
1. Sync plugin components
2. Guide you through creating workspaces
3. Initialize all data files

---

## Troubleshooting

### Plugin repo not found

If you see:

```
⚠  Plugin repo not found at ../cursor-command-center-plugin
ℹ  Skipping plugin sync
```

**Solution:** Clone the plugin repo next to the CLI repo:

```bash
cd ~/Projects  # or wherever you cloned cursor-command-center
git clone https://github.com/lionelresnik/cursor-command-center-plugin.git
cd cursor-command-center
./sync.sh
```

### @lu doesn't respond with full capabilities

**Possible causes:**
1. Plugin components not synced (run `./sync.sh`)
2. Workspace doesn't include the Command Center folder
3. Cursor window needs reload (Cmd+Shift+P → "Developer: Reload Window")

**Solution:**
```bash
./sync.sh
# Then reload Cursor window and try @lu again
```

### Workspace terminal fails to launch

**Error:** `Starting directory (cwd) "...workspaces/~/.command-center" does not exist`

**Solution:**
```bash
./sync.sh --workspaces
# This fixes the tilde path issue in workspace files
```

---

## What Gets Updated

### Always Safe to Run

`sync.sh` is **non-destructive**:
- ✅ Overwrites plugin components (rules, skills, agents, hooks) with latest versions
- ✅ Creates missing data files (never overwrites existing ones)
- ✅ Fixes workspace files (only corrects known issues)
- ❌ Never deletes your todos, task history, docs, or standups
- ❌ Never removes workspaces or contexts

### Run Anytime

You can run `./sync.sh` as often as you like:
- After `git pull` to get new features
- After manually editing plugin components (to restore originals)
- When troubleshooting issues
- To verify everything is up to date

---

## Future-Proof

As new features are added to Command Center, `sync.sh` will automatically:
- Install new plugin components
- Create new data files
- Fix new workspace issues
- Keep your setup current

**No need to recreate workspaces** — just `git pull && ./sync.sh` and you're up to date!
