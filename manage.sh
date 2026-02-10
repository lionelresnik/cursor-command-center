#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                  🔧 Cursor Command Center Manager                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# Use this to manage your Command Center after initial setup:
# - Add new project directories
# - Rescan for new repos
# - Update context groups
# - View current configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
CONTEXTS_DIR="$SCRIPT_DIR/contexts"
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
    echo -e "${CYAN}║${NC}        ${MAGENTA}🔧 Cursor Command Center Manager${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
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

# Check if config exists
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}⚠${NC}  No configuration found. Run ${GREEN}./setup.sh${NC} first."
        exit 1
    fi
}

# Show current configuration
show_config() {
    print_banner
    echo -e "${BOLD}Current Configuration:${NC}\n"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}Project Directories:${NC}"
        # Parse directories from config (handles both single and array format)
        if command -v python3 &> /dev/null; then
            python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
    dirs = config.get('projects_directories', [config.get('projects_directory', 'Not set')])
    if isinstance(dirs, str):
        dirs = [dirs]
    for d in dirs:
        print(f'  • {d}')
"
        else
            cat "$CONFIG_FILE"
        fi
        
        echo ""
        echo -e "${CYAN}Available Workspaces:${NC}"
        for ws in "$WORKSPACES_DIR"/*.code-workspace; do
            if [ -f "$ws" ]; then
                ws_name=$(basename "$ws" .code-workspace)
                echo -e "  • $ws_name"
            fi
        done
        
        echo ""
        echo -e "${CYAN}Contexts:${NC}"
        if command -v python3 &> /dev/null; then
            python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
    contexts = config.get('contexts', [])
    for c in contexts:
        print(f'  • {c}')
"
        fi
    else
        echo -e "${YELLOW}No configuration found.${NC}"
    fi
    echo ""
}

# Add a new project directory
add_directory() {
    print_banner
    echo -e "${BOLD}Add New Project Directory${NC}\n"
    
    echo -en "${YELLOW}?${NC} Enter the directory path: "
    read -r new_dir
    
    # Expand ~
    new_dir="${new_dir/#\~/$HOME}"
    
    if [ ! -d "$new_dir" ]; then
        print_warning "Directory doesn't exist: $new_dir"
        echo -en "${YELLOW}?${NC} Create it? [y/N]: "
        read -r create
        if [[ "$create" =~ ^[Yy] ]]; then
            mkdir -p "$new_dir"
            print_success "Created $new_dir"
        else
            exit 1
        fi
    fi
    
    # Update config to add directory
    if command -v python3 &> /dev/null; then
        python3 << EOF
import json

with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)

# Convert single directory to array if needed
if 'projects_directory' in config:
    old_dir = config.pop('projects_directory')
    config['projects_directories'] = [old_dir]

if 'projects_directories' not in config:
    config['projects_directories'] = []

new_dir = "$new_dir"
if new_dir not in config['projects_directories']:
    config['projects_directories'].append(new_dir)
    print(f"✓  Added: {new_dir}")
else:
    print(f"ℹ  Already configured: {new_dir}")

with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
EOF
    else
        print_warning "Python3 required to update config"
    fi
    
    echo ""
    echo -e "${CYAN}Run ${GREEN}./manage.sh rescan${NC} to scan for new repos in this directory."
}

# Rescan all directories for new repos
rescan_repos() {
    print_banner
    echo -e "${BOLD}Rescanning for Repositories...${NC}\n"
    
    if ! command -v python3 &> /dev/null; then
        print_warning "Python3 required for rescan"
        exit 1
    fi
    
    python3 << 'EOF'
import json
import os
from pathlib import Path

config_file = os.environ.get('CONFIG_FILE', 'config.json')
script_dir = os.path.dirname(os.path.abspath(config_file)) or '.'

with open(config_file, 'r') as f:
    config = json.load(f)

# Get directories (handle both formats)
dirs = config.get('projects_directories', [])
if not dirs and 'projects_directory' in config:
    dirs = [config['projects_directory']]

repos = []
print("Scanning directories:")
for d in dirs:
    print(f"  📁 {d}")
    if os.path.isdir(d):
        for item in os.listdir(d):
            item_path = os.path.join(d, item)
            git_path = os.path.join(item_path, '.git')
            if os.path.isdir(git_path):
                repos.append({
                    'name': item,
                    'path': item_path,
                    'source': d
                })
                print(f"     ✓ Found: {item}")

print(f"\n✓ Found {len(repos)} repositories total")

# Save repos list to config
config['repositories'] = repos
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("\nConfiguration updated!")
EOF
    
    echo ""
    echo -e "${CYAN}Run ${GREEN}./manage.sh regenerate${NC} to update workspace files."
}

# Regenerate workspace files
regenerate_workspaces() {
    print_banner
    echo -e "${BOLD}Regenerating Workspace Files...${NC}\n"
    
    if ! command -v python3 &> /dev/null; then
        print_warning "Python3 required"
        exit 1
    fi
    
    python3 << 'EOF'
import json
import os
from pathlib import Path

script_dir = os.path.dirname(os.path.abspath('config.json')) or '.'
config_file = 'config.json'
workspaces_dir = 'workspaces'

with open(config_file, 'r') as f:
    config = json.load(f)

repos = config.get('repositories', [])
contexts = config.get('contexts', ['all', 'none'])

os.makedirs(workspaces_dir, exist_ok=True)

for context in contexts:
    workspace_file = os.path.join(workspaces_dir, f"{context}.code-workspace")
    
    folders = [{"name": "📁 Command Center", "path": ".."}]
    
    if context == 'none':
        # Just command center
        pass
    elif context == 'all':
        # All repos
        for repo in repos:
            rel_path = os.path.relpath(repo['path'], workspaces_dir)
            folders.append({"name": f"🔷 {repo['name']}", "path": rel_path})
    else:
        # Custom context - check selection file
        selection_file = f"contexts/{context}.selection"
        if os.path.exists(selection_file):
            with open(selection_file) as f:
                selection = f.read().strip()
            if selection != 'none':
                indices = selection.split()
                for idx in indices:
                    try:
                        i = int(idx) - 1
                        if 0 <= i < len(repos):
                            repo = repos[i]
                            rel_path = os.path.relpath(repo['path'], workspaces_dir)
                            folders.append({"name": f"🔷 {repo['name']}", "path": rel_path})
                    except ValueError:
                        pass
    
    workspace = {
        "folders": folders,
        "settings": {
            "files.exclude": {
                "**/node_modules": True,
                "**/.git": True,
                "**/vendor": True
            }
        }
    }
    
    with open(workspace_file, 'w') as f:
        json.dump(workspace, f, indent=2)
    
    print(f"✓ Generated: {context}.code-workspace ({len(folders)} folders)")

print("\nDone! Use ./open.sh to launch a workspace.")
EOF
}

# Rename a workspace
rename_workspace() {
    print_banner
    echo -e "${BOLD}Rename Workspace${NC}\n"
    
    local old_name="$1"
    local new_name="$2"
    
    # If not provided, prompt for names
    if [ -z "$old_name" ]; then
        # List existing workspaces
        local workspaces=()
        for repos_file in "$CONTEXTS_DIR"/*.repos; do
            if [ -f "$repos_file" ]; then
                local name=$(basename "$repos_file" .repos)
                if [ "$name" != "all" ]; then
                    workspaces+=("$name")
                fi
            fi
        done
        
        if [ ${#workspaces[@]} -eq 0 ]; then
            print_warning "No workspaces found."
            return 1
        fi
        
        # Loop for valid selection
        while true; do
            echo -e "${CYAN}Available workspaces:${NC}"
            for i in "${!workspaces[@]}"; do
                echo -e "  $((i+1))) ${workspaces[$i]}"
            done
            echo ""
            echo -en "${YELLOW}?${NC} Select workspace to rename (number, or 'q' to cancel): "
            read -r choice
            
            if [ "$choice" = "q" ] || [ "$choice" = "cancel" ]; then
                echo -e "${DIM}Cancelled.${NC}"
                return 0
            fi
            
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#workspaces[@]} ]; then
                echo -e "${RED}Invalid selection. Please enter a number 1-${#workspaces[@]}${NC}"
                echo ""
                continue
            fi
            
            old_name="${workspaces[$((choice-1))]}"
            break
        done
    fi
    
    # Check if old workspace exists (for direct command line usage)
    if [ ! -f "$CONTEXTS_DIR/${old_name}.repos" ]; then
        echo -e "${RED}✗${NC} Workspace '${old_name}' not found"
        return 1
    fi
    
    # Prevent renaming 'all'
    if [ "$old_name" = "all" ]; then
        echo -e "${RED}✗${NC} Cannot rename 'all' workspace"
        return 1
    fi
    
    # Loop for valid new name
    while true; do
        if [ -z "$new_name" ]; then
            echo -en "${YELLOW}?${NC} New name for '${old_name}' (or 'q' to cancel): "
            read -r new_name
        fi
        
        if [ "$new_name" = "q" ] || [ "$new_name" = "cancel" ]; then
            echo -e "${DIM}Cancelled.${NC}"
            return 0
        fi
        
        # Validate new name
        if [ -z "$new_name" ]; then
            echo -e "${RED}✗${NC} Name cannot be empty"
            continue
        fi
        
        # Check for invalid characters
        if [[ "$new_name" =~ [^a-zA-Z0-9_-] ]]; then
            echo -e "${RED}✗${NC} Name can only contain letters, numbers, hyphens, and underscores"
            echo -e "${DIM}   Example: supply-chain, backend_api, Frontend${NC}"
            new_name=""
            continue
        fi
        
        # Check if new name already exists
        if [ -f "$CONTEXTS_DIR/${new_name}.repos" ]; then
            echo -e "${RED}✗${NC} Workspace '${new_name}' already exists"
            new_name=""
            continue
        fi
        
        break
    done
    
    # Rename files
    local renamed=0
    
    if [ -f "$CONTEXTS_DIR/${old_name}.repos" ]; then
        mv "$CONTEXTS_DIR/${old_name}.repos" "$CONTEXTS_DIR/${new_name}.repos"
        echo -e "  ${GREEN}✓${NC} contexts/${old_name}.repos → ${new_name}.repos"
        ((renamed++))
    fi
    
    if [ -f "$CONTEXTS_DIR/${old_name}.dirs" ]; then
        mv "$CONTEXTS_DIR/${old_name}.dirs" "$CONTEXTS_DIR/${new_name}.dirs"
        echo -e "  ${GREEN}✓${NC} contexts/${old_name}.dirs → ${new_name}.dirs"
        ((renamed++))
    fi
    
    if [ -f "$WORKSPACES_DIR/${old_name}.code-workspace" ]; then
        mv "$WORKSPACES_DIR/${old_name}.code-workspace" "$WORKSPACES_DIR/${new_name}.code-workspace"
        echo -e "  ${GREEN}✓${NC} workspaces/${old_name}.code-workspace → ${new_name}.code-workspace"
        ((renamed++))
    fi
    
    # Rename task-history folder if exists
    if [ -d "$SCRIPT_DIR/task-history/${old_name}" ]; then
        mv "$SCRIPT_DIR/task-history/${old_name}" "$SCRIPT_DIR/task-history/${new_name}"
        echo -e "  ${GREEN}✓${NC} task-history/${old_name}/ → ${new_name}/"
        ((renamed++))
    fi
    
    # Rename docs folder if exists
    if [ -d "$SCRIPT_DIR/docs/${old_name}" ]; then
        mv "$SCRIPT_DIR/docs/${old_name}" "$SCRIPT_DIR/docs/${new_name}"
        echo -e "  ${GREEN}✓${NC} docs/${old_name}/ → ${new_name}/"
        ((renamed++))
    fi
    
    # Update config.json contexts list
    if [ -f "$CONFIG_FILE" ] && command -v python3 &> /dev/null; then
        python3 << EOF
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
if 'contexts' in config:
    config['contexts'] = ['$new_name' if c == '$old_name' else c for c in config['contexts']]
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(config, f, indent=2)
    print("  ✓ Updated config.json")
EOF
    fi
    
    # Update .last-workspace if it was pointing to old name
    if [ -f "$SCRIPT_DIR/.last-workspace" ]; then
        last=$(cat "$SCRIPT_DIR/.last-workspace")
        if [ "$last" = "$old_name" ]; then
            echo "$new_name" > "$SCRIPT_DIR/.last-workspace"
            echo -e "  ${GREEN}✓${NC} Updated .last-workspace"
        fi
    fi
    
    echo ""
    print_success "Renamed '${old_name}' → '${new_name}'"
}

# Remove repos from a project
remove_repos() {
    print_banner
    echo -e "${BOLD}Remove Repos from Project${NC}\n"
    
    # List projects
    local projects=()
    for repos_file in "$CONTEXTS_DIR"/*.repos; do
        if [ -f "$repos_file" ]; then
            projects+=("$(basename "$repos_file" .repos)")
        fi
    done
    
    if [ ${#projects[@]} -eq 0 ]; then
        print_warning "No projects found."
        return 1
    fi
    
    local project=""
    
    # Loop for valid selection
    while true; do
        echo -e "${CYAN}Select a project:${NC}"
        for i in "${!projects[@]}"; do
            echo -e "  $((i+1))) ${projects[$i]}"
        done
        echo ""
        echo -en "${YELLOW}?${NC} Enter number (or 'q' to cancel): "
        read -r choice
        
        if [ "$choice" = "q" ] || [ "$choice" = "cancel" ]; then
            echo -e "${DIM}Cancelled.${NC}"
            return 0
        fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#projects[@]} ]; then
            echo -e "${RED}Invalid selection. Please enter a number 1-${#projects[@]}${NC}"
            echo ""
            continue
        fi
        
        project="${projects[$((choice-1))]}"
        break
    done
    local repos_file="$CONTEXTS_DIR/${project}.repos"
    
    # Read repos
    local repo_names=()
    local repo_paths=()
    local repo_selected=()
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            repo_names+=("$(echo "$line" | cut -d'|' -f1)")
            repo_paths+=("$(echo "$line" | cut -d'|' -f2)")
            repo_selected+=(1)
        fi
    done < "$repos_file"
    
    if [ ${#repo_names[@]} -eq 0 ]; then
        print_warning "No repos in $project"
        return 1
    fi
    
    # Interactive selection
    while true; do
        echo ""
        echo -e "${BOLD}Repos in $project (${#repo_names[@]} total):${NC}"
        echo ""
        for i in "${!repo_names[@]}"; do
            local num=$((i+1))
            if [ "${repo_selected[$i]}" = "1" ]; then
                echo -e "  ${GREEN}$num)${NC} ${GREEN}✓${NC} ${repo_names[$i]}"
            else
                echo -e "  ${DIM}$num)${NC} ${RED}✗${NC} ${DIM}${repo_names[$i]}${NC} ${RED}(will be removed)${NC}"
            fi
        done
        echo ""
        echo -e "${DIM}Commands: toggle 1,3,5 | save | cancel${NC}"
        echo -en "${MAGENTA}remove>${NC} "
        read -r cmd args
        
        case "$cmd" in
            toggle|t|remove|r)
                IFS=',' read -ra nums <<< "$args"
                for n in "${nums[@]}"; do
                    n=$(echo "$n" | tr -d ' ')
                    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#repo_names[@]}" ]; then
                        local idx=$((n-1))
                        if [ "${repo_selected[$idx]}" = "1" ]; then
                            repo_selected[$idx]=0
                        else
                            repo_selected[$idx]=1
                        fi
                    fi
                done
                ;;
            save|s|confirm|ok|y)
                # Write back only selected repos
                > "$repos_file"
                local kept=0
                for i in "${!repo_names[@]}"; do
                    if [ "${repo_selected[$i]}" = "1" ]; then
                        echo "${repo_names[$i]}|${repo_paths[$i]}" >> "$repos_file"
                        ((kept++))
                    fi
                done
                local removed=$((${#repo_names[@]} - kept))
                echo ""
                print_success "Kept $kept repos, removed $removed"
                echo -e "${DIM}Run './cc manage regenerate' to update workspace files${NC}"
                return 0
                ;;
            cancel|c|q)
                echo -e "${DIM}Cancelled${NC}"
                return 0
                ;;
            *)
                echo -e "${YELLOW}⚠${NC}  Unknown: $cmd"
                ;;
        esac
    done
}

# Export configuration
export_config() {
    print_banner
    echo -e "${BOLD}Export Configuration${NC}\n"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local export_file="${1:-command-center-export-$timestamp.tar.gz}"
    
    # Create temp directory
    local tmp_dir=$(mktemp -d)
    local export_dir="$tmp_dir/command-center-export"
    mkdir -p "$export_dir"
    
    # Copy config
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$export_dir/"
        echo -e "  ${GREEN}✓${NC} config.json"
    fi
    
    # Copy contexts
    if [ -d "$CONTEXTS_DIR" ]; then
        mkdir -p "$export_dir/contexts"
        cp "$CONTEXTS_DIR"/*.repos "$export_dir/contexts/" 2>/dev/null && echo -e "  ${GREEN}✓${NC} contexts/*.repos"
        cp "$CONTEXTS_DIR"/*.dirs "$export_dir/contexts/" 2>/dev/null && echo -e "  ${GREEN}✓${NC} contexts/*.dirs"
    fi
    
    # Optional: include knowledge base (task history + docs)
    echo ""
    echo -en "${YELLOW}?${NC} Include knowledge base (task-history + docs)? [y/N]: "
    read -r include_knowledge
    if [[ "$include_knowledge" =~ ^[Yy] ]]; then
        # List available workspaces
        local workspaces=()
        for dir in "$SCRIPT_DIR/task-history"/*/ "$SCRIPT_DIR/docs"/*/; do
            if [ -d "$dir" ]; then
                local ws=$(basename "$dir")
                if [[ ! " ${workspaces[@]} " =~ " ${ws} " ]]; then
                    workspaces+=("$ws")
                fi
            fi
        done
        
        if [ ${#workspaces[@]} -gt 0 ]; then
            echo ""
            echo -e "${CYAN}Available workspaces:${NC}"
            for ws in "${workspaces[@]}"; do
                echo -e "  • $ws"
            done
            echo ""
            echo -en "${YELLOW}?${NC} Export all workspaces or specific? [all/workspace name]: "
            read -r ws_choice
            
            if [ "$ws_choice" = "all" ] || [ -z "$ws_choice" ]; then
                # Export all
                if [ -d "$SCRIPT_DIR/task-history" ]; then
                    cp -r "$SCRIPT_DIR/task-history" "$export_dir/"
                    echo -e "  ${GREEN}✓${NC} task-history/ (all workspaces)"
                fi
                if [ -d "$SCRIPT_DIR/docs" ]; then
                    cp -r "$SCRIPT_DIR/docs" "$export_dir/"
                    echo -e "  ${GREEN}✓${NC} docs/ (all workspaces)"
                fi
            else
                # Export specific workspace
                mkdir -p "$export_dir/task-history"
                mkdir -p "$export_dir/docs"
                if [ -d "$SCRIPT_DIR/task-history/$ws_choice" ]; then
                    cp -r "$SCRIPT_DIR/task-history/$ws_choice" "$export_dir/task-history/"
                    echo -e "  ${GREEN}✓${NC} task-history/$ws_choice/"
                fi
                if [ -d "$SCRIPT_DIR/task-history/shared" ]; then
                    cp -r "$SCRIPT_DIR/task-history/shared" "$export_dir/task-history/"
                    echo -e "  ${GREEN}✓${NC} task-history/shared/"
                fi
                if [ -d "$SCRIPT_DIR/docs/$ws_choice" ]; then
                    cp -r "$SCRIPT_DIR/docs/$ws_choice" "$export_dir/docs/"
                    echo -e "  ${GREEN}✓${NC} docs/$ws_choice/"
                fi
                if [ -d "$SCRIPT_DIR/docs/shared" ]; then
                    cp -r "$SCRIPT_DIR/docs/shared" "$export_dir/docs/"
                    echo -e "  ${GREEN}✓${NC} docs/shared/"
                fi
            fi
        else
            # No workspace folders yet, copy entire folders
            if [ -d "$SCRIPT_DIR/task-history" ]; then
                cp -r "$SCRIPT_DIR/task-history" "$export_dir/"
                echo -e "  ${GREEN}✓${NC} task-history/"
            fi
            if [ -d "$SCRIPT_DIR/docs" ]; then
                cp -r "$SCRIPT_DIR/docs" "$export_dir/"
                echo -e "  ${GREEN}✓${NC} docs/"
            fi
        fi
    fi
    
    # Create archive
    echo ""
    tar -czf "$export_file" -C "$tmp_dir" "command-center-export"
    rm -rf "$tmp_dir"
    
    print_success "Exported to: $export_file"
    echo -e "${DIM}Share this file to transfer your setup to another machine${NC}"
}

# Import configuration
import_config() {
    print_banner
    echo -e "${BOLD}Import Configuration${NC}\n"
    
    local import_file="$1"
    
    # Loop until valid file or cancelled
    while true; do
        if [ -z "$import_file" ]; then
            echo -en "${YELLOW}?${NC} Path to export file (or 'q' to cancel): "
            read -r import_file
        fi
        
        if [ "$import_file" = "q" ] || [ "$import_file" = "cancel" ]; then
            echo -e "${DIM}Cancelled.${NC}"
            return 0
        fi
        
        # Expand ~
        import_file="${import_file/#\~/$HOME}"
        
        if [ ! -f "$import_file" ]; then
            echo -e "${RED}✗${NC} File not found: $import_file"
            import_file=""
            continue
        fi
        
        break
    done
    
    # Create temp directory
    local tmp_dir=$(mktemp -d)
    tar -xzf "$import_file" -C "$tmp_dir"
    
    local export_dir="$tmp_dir/command-center-export"
    
    if [ ! -d "$export_dir" ]; then
        echo -e "${RED}✗${NC} Invalid export file"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    echo -e "${CYAN}Found in export:${NC}"
    ls -la "$export_dir" | tail -n +4 | while read line; do echo "  $line"; done
    echo ""
    
    # Confirm
    echo -en "${YELLOW}?${NC} Import and overwrite current config? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo -e "${DIM}Cancelled${NC}"
        rm -rf "$tmp_dir"
        return 0
    fi
    
    # Import config
    if [ -f "$export_dir/config.json" ]; then
        cp "$export_dir/config.json" "$CONFIG_FILE"
        echo -e "  ${GREEN}✓${NC} Imported config.json"
    fi
    
    # Import contexts
    if [ -d "$export_dir/contexts" ]; then
        mkdir -p "$CONTEXTS_DIR"
        cp "$export_dir/contexts"/*.repos "$CONTEXTS_DIR/" 2>/dev/null && echo -e "  ${GREEN}✓${NC} Imported contexts/*.repos"
        cp "$export_dir/contexts"/*.dirs "$CONTEXTS_DIR/" 2>/dev/null && echo -e "  ${GREEN}✓${NC} Imported contexts/*.dirs"
    fi
    
    # Path remapping - detect if paths need to be updated
    local old_base_path=""
    local need_remap=false
    
    # Find the original base path from .repos files
    for repos_file in "$CONTEXTS_DIR"/*.repos; do
        if [ -f "$repos_file" ]; then
            while IFS='|' read -r name path; do
                if [ -n "$path" ] && [ ! -d "$path" ]; then
                    # Path doesn't exist - extract base directory
                    # Find common parent (e.g., /Users/olduser/Projects)
                    old_base_path=$(dirname "$path")
                    need_remap=true
                    break 2
                fi
            done < "$repos_file"
        fi
    done
    
    if [ "$need_remap" = true ]; then
        echo ""
        echo -e "${YELLOW}⚠${NC}  Detected paths from a different machine:"
        echo -e "   ${DIM}Old path: $old_base_path${NC}"
        echo ""
        echo -en "${YELLOW}?${NC} Enter your projects directory (or press Enter to skip): "
        read -r new_base_path
        
        if [ -n "$new_base_path" ]; then
            # Expand ~
            new_base_path="${new_base_path/#\~/$HOME}"
            
            if [ -d "$new_base_path" ]; then
                echo ""
                echo -e "${CYAN}Remapping paths:${NC}"
                echo -e "  ${DIM}$old_base_path → $new_base_path${NC}"
                echo ""
                
                local remapped=0
                
                # Update .repos files
                for repos_file in "$CONTEXTS_DIR"/*.repos; do
                    if [ -f "$repos_file" ]; then
                        local tmp_repos=$(mktemp)
                        while IFS='|' read -r name path; do
                            if [ -n "$path" ]; then
                                # Replace old base with new base
                                local new_path="${path/$old_base_path/$new_base_path}"
                                echo "${name}|${new_path}" >> "$tmp_repos"
                                if [ "$path" != "$new_path" ]; then
                                    ((remapped++))
                                fi
                            fi
                        done < "$repos_file"
                        mv "$tmp_repos" "$repos_file"
                    fi
                done
                
                # Update .dirs files
                for dirs_file in "$CONTEXTS_DIR"/*.dirs; do
                    if [ -f "$dirs_file" ]; then
                        local tmp_dirs=$(mktemp)
                        while IFS= read -r dir_path; do
                            if [ -n "$dir_path" ]; then
                                local new_dir="${dir_path/$old_base_path/$new_base_path}"
                                echo "$new_dir" >> "$tmp_dirs"
                            fi
                        done < "$dirs_file"
                        mv "$tmp_dirs" "$dirs_file"
                    fi
                done
                
                # Update config.json
                if [ -f "$CONFIG_FILE" ] && command -v python3 &> /dev/null; then
                    python3 << EOF
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)

old_base = '$old_base_path'
new_base = '$new_base_path'

# Update projects_directories
if 'projects_directories' in config:
    config['projects_directories'] = [d.replace(old_base, new_base) for d in config['projects_directories']]
if 'projects_directory' in config:
    config['projects_directory'] = config['projects_directory'].replace(old_base, new_base)

# Update repositories
if 'repositories' in config:
    for repo in config['repositories']:
        if 'path' in repo:
            repo['path'] = repo['path'].replace(old_base, new_base)
        if 'source' in repo:
            repo['source'] = repo['source'].replace(old_base, new_base)

with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
EOF
                fi
                
                print_success "Remapped $remapped repo paths"
            else
                echo -e "${YELLOW}⚠${NC}  Directory not found: $new_base_path"
                echo -e "${DIM}   You can manually update paths later or run setup again${NC}"
            fi
        else
            echo -e "${DIM}Skipped path remapping. You may need to update paths manually.${NC}"
        fi
    fi
    
    # Import knowledge base
    if [ -d "$export_dir/task-history" ] || [ -d "$export_dir/docs" ]; then
        # Show workspaces in export
        local export_workspaces=()
        for dir in "$export_dir/task-history"/*/ "$export_dir/docs"/*/; do
            if [ -d "$dir" ]; then
                local ws=$(basename "$dir")
                if [[ ! " ${export_workspaces[@]} " =~ " ${ws} " ]]; then
                    export_workspaces+=("$ws")
                fi
            fi
        done
        
        if [ ${#export_workspaces[@]} -gt 0 ]; then
            echo ""
            echo -e "${CYAN}Workspaces in export:${NC}"
            for ws in "${export_workspaces[@]}"; do
                echo -e "  • $ws"
            done
        fi
        
        echo ""
        echo -en "${YELLOW}?${NC} Import knowledge base (task-history + docs)? [y/N]: "
        read -r import_knowledge
        if [[ "$import_knowledge" =~ ^[Yy] ]]; then
            if [ -d "$export_dir/task-history" ]; then
                mkdir -p "$SCRIPT_DIR/task-history"
                cp -r "$export_dir/task-history"/* "$SCRIPT_DIR/task-history/" 2>/dev/null
                echo -e "  ${GREEN}✓${NC} Imported task-history/"
            fi
            if [ -d "$export_dir/docs" ]; then
                mkdir -p "$SCRIPT_DIR/docs"
                cp -r "$export_dir/docs"/* "$SCRIPT_DIR/docs/" 2>/dev/null
                echo -e "  ${GREEN}✓${NC} Imported docs/"
            fi
        fi
    fi
    
    rm -rf "$tmp_dir"
    
    echo ""
    print_success "Import complete!"
    echo -e "${DIM}Run './cc manage regenerate' to rebuild workspace files${NC}"
}

# Show help
show_help() {
    print_banner
    echo -e "${BOLD}Usage:${NC} ./manage.sh [command]\n"
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}status${NC}      Show current configuration"
    echo -e "  ${GREEN}add${NC}         Add a new project directory"
    echo -e "  ${GREEN}remove${NC}      Remove repos from a project"
    echo -e "  ${GREEN}rename${NC}      Rename a workspace"
    echo -e "  ${GREEN}rescan${NC}      Rescan directories for new repos"
    echo -e "  ${GREEN}regenerate${NC}  Regenerate workspace files"
    echo -e "  ${GREEN}export${NC}      Export config (for backup/sharing)"
    echo -e "  ${GREEN}import${NC}      Import config from export file"
    echo -e "  ${GREEN}help${NC}        Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ${DIM}# View current setup${NC}"
    echo -e "  ./manage.sh status"
    echo ""
    echo -e "  ${DIM}# Rename a workspace${NC}"
    echo -e "  ./manage.sh rename mobile mobile-app"
    echo ""
    echo -e "  ${DIM}# Backup your setup${NC}"
    echo -e "  ./manage.sh export"
    echo -e "  ./manage.sh import backup.tar.gz"
    echo ""
}

# Export for python scripts
export CONFIG_FILE
export SCRIPT_DIR

# Main
case "${1:-help}" in
    status|config|show)
        check_config
        show_config
        ;;
    add|add-dir|add-directory)
        check_config
        add_directory
        ;;
    remove|rm|delete)
        check_config
        remove_repos
        ;;
    rename|mv)
        check_config
        rename_workspace "$2" "$3"
        ;;
    rescan|scan|refresh)
        check_config
        rescan_repos
        ;;
    regenerate|regen|rebuild)
        check_config
        regenerate_workspaces
        ;;
    export|backup)
        check_config
        export_config "$2"
        ;;
    import|restore)
        import_config "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac

