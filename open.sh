#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     🚀 Cursor Command Center Launcher                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACES_DIR="$SCRIPT_DIR/workspaces"
CONTEXTS_DIR="$SCRIPT_DIR/contexts"
CONFIG_FILE="$SCRIPT_DIR/config.json"
LAST_FILE="$SCRIPT_DIR/.last-workspace"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Check if setup has been run
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠${NC}  Command Center hasn't been set up yet!"
    echo -e "${DIM}Run ./setup.sh first to configure your projects.${NC}"
    exit 1
fi

# Check if gum is available for pretty UI
HAS_GUM=false
if command -v gum &> /dev/null; then
    HAS_GUM=true
fi

# Handle --last flag
if [ "$1" = "--last" ] || [ "$1" = "-l" ]; then
    if [ -f "$LAST_FILE" ]; then
        last_workspace=$(cat "$LAST_FILE")
        workspace_file="$WORKSPACES_DIR/${last_workspace}.code-workspace"
        if [ -f "$workspace_file" ]; then
            echo -e "${GREEN}▶${NC} Re-opening ${BOLD}$last_workspace${NC} workspace..."
            if command -v cursor &> /dev/null; then
                cursor "$workspace_file"
                exit 0
            else
                echo -e "${YELLOW}⚠${NC}  Cursor CLI not found. Install it from Cursor: Cmd+Shift+P → 'Install cursor command'"
                exit 1
            fi
        fi
    fi
    echo -e "${YELLOW}⚠${NC}  No last workspace found. Run ./open.sh to select one."
    exit 1
fi

# Handle --help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: ./open.sh [options] [workspace]"
    echo ""
    echo "Options:"
    echo "  -l, --last    Re-open the last workspace"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Examples:"
    echo "  ./open.sh           # Show menu to select workspace"
    echo "  ./open.sh --last    # Re-open last workspace"
    echo "  ./open.sh backend   # Open 'backend' workspace directly"
    exit 0
fi

# Handle direct workspace name argument
if [ -n "$1" ] && [ "$1" != "--last" ]; then
    workspace_file="$WORKSPACES_DIR/${1}.code-workspace"
    if [ -f "$workspace_file" ]; then
        echo "$1" > "$LAST_FILE"
        echo -e "${GREEN}▶${NC} Opening ${BOLD}$1${NC} workspace..."
        if command -v cursor &> /dev/null; then
            cursor "$workspace_file"
            exit 0
        else
            echo -e "${YELLOW}⚠${NC}  Cursor CLI not found. Install it from Cursor: Cmd+Shift+P → 'Install cursor command'"
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} Workspace '$1' not found."
        echo -e "${DIM}Available: $(ls "$WORKSPACES_DIR"/*.code-workspace 2>/dev/null | xargs -n1 basename | sed 's/.code-workspace//' | tr '\n' ' ')${NC}"
        exit 1
    fi
fi

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${MAGENTA}🚀 Cursor Command Center${NC}                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Scan a directory for git repos
scan_directory() {
    local dir="$1"
    local repos=()
    
    if [ -d "$dir" ]; then
        while IFS= read -r -d '' git_dir; do
            repo_path=$(dirname "$git_dir")
            repo_name=$(basename "$repo_path")
            repos+=("$repo_name|$repo_path")
        done < <(find "$dir" -maxdepth 5 -name ".git" -type d -print0 2>/dev/null)
    fi
    
    printf '%s\n' "${repos[@]}"
}

# Generate workspace file for a project
generate_workspace() {
    local project_name="$1"
    local workspace_file="$WORKSPACES_DIR/${project_name}.code-workspace"
    
    mkdir -p "$WORKSPACES_DIR"
    
    echo '{' > "$workspace_file"
    echo '  "folders": [' >> "$workspace_file"
    echo '    { "name": "📁 Command Center", "path": ".." }' >> "$workspace_file"
    
    local repos_file="$CONTEXTS_DIR/${project_name}.repos"
    
    if [ -f "$repos_file" ]; then
        while IFS= read -r repo_entry; do
            if [ -n "$repo_entry" ]; then
                repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                
                local rel_path=$(python3 -c "import os.path; print(os.path.relpath('$repo_path', '$WORKSPACES_DIR'))" 2>/dev/null || echo "$repo_path")
                
                echo ',' >> "$workspace_file"
                printf '    { "name": "🔷 %s", "path": "%s" }' "$repo_name" "$rel_path" >> "$workspace_file"
            fi
        done < "$repos_file"
    fi
    
    echo '' >> "$workspace_file"
    echo '  ],' >> "$workspace_file"
    echo '  "settings": {' >> "$workspace_file"
    echo '    "files.exclude": {' >> "$workspace_file"
    echo '      "**/node_modules": true,' >> "$workspace_file"
    echo '      "**/.git": true,' >> "$workspace_file"
    echo '      "**/vendor": true' >> "$workspace_file"
    echo '    }' >> "$workspace_file"
    echo '  }' >> "$workspace_file"
    echo '}' >> "$workspace_file"
}

# Regenerate "all" workspace
regenerate_all_workspace() {
    local workspace_file="$WORKSPACES_DIR/all.code-workspace"
    
    echo '{' > "$workspace_file"
    echo '  "folders": [' >> "$workspace_file"
    echo '    { "name": "📁 Command Center", "path": ".." }' >> "$workspace_file"
    
    local seen_repos=""
    
    for repos_file in "$CONTEXTS_DIR"/*.repos; do
        if [ -f "$repos_file" ]; then
            while IFS= read -r repo_entry; do
                if [ -n "$repo_entry" ]; then
                    repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                    repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                    
                    if echo "$seen_repos" | grep -q "|$repo_path|"; then
                        continue
                    fi
                    seen_repos="$seen_repos|$repo_path|"
                    
                    local rel_path=$(python3 -c "import os.path; print(os.path.relpath('$repo_path', '$WORKSPACES_DIR'))" 2>/dev/null || echo "$repo_path")
                    
                    echo ',' >> "$workspace_file"
                    printf '    { "name": "🔷 %s", "path": "%s" }' "$repo_name" "$rel_path" >> "$workspace_file"
                fi
            done < "$repos_file"
        fi
    done
    
    echo '' >> "$workspace_file"
    echo '  ],' >> "$workspace_file"
    echo '  "settings": {' >> "$workspace_file"
    echo '    "files.exclude": {' >> "$workspace_file"
    echo '      "**/node_modules": true,' >> "$workspace_file"
    echo '      "**/.git": true,' >> "$workspace_file"
    echo '      "**/vendor": true' >> "$workspace_file"
    echo '    }' >> "$workspace_file"
    echo '  }' >> "$workspace_file"
    echo '}' >> "$workspace_file"
}

# Add a new project group
add_new_project() {
    echo ""
    echo -e "${BOLD}➕ Add New Project Group${NC}\n"
    
    local project_name=""
    local safe_name=""
    
    # Loop until valid name or cancelled
    while true; do
        echo -en "${YELLOW}?${NC} Project group name: "
        read -r project_name
        
        if [ -z "$project_name" ]; then
            echo -e "${DIM}Cancelled.${NC}"
            return 1
        fi
        
        # Validate name (no spaces or special characters)
        if [[ "$project_name" =~ [^a-zA-Z0-9_-] ]]; then
            echo -e "${RED}✗${NC} Name can only contain letters, numbers, hyphens, and underscores"
            echo -e "${DIM}   Example: supply-chain, backend_api, Frontend${NC}"
            echo ""
            continue
        fi
        
        # Valid name - break out of loop
        break
    done
    
    # Normalize to lowercase
    safe_name=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')
    
    echo ""
    echo -e "${CYAN}Adding directories for \"$project_name\"${NC}"
    echo ""
    
    local dirs=()
    local all_repos=()
    local adding=true
    
    # Remember last browsed directory across sessions
    local last_dir_file="$SCRIPT_DIR/.last-browse-dir"
    local current_dir="${HOME}"
    if [ -f "$last_dir_file" ] && [ -d "$(cat "$last_dir_file")" ]; then
        current_dir="$(cat "$last_dir_file")"
    fi
    
    while $adding; do
        local dir_path=""
        
        # Show browse UI
        echo -e "${DIM}Find a directory containing repos for this project:${NC}"
        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}📁 Directory Browser${NC}                                        ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}    ${GREEN}ls${NC}        - List directories here                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}    ${GREEN}cd <dir>${NC}  - Enter a directory                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}    ${GREEN}cd ..${NC}     - Go up one level                               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}    ${GREEN}select${NC}    - ✓ Pick repos from this dir (toggle selection)  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}    ${GREEN}done${NC}      - ✓ Finish this project group                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        while true; do
            echo -e "${DIM}📍 ${NC}${BOLD}$current_dir${NC}"
            echo -en "${MAGENTA}browse>${NC} "
            read -e cmd args
            
            case "$cmd" in
                ls|l)
                    echo ""
                    local has_items=false
                    for item in "$current_dir"/*; do
                        if [ -d "$item" ]; then
                            has_items=true
                            local name=$(basename "$item")
                            if [ -d "$item/.git" ]; then
                                echo -e "  ${GREEN}📦 $name${NC} ${DIM}(git repo)${NC}"
                            else
                                echo -e "  📁 $name"
                            fi
                        fi
                    done
                    if [ "$has_items" = false ]; then
                        echo -e "  ${DIM}(empty)${NC}"
                    fi
                    echo ""
                    ;;
                cd)
                    if [ -z "$args" ]; then
                        current_dir="$HOME"
                    elif [ "$args" = ".." ]; then
                        current_dir=$(dirname "$current_dir")
                    elif [ "$args" = "~" ]; then
                        current_dir="$HOME"
                    else
                        args="${args/#\~/$HOME}"
                        if [[ "$args" = /* ]]; then
                            new_dir="$args"
                        else
                            new_dir="$current_dir/$args"
                        fi
                        if [ -d "$new_dir" ]; then
                            current_dir=$(cd "$new_dir" && pwd)
                        else
                            echo -e "${YELLOW}⚠${NC}  Not found: $args"
                        fi
                    fi
                    ;;
                select|s)
                    # Save location for next time
                    echo "$current_dir" > "$last_dir_file"
                    
                    # Scan for repos
                    echo ""
                    echo -e "${DIM}Scanning for git repos...${NC}"
                    local found_repos=$(scan_directory "$current_dir")
                    
                    if [ -z "$found_repos" ]; then
                        echo -e "${YELLOW}⚠${NC}  No git repos found in $current_dir"
                        continue
                    fi
                    
                    # Build arrays for selection
                    local repo_names=()
                    local repo_paths=()
                    local repo_selected=()
                    
                    while IFS= read -r repo; do
                        if [ -n "$repo" ]; then
                            repo_names+=("$(echo "$repo" | cut -d'|' -f1)")
                            repo_paths+=("$(echo "$repo" | cut -d'|' -f2)")
                            repo_selected+=(0)  # All deselected by default - user picks what they want
                        fi
                    done <<< "$found_repos"
                    
                    # Interactive selection loop
                    while true; do
                        echo ""
                        echo -e "${BOLD}Found ${#repo_names[@]} repos in $current_dir:${NC}"
                        echo ""
                        for i in "${!repo_names[@]}"; do
                            local num=$((i+1))
                            # Calculate relative path from current_dir for disambiguation
                            local rel_path="${repo_paths[$i]#$current_dir/}"
                            local parent_path=$(dirname "$rel_path")
                            local display_suffix=""
                            if [ "$parent_path" != "." ] && [ -n "$parent_path" ]; then
                                display_suffix=" ${DIM}($parent_path/)${NC}"
                            fi
                            
                            if [ "${repo_selected[$i]}" = "1" ]; then
                                echo -e "  ${GREEN}$num)${NC} ${GREEN}✓${NC} ${repo_names[$i]}${display_suffix}"
                            else
                                echo -e "  ${DIM}$num) ${repo_names[$i]}${NC}${display_suffix}"
                            fi
                        done
                        echo ""
                        echo -e "${DIM}Commands: 1,3,5 (select) | all | none | except 1,2 | confirm | cancel${NC}"
                        echo -en "${MAGENTA}select>${NC} "
                        read -r sel_cmd sel_args
                        
                        case "$sel_cmd" in
                            toggle|t)
                                IFS=',' read -ra nums <<< "$sel_args"
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
                            all|a)
                                for i in "${!repo_selected[@]}"; do
                                    repo_selected[$i]=1
                                done
                                ;;
                            none|n)
                                for i in "${!repo_selected[@]}"; do
                                    repo_selected[$i]=0
                                done
                                ;;
                            except|x)
                                # Select all EXCEPT the specified numbers
                                for i in "${!repo_selected[@]}"; do
                                    repo_selected[$i]=1
                                done
                                IFS=',' read -ra nums <<< "$sel_args"
                                for n in "${nums[@]}"; do
                                    n=$(echo "$n" | tr -d ' ')
                                    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#repo_names[@]}" ]; then
                                        local idx=$((n-1))
                                        repo_selected[$idx]=0
                                    fi
                                done
                                ;;
                            confirm|ok|c|y)
                                # Add selected repos
                                local added=0
                                for i in "${!repo_names[@]}"; do
                                    if [ "${repo_selected[$i]}" = "1" ]; then
                                        all_repos+=("${repo_names[$i]}|${repo_paths[$i]}")
                                        ((added++))
                                    fi
                                done
                                if [ $added -gt 0 ]; then
                                    dirs+=("$current_dir")
                                    echo ""
                                    echo -e "${GREEN}✓${NC} Added $added repos from this directory"
                                    echo -e "${CYAN}Total repos selected: ${#all_repos[@]}${NC}"
                                    echo ""
                                    echo -e "${DIM}Continue browsing to add more, or type 'done' to finish${NC}"
                                else
                                    echo -e "${YELLOW}⚠${NC}  No repos selected"
                                fi
                                break
                                ;;
                            cancel|back|b|q)
                                echo -e "${DIM}Cancelled${NC}"
                                break
                                ;;
                            *)
                                # If input looks like numbers, treat as toggle
                                if [[ "$sel_cmd" =~ ^[0-9] ]]; then
                                    local input="$sel_cmd"
                                    [ -n "$sel_args" ] && input="$sel_cmd $sel_args"
                                    IFS=',' read -ra nums <<< "$input"
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
                                else
                                    echo -e "${YELLOW}⚠${NC}  Unknown: $sel_cmd"
                                fi
                                ;;
                        esac
                    done
                    ;;
                done|finish|next|q)
                    # Show summary before finishing
                    if [ ${#all_repos[@]} -gt 0 ]; then
                        echo ""
                        echo -e "${BOLD}📋 Final Selection (${#all_repos[@]} repos):${NC}"
                        echo ""
                        for repo in "${all_repos[@]}"; do
                            local rname=$(echo "$repo" | cut -d'|' -f1)
                            echo -e "  ${GREEN}✓${NC} $rname"
                        done
                        echo ""
                        echo -en "${YELLOW}?${NC} Confirm and create project? [Y/n]: "
                        read -r final_confirm
                        if [[ "$final_confirm" =~ ^[Nn] ]]; then
                            echo -e "${DIM}Cancelled. Continue browsing to modify selection.${NC}"
                            continue
                        fi
                    fi
                    adding=false
                    break
                    ;;
                "")
                    ;;
                *)
                    echo -e "${YELLOW}⚠${NC}  Unknown: $cmd (try: ls, cd, select, done)"
                    ;;
            esac
        done
    done
    
    if [ ${#dirs[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠${NC}  No directories added, project not created."
        return 1
    fi
    
    # Save project config
    mkdir -p "$CONTEXTS_DIR"
    printf '%s\n' "${dirs[@]}" > "$CONTEXTS_DIR/${safe_name}.dirs"
    printf '%s\n' "${all_repos[@]}" > "$CONTEXTS_DIR/${safe_name}.repos"
    
    # Generate workspace
    generate_workspace "$safe_name"
    
    # Regenerate "all" workspace to include new project
    regenerate_all_workspace
    
    # Update config.json
    if command -v python3 &> /dev/null; then
        python3 << EOF
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
projects = config.get('projects', [])
if '$safe_name' not in projects:
    projects.append('$safe_name')
    config['projects'] = projects
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(config, f, indent=2)
EOF
    fi
    
    echo ""
    echo -e "${GREEN}✓${NC}  Project \"$project_name\" created with ${#all_repos[@]} repos!"
    echo -e "${GREEN}✓${NC}  Workspace: ${safe_name}.code-workspace"
    
    # Generate architecture graph
    echo -e "${BLUE}▶${NC}  Generating architecture graph..."
    if "$SCRIPT_DIR/graph.sh" "$safe_name" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}  Graph: docs/${safe_name}/architecture.html"
    fi
    echo ""
    
    echo -en "${YELLOW}?${NC} Open this project now? [Y/n]: "
    read -r open_now
    
    if [[ ! "$open_now" =~ ^[nN] ]]; then
        echo -e "\n${GREEN}▶${NC} Opening ${BOLD}$safe_name${NC} workspace..."
        cursor "$WORKSPACES_DIR/${safe_name}.code-workspace"
        
        # Ask to view graph
        echo -en "${YELLOW}?${NC} View architecture graph in browser? [y/N]: "
        read -r view_graph
        if [[ "$view_graph" =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/graph.sh" "$safe_name" --view
        fi
    fi
    
    return 0
}

# Main menu
main() {
    print_banner
    echo -e "${BOLD}Select a project to open:${NC}\n"
    
    # Build list of workspaces
    local workspaces=()
    local ws_display=()
    
    for ws in "$WORKSPACES_DIR"/*.code-workspace; do
        if [ -f "$ws" ]; then
            ws_name=$(basename "$ws" .code-workspace)
            workspaces+=("$ws_name")
            
            # Count repos for display
            local repo_count=0
            local repos_file="$CONTEXTS_DIR/${ws_name}.repos"
            if [ -f "$repos_file" ]; then
                repo_count=$(wc -l < "$repos_file" | tr -d ' ')
            fi
            
            if [ "$ws_name" = "all" ]; then
                ws_display+=("all (all projects combined)")
            elif [ "$ws_name" = "none" ]; then
                ws_display+=("none (command center only)")
            else
                ws_display+=("$ws_name ($repo_count repos)")
            fi
        fi
    done
    
    if [ ${#workspaces[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠${NC}  No workspaces found. Run ./setup.sh to create some."
        exit 1
    fi
    
    # Add special options
    workspaces+=("__ADD_NEW__")
    ws_display+=("➕ Add new project group...")
    
    workspaces+=("__CANCEL__")
    ws_display+=("❌ Cancel")
    
    # Display menu
    local selected=""
    if $HAS_GUM; then
        selected=$(printf '%s\n' "${ws_display[@]}" | gum choose --header "Choose project:")
        # Extract workspace name from selection
        selected=$(echo "$selected" | cut -d' ' -f1)
    else
        local i=1
        for ws in "${ws_display[@]}"; do
            echo -e "  ${CYAN}$i)${NC} $ws"
            ((i++))
        done
        echo ""
        echo -en "${YELLOW}?${NC} Enter number: "
        read -r choice
        
        if [ -z "$choice" ] || ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${DIM}Cancelled.${NC}"
            exit 0
        fi
        
        local idx=$((choice-1))
        if [ $idx -lt 0 ] || [ $idx -ge ${#workspaces[@]} ]; then
            echo -e "${RED}Invalid selection.${NC}"
            exit 1
        fi
        
        selected="${workspaces[$idx]}"
    fi
    
    # Handle special options
    if [ "$selected" = "__ADD_NEW__" ] || [ "$selected" = "➕" ]; then
        add_new_project
        exit 0
    fi
    
    if [ "$selected" = "__CANCEL__" ] || [ "$selected" = "❌" ] || [ -z "$selected" ]; then
        echo -e "${DIM}Cancelled.${NC}"
        exit 0
    fi
    
    # Open the selected workspace
    local workspace_file="$WORKSPACES_DIR/${selected}.code-workspace"
    
    if [ ! -f "$workspace_file" ]; then
        echo -e "${RED}Workspace not found: $workspace_file${NC}"
        exit 1
    fi
    
    # Save as last workspace
    echo "$selected" > "$LAST_FILE"
    
    echo ""
    echo -e "${GREEN}▶${NC} Opening ${BOLD}$selected${NC} workspace..."
    echo -e "${DIM}$workspace_file${NC}"
    echo ""
    echo -e "${DIM}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}│${NC}  ${BOLD}💡 Tip:${NC} Use ${CYAN}@Codebase${NC} in your prompts to search all repos at once!   ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  Example: ${DIM}\"${NC}${GREEN}@Codebase${NC} where is the auth logic?${DIM}\"${NC}                        ${DIM}│${NC}"
    echo -e "${DIM}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    # Check if cursor command is available
    if ! command -v cursor &> /dev/null; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⚠${NC}  ${BOLD}Cursor CLI not found!${NC}"
        echo ""
        echo -e "To install it:"
        echo -e "  1. Open ${CYAN}Cursor${NC} app"
        echo -e "  2. Press ${CYAN}Cmd+Shift+P${NC} (Mac) or ${CYAN}Ctrl+Shift+P${NC} (Windows/Linux)"
        echo -e "  3. Type: ${GREEN}Shell Command: Install 'cursor' command in PATH${NC}"
        echo -e "  4. Run this script again"
        echo ""
        echo -e "${DIM}Or open manually: ${NC}${workspace_file}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 1
    fi
    
    cursor "$workspace_file"
}

main "$@"
