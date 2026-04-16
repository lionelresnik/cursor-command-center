#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              Cursor Command Center Sync & Upgrade                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# Syncs plugin components, migrates data to ~/.command-center/, and cleans up
# the CLI repo so all user data lives exclusively in ~/.command-center/.
#
# Usage:
#   ./sync.sh              # Full sync (migrate + assets + data + workspaces + cleanup)
#   ./sync.sh --plugin     # Developer only: sync from local plugin repo into CLI's .cursor/
#   ./sync.sh --data       # Only initialize data files in ~/.command-center/
#   ./sync.sh --workspaces # Only fix workspace files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/../cursor-command-center-plugin"
CURSOR_DIR="$SCRIPT_DIR/.cursor"
ASSETS_DIR="$SCRIPT_DIR/assets"
DATA_DIR="$HOME/.command-center"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${MAGENTA}🔄 Command Center Sync & Upgrade${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}✗${NC}  $1"
}

migrate_data() {
    print_step "Migrating Data to ~/.command-center/"

    mkdir -p "$DATA_DIR/task-history" "$DATA_DIR/docs" "$DATA_DIR/contexts" \
             "$DATA_DIR/standups" "$DATA_DIR/workspaces" "$DATA_DIR/daily-log"

    local migrated=0
    local migrate_tmp
    migrate_tmp=$(mktemp)
    echo "0" > "$migrate_tmp"

    migrate_tree() {
        local src_base="$1"
        local dest_base="$2"
        local label="$3"

        [ -d "$src_base" ] || return 0

        while IFS= read -r src_file; do
            local rel_path="${src_file#$src_base/}"

            [ "$rel_path" = ".gitkeep" ] && continue
            [ "$rel_path" = ".DS_Store" ] && continue

            local dest_file="$dest_base/$rel_path"
            mkdir -p "$(dirname "$dest_file")"

            if [ ! -f "$dest_file" ]; then
                cp "$src_file" "$dest_file"
                echo -e "  ${GREEN}+${NC} $label/$rel_path ${DIM}(migrated)${NC}"
                echo $(( $(cat "$migrate_tmp") + 1 )) > "$migrate_tmp"
            elif ! cmp -s "$src_file" "$dest_file"; then
                local src_mod dest_mod
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    src_mod=$(stat -f %m "$src_file" 2>/dev/null || echo 0)
                    dest_mod=$(stat -f %m "$dest_file" 2>/dev/null || echo 0)
                else
                    src_mod=$(stat -c %Y "$src_file" 2>/dev/null || echo 0)
                    dest_mod=$(stat -c %Y "$dest_file" 2>/dev/null || echo 0)
                fi
                if [ "$src_mod" -gt "$dest_mod" ]; then
                    cp "$src_file" "$dest_file"
                    echo -e "  ${YELLOW}↻${NC} $label/$rel_path ${DIM}(newer in CLI repo, updated)${NC}"
                    echo $(( $(cat "$migrate_tmp") + 1 )) > "$migrate_tmp"
                else
                    echo -e "  ${DIM}  $label/$rel_path (kept ~/.command-center/ version)${NC}"
                fi
            fi
        done < <(find "$src_base" -type f \( -name "*.md" -o -name "*.repos" -o -name "*.dirs" -o -name "*.code-workspace" -o -name "*.json" -o -name "*.selection" \))
    }

    migrate_tree "$SCRIPT_DIR/task-history" "$DATA_DIR/task-history" "task-history"
    migrate_tree "$SCRIPT_DIR/docs" "$DATA_DIR/docs" "docs"
    migrate_tree "$SCRIPT_DIR/contexts" "$DATA_DIR/contexts" "contexts"
    migrate_tree "$SCRIPT_DIR/standups" "$DATA_DIR/standups" "standups"
    migrate_tree "$SCRIPT_DIR/workspaces" "$DATA_DIR/workspaces" "workspaces"

    for rootfile in config.json profile.json session-state.json todos.md; do
        if [ -f "$SCRIPT_DIR/$rootfile" ] && [ ! -f "$DATA_DIR/$rootfile" ]; then
            local content_check
            content_check=$(grep -v '^\s*$' "$SCRIPT_DIR/$rootfile" 2>/dev/null | grep -v '""' | wc -l)
            if [ "$content_check" -gt 2 ]; then
                cp "$SCRIPT_DIR/$rootfile" "$DATA_DIR/$rootfile"
                echo -e "  ${GREEN}+${NC} $rootfile ${DIM}(migrated)${NC}"
                echo $(( $(cat "$migrate_tmp") + 1 )) > "$migrate_tmp"
            fi
        fi
    done

    migrated=$(cat "$migrate_tmp")
    rm -f "$migrate_tmp"

    if [ "$migrated" -eq 0 ]; then
        print_info "No data to migrate (already in ~/.command-center/)"
    else
        print_success "Migrated $migrated file(s) to ~/.command-center/"
    fi
}

cleanup_stale() {
    print_step "Cleaning Up Stale Files"

    local cleaned=0

    if [ -d "$DATA_DIR/workspaces/.cursor" ]; then
        rm -rf "$DATA_DIR/workspaces/.cursor"
        print_success "Removed stale ~/.command-center/workspaces/.cursor/"
        cleaned=$((cleaned + 1))
    fi

    if [ -f "$DATA_DIR/easter-egg-art.md" ]; then
        rm -f "$DATA_DIR/easter-egg-art.md"
        print_success "Removed stale ~/.command-center/easter-egg-art.md (lives in assets/)"
        cleaned=$((cleaned + 1))
    fi

    if [ $cleaned -eq 0 ]; then
        print_info "No stale files found"
    fi
}

sync_cursor_dir() {
    print_step "Syncing .cursor/ (rules, skills, agents, hooks)"

    local SRC="$CURSOR_DIR"
    local DEST="$DATA_DIR/.cursor"

    if [ ! -d "$SRC" ]; then
        print_warning "No .cursor/ directory found in CLI repo"
        return 0
    fi

    local added_count=0
    local updated_count=0
    local unchanged_count=0

    while IFS= read -r src_file; do
        local rel_path="${src_file#$SRC/}"
        local dest_file="$DEST/$rel_path"

        mkdir -p "$(dirname "$dest_file")"

        if [ ! -f "$dest_file" ]; then
            cp "$src_file" "$dest_file"
            echo -e "  ${GREEN}+${NC} .cursor/$rel_path ${DIM}(new)${NC}"
            added_count=$((added_count + 1))
        elif ! cmp -s "$src_file" "$dest_file"; then
            cp "$src_file" "$dest_file"
            echo -e "  ${YELLOW}↻${NC} .cursor/$rel_path ${DIM}(updated)${NC}"
            updated_count=$((updated_count + 1))
        else
            unchanged_count=$((unchanged_count + 1))
        fi
    done < <(find "$SRC" -type f -not -name '.DS_Store')

    echo ""
    if [ $added_count -gt 0 ] || [ $updated_count -gt 0 ]; then
        print_success ".cursor/ synced: $added_count added, $updated_count updated, $unchanged_count unchanged"
    else
        print_success "All rules/skills/agents up to date ($unchanged_count files)"
    fi
}

install_global_plugin() {
    print_step "Installing Global Plugin (for Home chats)"

    local PLUGIN_LOCAL="$HOME/.cursor/plugins/local"
    local PLUGIN_DEST="$PLUGIN_LOCAL/command-center"

    mkdir -p "$PLUGIN_LOCAL"

    # Create plugin structure from CLI's .cursor/
    mkdir -p "$PLUGIN_DEST/.cursor-plugin"
    mkdir -p "$PLUGIN_DEST/rules"
    mkdir -p "$PLUGIN_DEST/skills"
    mkdir -p "$PLUGIN_DEST/agents"
    mkdir -p "$PLUGIN_DEST/hooks"

    # Create plugin manifest
    cat > "$PLUGIN_DEST/.cursor-plugin/plugin.json" << 'MANIFEST'
{
  "name": "command-center",
  "version": "0.1.0",
  "description": "Multi-repo workspace management with task tracking, standups, and personalization."
}
MANIFEST

    # Copy rules, skills, agents, hooks from CLI's .cursor/
    local count=0
    for dir in rules skills agents hooks; do
        if [ -d "$CURSOR_DIR/$dir" ]; then
            cp -R "$CURSOR_DIR/$dir"/* "$PLUGIN_DEST/$dir/" 2>/dev/null && count=$((count + 1))
        fi
    done

    print_success "Global plugin installed at ~/.cursor/plugins/local/command-center/"
    print_info "This enables Command Center in Agents Window 'Home' chats"
}

check_first_run() {
    # Check if this is a first run (no workspaces exist yet)
    local ws_count=0
    for ws_file in "$DATA_DIR/workspaces"/*.code-workspace; do
        [ -f "$ws_file" ] || continue
        ws_count=$((ws_count + 1))
    done

    if [ $ws_count -gt 0 ]; then
        return 0
    fi

    # First run - check if user has existing workspaces elsewhere
    print_step "First Run Detected"
    
    local found_workspaces=()
    local search_dirs=("$HOME/Projects" "$HOME/Workspaces" "$HOME/Code" "$HOME/Developer")
    
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' file; do
                [[ "$file" == *"/.command-center/"* ]] && continue
                found_workspaces+=("$file")
            done < <(find "$dir" -maxdepth 3 -name "*.code-workspace" -print0 2>/dev/null)
        fi
    done

    if [ ${#found_workspaces[@]} -eq 0 ]; then
        print_info "No existing workspace files found"
        print_info "Create your first workspace with: ${BOLD}cc setup${NC}"
        return 0
    fi

    echo ""
    echo -e "Found ${BOLD}${#found_workspaces[@]}${NC} existing workspace file(s) on your system."
    echo ""
    echo -en "${YELLOW}?${NC} Would you like to import them into Command Center? [Y/n]: "
    read -r import_choice

    if [[ "$import_choice" =~ ^[Nn] ]]; then
        print_info "Skipped. You can import later with: cc import-workspace --scan"
        return 0
    fi

    # Run the import script
    "$SCRIPT_DIR/import-workspace.sh" --scan
}

sync_assets() {
    print_step "Syncing Assets"

    local DEST_ASSETS="$DATA_DIR/assets"
    mkdir -p "$DEST_ASSETS"

    local added_count=0
    local updated_count=0
    local unchanged_count=0

    for src_file in "$ASSETS_DIR"/*; do
        [ -f "$src_file" ] || continue
        local filename
        filename=$(basename "$src_file")
        local dest_file="$DEST_ASSETS/$filename"

        if [ ! -f "$dest_file" ]; then
            cp "$src_file" "$dest_file"
            echo -e "  ${GREEN}+${NC} $filename ${DIM}(new)${NC}"
            added_count=$((added_count + 1))
        elif ! cmp -s "$src_file" "$dest_file"; then
            cp "$src_file" "$dest_file"
            echo -e "  ${YELLOW}↻${NC} $filename ${DIM}(modified)${NC}"
            updated_count=$((updated_count + 1))
        else
            unchanged_count=$((unchanged_count + 1))
        fi
    done

    echo ""
    if [ $added_count -gt 0 ] || [ $updated_count -gt 0 ]; then
        print_success "Assets synced: $added_count added, $updated_count updated, $unchanged_count unchanged"
    else
        print_success "All assets up to date ($unchanged_count files)"
    fi
}

sync_from_plugin() {
    print_step "Syncing from Plugin Repo (developer mode)"

    if [ ! -d "$PLUGIN_DIR" ]; then
        print_error "Plugin repo not found at $PLUGIN_DIR"
        print_info "Clone cursor-command-center-plugin next to this repo to use --plugin"
        return 1
    fi

    print_info "Found plugin at: $PLUGIN_DIR"

    local DEST_DIR="$CURSOR_DIR"
    local added_count=0
    local updated_count=0
    local unchanged_count=0

    sync_files() {
        local src_dir="$1"
        local dest_dir="$2"
        local pattern="$3"

        for src_file in "$src_dir"/$pattern; do
            [ -e "$src_file" ] || continue
            local filename
            filename=$(basename "$src_file")
            local dest_file="$dest_dir/$filename"

            if [ ! -f "$dest_file" ]; then
                cp -r "$src_file" "$dest_file"
                echo -e "  ${GREEN}+${NC} $filename ${DIM}(new)${NC}"
                added_count=$((added_count + 1))
            elif ! cmp -s "$src_file" "$dest_file"; then
                cp -r "$src_file" "$dest_file"
                echo -e "  ${YELLOW}↻${NC} $filename ${DIM}(modified)${NC}"
                updated_count=$((updated_count + 1))
            else
                unchanged_count=$((unchanged_count + 1))
            fi
        done
    }

    mkdir -p "$DEST_DIR/rules" "$DEST_DIR/skills" "$DEST_DIR/agents" "$DEST_DIR/hooks" "$DEST_DIR/scripts"

    [ -d "$PLUGIN_DIR/rules" ]   && sync_files "$PLUGIN_DIR/rules"   "$DEST_DIR/rules"   "*.mdc"
    [ -d "$PLUGIN_DIR/agents" ]  && sync_files "$PLUGIN_DIR/agents"  "$DEST_DIR/agents"  "*.md"
    [ -d "$PLUGIN_DIR/hooks" ]   && sync_files "$PLUGIN_DIR/hooks"   "$DEST_DIR/hooks"   "*"
    [ -d "$PLUGIN_DIR/scripts" ] && sync_files "$PLUGIN_DIR/scripts" "$DEST_DIR/scripts" "*.sh"
    [ -d "$PLUGIN_DIR/assets" ]  && sync_files "$PLUGIN_DIR/assets"  "$ASSETS_DIR"       "*"

    if [ -d "$PLUGIN_DIR/skills" ]; then
        for skill_dir in "$PLUGIN_DIR/skills"/*; do
            [ -d "$skill_dir" ] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")
            mkdir -p "$DEST_DIR/skills/$skill_name"
            for skill_file in "$skill_dir"/*; do
                [ -f "$skill_file" ] || continue
                local filename
                filename=$(basename "$skill_file")
                local dest_file="$DEST_DIR/skills/$skill_name/$filename"
                if [ ! -f "$dest_file" ]; then
                    cp "$skill_file" "$dest_file"
                    echo -e "  ${GREEN}+${NC} skills/$skill_name/$filename ${DIM}(new)${NC}"
                    added_count=$((added_count + 1))
                elif ! cmp -s "$skill_file" "$dest_file"; then
                    cp "$skill_file" "$dest_file"
                    echo -e "  ${YELLOW}↻${NC} skills/$skill_name/$filename ${DIM}(modified)${NC}"
                    updated_count=$((updated_count + 1))
                else
                    unchanged_count=$((unchanged_count + 1))
                fi
            done
        done
    fi

    if [ -f "$DEST_DIR/rules/easter-egg.mdc" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's|assets/easter-egg-art.md|~/.command-center/assets/easter-egg-art.md|g' "$DEST_DIR/rules/easter-egg.mdc" 2>/dev/null || true
        else
            sed -i 's|assets/easter-egg-art.md|~/.command-center/assets/easter-egg-art.md|g' "$DEST_DIR/rules/easter-egg.mdc" 2>/dev/null || true
        fi
    fi

    echo ""
    if [ $added_count -gt 0 ] || [ $updated_count -gt 0 ]; then
        print_success "Plugin sync complete: $added_count added, $updated_count updated, $unchanged_count unchanged"
        print_info "Run ./sync.sh (no flags) to push assets to ~/.command-center"
    else
        print_success "All plugin files already up to date ($unchanged_count files)"
    fi
}

init_data_files() {
    print_step "Initializing Data Files"

    mkdir -p "$DATA_DIR/standups" "$DATA_DIR/task-history" "$DATA_DIR/docs" \
             "$DATA_DIR/contexts" "$DATA_DIR/workspaces" "$DATA_DIR/assets" "$DATA_DIR/daily-log"

    if [ ! -f "$DATA_DIR/profile.json" ]; then
        cat > "$DATA_DIR/profile.json" << 'TMPL'
{
  "name": "",
  "createdAt": "",
  "preferences": {
    "workWeek": "mon-fri"
  }
}
TMPL
        print_success "Created profile.json (personalization: name, work week)"
    else
        print_info "profile.json already exists"
    fi

    if [ ! -f "$DATA_DIR/session-state.json" ]; then
        cat > "$DATA_DIR/session-state.json" << 'TMPL'
{
  "lastWorkspace": "",
  "lastSessionEnd": ""
}
TMPL
        print_success "Created session-state.json (session tracking)"
    else
        print_info "session-state.json already exists"
    fi

    if [ ! -f "$DATA_DIR/todos.md" ]; then
        cat > "$DATA_DIR/todos.md" << 'TMPL'
# Todos

## In Progress

## Pending

## Done
TMPL
        print_success "Created todos.md (persistent todo list)"
    else
        print_info "todos.md already exists"
    fi

    print_success "Data files initialized in ~/.command-center/"
}

fix_workspace_files() {
    print_step "Fixing Workspace Files"

    local fixed=0
    local total=0
    local OLD_PROJECTS_DIR
    OLD_PROJECTS_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"

    fix_ws_dir() {
        local ws_dir="$1"
        [ -d "$ws_dir" ] || return 0

        for ws_file in "$ws_dir"/*.code-workspace; do
            [ -e "$ws_file" ] || continue
            total=$((total + 1))
            local needs_fix=0

            if grep -q '"path": "\.\.' "$ws_file" 2>/dev/null; then
                needs_fix=1
            fi
            if grep -q "\"path\": \"$SCRIPT_DIR\"" "$ws_file" 2>/dev/null; then
                needs_fix=1
            fi
            if grep -q '"path": "~/\.command-center"' "$ws_file" 2>/dev/null; then
                needs_fix=1
            fi

            if [ $needs_fix -eq 1 ]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' 's|"path": "\.\."|"path": "'"$DATA_DIR"'"|g' "$ws_file"
                    sed -i '' 's|"path": "'"$SCRIPT_DIR"'"|"path": "'"$DATA_DIR"'"|g' "$ws_file"
                    sed -i '' 's|"path": "~/\.command-center"|"path": "'"$DATA_DIR"'"|g' "$ws_file"
                    sed -i '' 's|"path": "\.\./\.\./|"path": "'"$OLD_PROJECTS_DIR"'/|g' "$ws_file"
                else
                    sed -i 's|"path": "\.\."|"path": "'"$DATA_DIR"'"|g' "$ws_file"
                    sed -i 's|"path": "'"$SCRIPT_DIR"'"|"path": "'"$DATA_DIR"'"|g' "$ws_file"
                    sed -i 's|"path": "~/\.command-center"|"path": "'"$DATA_DIR"'"|g' "$ws_file"
                    sed -i 's|"path": "\.\./\.\./|"path": "'"$OLD_PROJECTS_DIR"'/|g' "$ws_file"
                fi
                fixed=$((fixed + 1))
                print_success "Fixed $(basename "$ws_file")"
            fi
        done
    }

    fix_ws_dir "$DATA_DIR/workspaces"
    fix_ws_dir "$SCRIPT_DIR/workspaces"

    if [ $fixed -eq 0 ]; then
        print_info "All workspace files up to date ($total checked)"
    else
        print_success "Fixed $fixed workspace file(s) to point to ~/.command-center/"
    fi
}

cleanup_cli_data() {
    print_step "Cleaning Up CLI Repo Data (moved to ~/.command-center/)"

    local cleaned=0

    remove_if_exists() {
        local target="$1"
        local label="$2"
        if [ -e "$target" ]; then
            rm -rf "$target"
            print_success "Removed $label"
            cleaned=$((cleaned + 1))
        fi
    }

    for dir in task-history docs standups; do
        if [ -d "$SCRIPT_DIR/$dir" ]; then
            local has_files
            has_files=$(find "$SCRIPT_DIR/$dir" -type f -not -name '.gitkeep' -not -name '.DS_Store' 2>/dev/null | head -1)
            if [ -n "$has_files" ]; then
                print_warning "$dir/ still has files — verifying migration before removing"
                local safe_to_remove=1
                while IFS= read -r f; do
                    local rel="${f#$SCRIPT_DIR/$dir/}"
                    if [ ! -f "$DATA_DIR/$dir/$rel" ]; then
                        print_error "  MISSING in ~/.command-center/$dir/$rel — skipping cleanup of $dir/"
                        safe_to_remove=0
                        break
                    fi
                done < <(find "$SCRIPT_DIR/$dir" -type f \( -name "*.md" -o -name "*.json" \) -not -name '.gitkeep')
                if [ $safe_to_remove -eq 1 ]; then
                    rm -rf "$SCRIPT_DIR/$dir"
                    print_success "Removed $dir/ from CLI repo"
                    cleaned=$((cleaned + 1))
                fi
            else
                rm -rf "$SCRIPT_DIR/$dir"
                print_success "Removed empty $dir/ from CLI repo"
                cleaned=$((cleaned + 1))
            fi
        fi
    done

    if [ -d "$SCRIPT_DIR/contexts" ]; then
        find "$SCRIPT_DIR/contexts" -type f \( -name "*.repos" -o -name "*.dirs" -o -name "*.selection" \) -exec rm -f {} \;
        rm -f "$SCRIPT_DIR/contexts/.gitkeep"
        if [ -z "$(ls -A "$SCRIPT_DIR/contexts" 2>/dev/null)" ]; then
            rmdir "$SCRIPT_DIR/contexts"
        fi
        print_success "Cleaned contexts/ in CLI repo"
        cleaned=$((cleaned + 1))
    fi

    if [ -d "$SCRIPT_DIR/workspaces" ]; then
        find "$SCRIPT_DIR/workspaces" -name "*.code-workspace" -exec rm -f {} \;
        rm -f "$SCRIPT_DIR/workspaces/.gitkeep"
        if [ -z "$(ls -A "$SCRIPT_DIR/workspaces" 2>/dev/null)" ]; then
            rmdir "$SCRIPT_DIR/workspaces"
        fi
        print_success "Cleaned workspaces/ in CLI repo"
        cleaned=$((cleaned + 1))
    fi

    for f in profile.json session-state.json todos.md config.json .last-workspace .last-browse-dir; do
        remove_if_exists "$SCRIPT_DIR/$f" "$f from CLI repo"
    done

    for f in "$SCRIPT_DIR"/*.code-workspace; do
        [ -e "$f" ] || continue
        remove_if_exists "$f" "$(basename "$f") from CLI repo root"
    done

    if [ $cleaned -eq 0 ]; then
        print_info "CLI repo already clean"
    else
        print_success "Cleaned $cleaned item(s) from CLI repo"
    fi
}

reopen_workspaces() {
    print_step "Reopening Workspaces"

    local ws_count=0
    for ws_file in "$DATA_DIR/workspaces"/*.code-workspace; do
        [ -f "$ws_file" ] || continue
        ws_count=$((ws_count + 1))
    done

    if [ $ws_count -eq 0 ]; then
        print_info "No workspace files found to open"
        return 0
    fi

    print_info "Your workspaces moved to ~/.command-center/workspaces/ (hidden folder)."
    print_info "Opening all $ws_count workspace(s) in Cursor now..."
    echo ""

    for ws_file in "$DATA_DIR/workspaces"/*.code-workspace; do
        [ -f "$ws_file" ] || continue
        local ws_name
        ws_name=$(basename "$ws_file" .code-workspace)
        open "$ws_file" 2>/dev/null || cursor "$ws_file" 2>/dev/null || true
        echo -e "  ${GREEN}●${NC} Opened ${BOLD}$ws_name${NC}"
    done

    echo ""
}

show_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                    ${BOLD}✓ Sync Complete!${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Data Location:${NC} ~/.command-center/"
    echo ""
    echo -e "${BOLD}What's Included:${NC}"
    echo ""
    echo -e "  ${GREEN}●${NC} ${BOLD}@lu / @lucius${NC} — AI assistant with full plugin capabilities"
    echo -e "  ${GREEN}●${NC} ${BOLD}Todo List${NC} — Persistent todos with priorities & workspace tags"
    echo -e "  ${GREEN}●${NC} ${BOLD}Standups${NC} — Daily/weekly summaries from todos & task history"
    echo -e "  ${GREEN}●${NC} ${BOLD}Personalization${NC} — Remembers your name & work schedule"
    echo -e "  ${GREEN}●${NC} ${BOLD}Daily Recap${NC} — Time-aware greetings & session recaps"
    echo -e "  ${GREEN}●${NC} ${BOLD}Task Tracking${NC} — Auto-creates task files with Jira integration"
    echo -e "  ${GREEN}●${NC} ${BOLD}PR Linking${NC} — Auto-captures PR URLs from git commands"
    echo -e "  ${GREEN}●${NC} ${BOLD}Easter Egg${NC} — Say 'batman' to @lu and see what happens"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  IMPORTANT: About your existing Cursor chats${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Your workspaces have been reopened from the new location."
    echo -e "  All your data (tasks, todos, docs, standups) is preserved."
    echo ""
    echo -e "  However, ${BOLD}existing agent chats won't carry over${NC} to the"
    echo -e "  new workspace windows. Start a ${BOLD}new chat${NC} and the agent"
    echo -e "  will automatically pick up all your data."
    echo ""
    echo -e "  ${CYAN}Tip:${NC} If you had important context in an old chat, you can"
    echo -e "  ask that agent to summarize it, then paste the summary into"
    echo -e "  a new chat in the reopened workspace."
    echo ""
    echo -e "${CYAN}Getting Started:${NC}"
    echo ""
    echo -e "  1. Pick any of the reopened workspace windows"
    echo -e "  2. Start a new chat and type ${BOLD}@lu${NC} or ${BOLD}@lucius${NC}"
    echo -e "  3. Try: ${DIM}\"@lu what can you do?\"${NC}"
    echo ""
}

main() {
    local mode="$1"

    print_banner

    case "$mode" in
        --plugin)
            sync_from_plugin
            ;;
        --data)
            init_data_files
            ;;
        --workspaces)
            fix_workspace_files
            ;;
        *)
            migrate_data
            cleanup_stale
            sync_cursor_dir
            sync_assets
            init_data_files
            fix_workspace_files
            install_global_plugin
            cleanup_cli_data
            check_first_run
            reopen_workspaces
            show_completion
            ;;
    esac
}

main "$@"
