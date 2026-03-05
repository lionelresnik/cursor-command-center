#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              🔄 Cursor Command Center Sync & Upgrade                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# Syncs plugin components and upgrades existing Command Center installations
# with new features without recreating workspaces.
#
# Usage:
#   ./sync.sh              # Full sync (plugin components + data files + workspace fixes)
#   ./sync.sh --plugin     # Only sync plugin components
#   ./sync.sh --data       # Only initialize data files
#   ./sync.sh --workspaces # Only fix workspace files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/../cursor-command-center-plugin"
CURSOR_DIR="$SCRIPT_DIR/.cursor"
ASSETS_DIR="$SCRIPT_DIR/assets"
WORKSPACES_DIR="$SCRIPT_DIR/workspaces"

# Colors
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

sync_plugin_components() {
    print_step "Syncing Plugin Components"
    
    if [ ! -d "$PLUGIN_DIR" ]; then
        print_warning "Plugin repo not found at $PLUGIN_DIR"
        print_info "Skipping plugin sync"
        print_info "Clone the plugin repo next to this one to enable @lu features:"
        print_info "  cd $(dirname "$SCRIPT_DIR")"
        print_info "  git clone https://github.com/lionelresnik/cursor-command-center-plugin.git"
        return 1
    fi
    
    print_info "Found plugin at: $PLUGIN_DIR"
    
    # Create .cursor structure
    mkdir -p "$CURSOR_DIR/rules" "$CURSOR_DIR/skills" "$CURSOR_DIR/agents" "$CURSOR_DIR/hooks" "$CURSOR_DIR/scripts" "$ASSETS_DIR"
    
    local added_count=0
    local updated_count=0
    local unchanged_count=0
    
    # Helper function to sync files and track changes
    sync_files() {
        local src_dir="$1"
        local dest_dir="$2"
        local pattern="$3"
        local category="$4"
        
        local changes=()
        
        for src_file in "$src_dir"/$pattern; do
            [ -e "$src_file" ] || continue
            local filename=$(basename "$src_file")
            local dest_file="$dest_dir/$filename"
            
            if [ ! -f "$dest_file" ]; then
                cp -r "$src_file" "$dest_file"
                changes+=("${GREEN}+${NC} $filename ${DIM}(new)${NC}")
                ((added_count++))
            elif ! cmp -s "$src_file" "$dest_file"; then
                cp -r "$src_file" "$dest_file"
                changes+=("${YELLOW}↻${NC} $filename ${DIM}(modified)${NC}")
                ((updated_count++))
            else
                ((unchanged_count++))
            fi
        done
        
        # Print changes for this category
        if [ ${#changes[@]} -gt 0 ]; then
            for change in "${changes[@]}"; do
                echo -e "  $change"
            done
        fi
    }
    
    # Sync rules
    if [ -d "$PLUGIN_DIR/rules" ]; then
        sync_files "$PLUGIN_DIR/rules" "$CURSOR_DIR/rules" "*.mdc" "rules"
    fi
    
    # Sync skills (directory-based)
    if [ -d "$PLUGIN_DIR/skills" ]; then
        for skill_dir in "$PLUGIN_DIR/skills"/*; do
            [ -d "$skill_dir" ] || continue
            local skill_name=$(basename "$skill_dir")
            local dest_skill_dir="$CURSOR_DIR/skills/$skill_name"
            mkdir -p "$dest_skill_dir"
            
            for skill_file in "$skill_dir"/*; do
                [ -f "$skill_file" ] || continue
                local filename=$(basename "$skill_file")
                local dest_file="$dest_skill_dir/$filename"
                
                if [ ! -f "$dest_file" ]; then
                    cp "$skill_file" "$dest_file"
                    echo -e "  ${GREEN}+${NC} skills/$skill_name/$filename ${DIM}(new)${NC}"
                    ((added_count++))
                elif ! cmp -s "$skill_file" "$dest_file"; then
                    cp "$skill_file" "$dest_file"
                    echo -e "  ${YELLOW}↻${NC} skills/$skill_name/$filename ${DIM}(modified)${NC}"
                    ((updated_count++))
                else
                    ((unchanged_count++))
                fi
            done
        done
    fi
    
    # Sync agents
    if [ -d "$PLUGIN_DIR/agents" ]; then
        sync_files "$PLUGIN_DIR/agents" "$CURSOR_DIR/agents" "*.md" "agents"
    fi
    
    # Sync hooks
    if [ -d "$PLUGIN_DIR/hooks" ]; then
        sync_files "$PLUGIN_DIR/hooks" "$CURSOR_DIR/hooks" "*" "hooks"
    fi
    
    # Sync scripts
    if [ -d "$PLUGIN_DIR/scripts" ]; then
        for script in "$PLUGIN_DIR/scripts"/*.sh; do
            [ -f "$script" ] || continue
            local filename=$(basename "$script")
            local dest_file="$CURSOR_DIR/scripts/$filename"
            
            if [ ! -f "$dest_file" ]; then
                cp "$script" "$dest_file"
                chmod +x "$dest_file"
                echo -e "  ${GREEN}+${NC} scripts/$filename ${DIM}(new)${NC}"
                ((added_count++))
            elif ! cmp -s "$script" "$dest_file"; then
                cp "$script" "$dest_file"
                chmod +x "$dest_file"
                echo -e "  ${YELLOW}↻${NC} scripts/$filename ${DIM}(modified)${NC}"
                ((updated_count++))
            else
                ((unchanged_count++))
            fi
        done
    fi
    
    # Sync assets
    if [ -d "$PLUGIN_DIR/assets" ]; then
        sync_files "$PLUGIN_DIR/assets" "$ASSETS_DIR" "*" "assets"
    fi
    
    # Verify graph.sh is available for @lu (--mermaid-file support)
    if [ -f "$SCRIPT_DIR/graph.sh" ]; then
        chmod +x "$SCRIPT_DIR/graph.sh"
    fi
    
    # Fix easter-egg.mdc path reference
    if [ -f "$CURSOR_DIR/rules/easter-egg.mdc" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's|assets/easter-egg-art.md|~/.command-center/assets/easter-egg-art.md|g' "$CURSOR_DIR/rules/easter-egg.mdc" 2>/dev/null || true
        else
            sed -i 's|assets/easter-egg-art.md|~/.command-center/assets/easter-egg-art.md|g' "$CURSOR_DIR/rules/easter-egg.mdc" 2>/dev/null || true
        fi
    fi
    
    echo ""
    # Print summary
    if [ $added_count -gt 0 ] || [ $updated_count -gt 0 ]; then
        print_success "Sync complete: $added_count added, $updated_count updated, $unchanged_count unchanged"
    else
        print_success "All files up to date ($unchanged_count files)"
    fi
    
    return 0
}

init_data_files() {
    print_step "Initializing Data Files"
    
    # Create directories
    mkdir -p "$SCRIPT_DIR/standups" "$SCRIPT_DIR/task-history" "$SCRIPT_DIR/docs"
    
    # Initialize profile.json if missing
    if [ ! -f "$SCRIPT_DIR/profile.json" ]; then
        cat > "$SCRIPT_DIR/profile.json" << 'EOF'
{
  "name": "",
  "createdAt": "",
  "preferences": {
    "workWeek": "mon-fri"
  }
}
EOF
        print_success "Created profile.json (personalization: name, work week)"
    else
        print_info "profile.json already exists"
    fi
    
    # Initialize session-state.json if missing
    if [ ! -f "$SCRIPT_DIR/session-state.json" ]; then
        cat > "$SCRIPT_DIR/session-state.json" << 'EOF'
{
  "lastWorkspace": "",
  "lastSessionEnd": ""
}
EOF
        print_success "Created session-state.json (session tracking)"
    else
        print_info "session-state.json already exists"
    fi
    
    # Initialize todos.md if missing
    if [ ! -f "$SCRIPT_DIR/todos.md" ]; then
        cat > "$SCRIPT_DIR/todos.md" << 'EOF'
# Todos

## In Progress

## Pending

## Done
EOF
        print_success "Created todos.md (persistent todo list)"
    else
        print_info "todos.md already exists"
    fi
    
    print_success "Data files initialized"
}

fix_workspace_files() {
    print_step "Fixing Workspace Files"
    
    if [ ! -d "$WORKSPACES_DIR" ]; then
        print_warning "No workspaces directory found"
        return
    fi
    
    local fixed=0
    local total=0
    
    for ws_file in "$WORKSPACES_DIR"/*.code-workspace; do
        [ -e "$ws_file" ] || continue
        total=$((total + 1))
        
        # Check if it has the tilde path issue
        if grep -q '"path": "~/\.command-center"' "$ws_file" 2>/dev/null; then
            # Fix it
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's|"path": "~/\.command-center"|"path": "'$SCRIPT_DIR'"|g' "$ws_file"
            else
                sed -i 's|"path": "~/\.command-center"|"path": "'$SCRIPT_DIR'"|g' "$ws_file"
            fi
            fixed=$((fixed + 1))
            print_success "Fixed $(basename "$ws_file")"
        fi
    done
    
    if [ $fixed -eq 0 ]; then
        print_info "All workspace files are up to date ($total checked)"
    else
        print_success "Fixed $fixed workspace file(s)"
    fi
}

show_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                    ${BOLD}✓ Sync Complete!${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}What's New:${NC}"
    echo ""
    echo -e "  ${GREEN}●${NC} ${BOLD}@lu / @lucius${NC} — AI assistant with full plugin capabilities"
    echo -e "  ${GREEN}●${NC} ${BOLD}Todo List${NC} — Persistent todos with priorities & workspace tags"
    echo -e "  ${GREEN}●${NC} ${BOLD}Standups${NC} — Daily/weekly summaries from todos & task history"
    echo -e "  ${GREEN}●${NC} ${BOLD}Personalization${NC} — Remembers your name & work schedule"
    echo -e "  ${GREEN}●${NC} ${BOLD}Daily Recap${NC} — Time-aware greetings & session recaps"
    echo -e "  ${GREEN}●${NC} ${BOLD}Task Tracking${NC} — Auto-creates task files with Jira integration"
    echo -e "  ${GREEN}●${NC} ${BOLD}PR Linking${NC} — Auto-captures PR URLs from git commands"
    echo -e "  ${GREEN}●${NC} ${BOLD}Easter Egg${NC} — Say 'batman' to @lu and see what happens 🦇"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo -e "  1. Open any workspace in Cursor"
    echo -e "  2. Type ${BOLD}@lu${NC} or ${BOLD}@lucius${NC} in chat"
    echo -e "  3. Try: ${DIM}\"@lu what can you do?\"${NC}"
    echo ""
}

main() {
    local mode="$1"
    
    print_banner
    
    case "$mode" in
        --plugin)
            sync_plugin_components
            ;;
        --data)
            init_data_files
            ;;
        --workspaces)
            fix_workspace_files
            ;;
        *)
            # Full sync
            local plugin_synced=false
            sync_plugin_components && plugin_synced=true
            init_data_files
            fix_workspace_files
            
            if [ "$plugin_synced" = true ]; then
                show_completion
            else
                echo ""
                print_warning "Plugin components not synced (plugin repo not found)"
                print_info "Data files and workspaces were updated"
                echo ""
            fi
            ;;
    esac
}

main "$@"
