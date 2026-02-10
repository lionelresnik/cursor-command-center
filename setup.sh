#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     🚀 Cursor Command Center Setup                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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

clear_screen() {
    printf "\033c"
}

print_banner() {
    clear_screen
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${MAGENTA}█▀▀ █░█ █▀█ █▀ █▀█ █▀█   ${YELLOW}█▀▀ █▀█ █▀▄▀█ █▀▄▀█ ▄▀█ █▄░█ █▀▄${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${MAGENTA}█▄▄ █▄█ █▀▄ ▄█ █▄█ █▀▄   ${YELLOW}█▄▄ █▄█ █░▀░█ █░▀░█ █▀█ █░▀█ █▄▀${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           ${DIM}Your AI-Powered Multi-Repo Development Hub${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() {
    echo -e "${CYAN}ℹ${NC}  $1"
}

print_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

prompt_confirm() {
    local prompt="$1"
    echo -en "${YELLOW}?${NC} $prompt ${DIM}[Y/n]${NC}: " >&2
    read -r response
    case "$response" in
        [nN][oO]|[nN]) echo "no" ;;
        *) echo "yes" ;;
    esac
}

press_enter_to_continue() {
    echo ""
    echo -en "${DIM}Press Enter to continue...${NC}"
    read -r
}

show_intro() {
    # Screen 1: Welcome & Banner
    print_banner
    
    echo -e "${BOLD}Welcome! This wizard will set up your Cursor Command Center.${NC}"
    
    press_enter_to_continue
    
    # Screen 2: What is it? (keep previous content visible)
    echo ""
    echo -e "${DIM}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}│${NC}  ${BOLD}What is Cursor Command Center?${NC}                                        ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${GREEN}●${NC} A central hub to manage multiple repositories                      ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${GREEN}●${NC} Super-fast @Codebase search across all your projects                ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${GREEN}●${NC} Project groups for focused work (e.g., \"Backend\", \"Frontend\")       ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${GREEN}●${NC} Task history to track what you've done                              ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${GREEN}●${NC} Shared rules across all your AI conversations                       ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    
    press_enter_to_continue
    
    # Screen 3: What will happen? (keep previous content visible)
    echo ""
    echo -e "${DIM}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}│${NC}  ${BOLD}What will happen:${NC}                                                      ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${CYAN}1.${NC} You'll define your project groups (e.g., \"Backend\", \"Frontend\")     ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${CYAN}2.${NC} For each group, you'll browse and add directories                   ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${CYAN}3.${NC} We'll generate workspace files for each project                     ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${CYAN}4.${NC} Use ./open.sh to quickly switch between projects                    ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${YELLOW}⚠${NC}  We will ${BOLD}NOT${NC} modify any of your existing repositories              ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    if [ "$(prompt_confirm "Ready to start?")" = "no" ]; then
        echo -e "\n${DIM}Setup cancelled. Run ./setup.sh when you're ready.${NC}"
        exit 0
    fi
}

# Interactive directory browser - writes result to BROWSE_RESULT variable
browse_directories() {
    local current_dir="${HOME}"
    BROWSE_RESULT=""
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}📁 Directory Browser${NC}                                        ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}ls${NC}        - List directories                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}cd <dir>${NC}  - Go to directory                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}cd ..${NC}     - Go up                                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}select${NC}    - ✓ Choose current directory                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${GREEN}cancel${NC}    - Go back                                       ${CYAN}║${NC}"
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
                            echo -e "  ${BLUE}📁 $name${NC}"
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
            pwd|p)
                echo -e "${CYAN}$current_dir${NC}"
                ;;
            select|s|done|ok|.)
                BROWSE_RESULT="$current_dir"
                echo ""
                return 0
                ;;
            cancel|c|q|exit)
                BROWSE_RESULT="CANCEL"
                echo ""
                return 1
                ;;
            "")
                ;;
            *)
                echo -e "${YELLOW}⚠${NC}  Unknown: $cmd (try: ls, cd, select, cancel)"
                ;;
        esac
    done
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

# Add a single project group - sets ADD_PROJECT_RESULT
add_project_group() {
    local project_name="$1"
    local is_first="$2"
    ADD_PROJECT_RESULT=""
    
    if [ -z "$project_name" ]; then
        if [ "$is_first" = "true" ]; then
            echo -en "${YELLOW}?${NC} ${BOLD}Project group name${NC} (e.g., Backend, Frontend): "
        else
            echo -e ""
            echo -e "${DIM}───────────────────────────────────────────────────────────────${NC}"
            echo -e "Add another project group, or type ${GREEN}done${NC} to finish setup."
            echo -e ""
            echo -en "${YELLOW}?${NC} ${BOLD}Project group name:${NC} "
        fi
        read -r project_name
        
        if [ "$project_name" = "done" ] || [ -z "$project_name" ]; then
            if [ "$is_first" = "true" ]; then
                echo -e "${YELLOW}⚠${NC}  Please enter at least one project group name."
                ADD_PROJECT_RESULT="SKIP"
                return
            fi
            ADD_PROJECT_RESULT="DONE"
            return
        fi
        
        # Validate name (no spaces or special characters)
        if [[ "$project_name" =~ [^a-zA-Z0-9_-] ]]; then
            echo -e "${RED}✗${NC} Name can only contain letters, numbers, hyphens, and underscores"
            echo -e "${DIM}   Example: supply-chain, backend_api, Frontend${NC}"
            ADD_PROJECT_RESULT="SKIP"
            return
        fi
    fi
    
    # Normalize to lowercase
    local safe_name=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')
    
    echo ""
    echo -e "${CYAN}━━━ Adding directories for \"${BOLD}$project_name${NC}${CYAN}\" ━━━${NC}"
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
                                echo -e "  ${BLUE}📁 $name${NC}"
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
                pwd|p)
                    echo -e "${CYAN}$current_dir${NC}"
                    ;;
                select|s)
                    # Save location for next time
                    echo "$current_dir" > "$last_dir_file"
                    
                    # Scan for repos
                    echo ""
                    echo -e "${DIM}Scanning for git repos...${NC}"
                    
                    local repo_names=()
                    local repo_paths=()
                    local repo_selected=()
                    
                    while IFS= read -r -d '' git_dir; do
                        repo_path=$(dirname "$git_dir")
                        repo_name=$(basename "$repo_path")
                        repo_names+=("$repo_name")
                        repo_paths+=("$repo_path")
                        repo_selected+=(0)  # All deselected by default - user picks what they want
                    done < <(find "$current_dir" -maxdepth 5 -name ".git" -type d -print0 2>/dev/null)
                    
                    if [ ${#repo_names[@]} -eq 0 ]; then
                        print_warning "No git repos found in $current_dir"
                        continue
                    fi
                    
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
                                    print_warning "No repos selected"
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
                done|finish|next|skip|q)
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
                        echo -en "${YELLOW}?${NC} Confirm and continue? [Y/n]: "
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
        print_warning "No directories added for $project_name, skipping."
        ADD_PROJECT_RESULT="SKIP"
        return
    fi
    
    # Save project config
    mkdir -p "$CONTEXTS_DIR"
    
    # Save directories
    printf '%s\n' "${dirs[@]}" > "$CONTEXTS_DIR/${safe_name}.dirs"
    
    # Save repos
    printf '%s\n' "${all_repos[@]}" > "$CONTEXTS_DIR/${safe_name}.repos"
    
    print_success "Project \"$project_name\" configured with ${#all_repos[@]} repos"
    
    ADD_PROJECT_RESULT="$safe_name"
}

# Generate workspace file for a project
generate_workspace() {
    local project_name="$1"
    local workspace_file="$WORKSPACES_DIR/${project_name}.code-workspace"
    
    mkdir -p "$WORKSPACES_DIR"
    
    # Start JSON
    echo '{' > "$workspace_file"
    echo '  "folders": [' >> "$workspace_file"
    echo '    { "name": "📁 Command Center", "path": ".." }' >> "$workspace_file"
    
    local repos_file="$CONTEXTS_DIR/${project_name}.repos"
    
    if [ -f "$repos_file" ] && [ "$project_name" != "none" ]; then
        while IFS= read -r repo_entry; do
            if [ -n "$repo_entry" ]; then
                repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                
                # Calculate relative path
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

# Generate "all" workspace combining all projects
generate_all_workspace() {
    local projects=("$@")
    local workspace_file="$WORKSPACES_DIR/all.code-workspace"
    
    echo '{' > "$workspace_file"
    echo '  "folders": [' >> "$workspace_file"
    echo '    { "name": "📁 Command Center", "path": ".." }' >> "$workspace_file"
    
    local seen_repos=""
    
    for project in "${projects[@]}"; do
        local repos_file="$CONTEXTS_DIR/${project}.repos"
        if [ -f "$repos_file" ]; then
            while IFS= read -r repo_entry; do
                if [ -n "$repo_entry" ]; then
                    repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                    repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                    
                    # Skip if already added (dedupe)
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

# Generate "none" workspace (command center only)
generate_none_workspace() {
    local workspace_file="$WORKSPACES_DIR/none.code-workspace"
    
    cat > "$workspace_file" << 'EOF'
{
  "folders": [
    { "name": "📁 Command Center", "path": ".." }
  ],
  "settings": {
    "files.exclude": {
      "**/node_modules": true,
      "**/.git": true,
      "**/vendor": true
    }
  }
}
EOF
}

save_config() {
    local projects=("$@")
    
    # Create JSON config
    cat > "$CONFIG_FILE" << EOF
{
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "2.0.0",
  "projects": [$(printf '"%s",' "${projects[@]}" | sed 's/,$//')]
}
EOF
}

show_completion() {
    print_banner
    
    echo -e "${GREEN}${BOLD}✓ Setup Complete!${NC}\n"
    
    echo -e "${DIM}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}│${NC}  ${BOLD}Your Project Workspaces:${NC}                                              ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    
    for ws in "$WORKSPACES_DIR"/*.code-workspace; do
        if [ -f "$ws" ]; then
            ws_name=$(basename "$ws" .code-workspace)
            local repo_count=0
            local repos_file="$CONTEXTS_DIR/${ws_name}.repos"
            if [ -f "$repos_file" ]; then
                repo_count=$(wc -l < "$repos_file" | tr -d ' ')
            fi
            if [ "$ws_name" = "all" ]; then
                echo -e "${DIM}│${NC}    ${GREEN}●${NC} all        - All projects combined                            ${DIM}│${NC}"
            elif [ "$ws_name" = "none" ]; then
                echo -e "${DIM}│${NC}    ${GREEN}●${NC} none       - Command center only (no repos)                   ${DIM}│${NC}"
            else
                printf "${DIM}│${NC}    ${GREEN}●${NC} %-10s - %d repos                                          ${DIM}│${NC}\n" "$ws_name" "$repo_count"
            fi
        fi
    done
    
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    echo -e "${DIM}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}│${NC}  ${BOLD}Quick Start:${NC}                                                          ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}    ${GREEN}\$ ./open.sh${NC}                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  This will let you select a project and open it in Cursor.             ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${DIM}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}│${NC}  ${BOLD}💡 Pro Tip:${NC}                                                            ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  Use ${CYAN}@Codebase${NC} in your prompts to search across ALL your repos:        ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}    ${DIM}\"${NC}${GREEN}@Codebase${NC} where is the authentication logic?${DIM}\"${NC}                   ${DIM}│${NC}"
    echo -e "${DIM}│${NC}    ${DIM}\"${NC}${GREEN}@Codebase${NC} how does the API handle errors?${DIM}\"${NC}                      ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    # Generate architecture graphs for all workspaces
    echo -e "${BLUE}▶${NC} Generating architecture graphs..."
    for ws in "$WORKSPACES_DIR"/*.code-workspace; do
        if [ -f "$ws" ]; then
            ws_name=$(basename "$ws" .code-workspace)
            [ "$ws_name" = "all" ] && continue
            [ "$ws_name" = "none" ] && continue
            
            if [ -f "$CONTEXTS_DIR/${ws_name}.repos" ]; then
                "$SCRIPT_DIR/graph.sh" "$ws_name" >/dev/null 2>&1 && \
                    echo -e "  ${GREEN}✓${NC} Generated graph for ${BOLD}$ws_name${NC}" || \
                    echo -e "  ${YELLOW}⚠${NC} Could not generate graph for $ws_name"
            fi
        fi
    done
    echo ""
    
    # Ask if user wants to view a graph
    echo -en "${MAGENTA}?${NC} View an architecture graph now? [y/N]: "
    read -r view_graph
    if [[ "$view_graph" =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/graph.sh" --open
    fi
    echo ""
    
    echo -e "${CYAN}Happy coding! 🚀${NC}\n"
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    mkdir -p "$CONTEXTS_DIR" "$WORKSPACES_DIR"
    
    show_intro
    
    print_step "Define Your Project Groups"
    
    echo -e "A ${BOLD}project group${NC} is a collection of related repositories."
    echo -e ""
    echo -e "${DIM}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${DIM}│${NC}  ${BOLD}Example workflow:${NC}                                                       ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${YELLOW}?${NC} Project group name: ${GREEN}Backend${NC}                                        ${DIM}│${NC}"
    echo -e "${DIM}│${NC}      ${DIM}→ Browse to ~/Projects/backend${NC}                                     ${DIM}│${NC}"
    echo -e "${DIM}│${NC}      ${DIM}→ Type${NC} ${GREEN}select${NC} ${DIM}to add it (finds all repos inside)${NC}               ${DIM}│${NC}"
    echo -e "${DIM}│${NC}      ${DIM}→ Type${NC} ${GREEN}done${NC} ${DIM}to finish this project group${NC}                       ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}│${NC}  ${YELLOW}?${NC} Project group name: ${GREEN}done${NC}  ${DIM}← when finished with ALL groups${NC}        ${DIM}│${NC}"
    echo -e "${DIM}│${NC}                                                                         ${DIM}│${NC}"
    echo -e "${DIM}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    echo -e ""
    echo -e "${CYAN}Let's create your first project group:${NC}"
    echo -e ""
    
    local projects=()
    local is_first="true"
    
    while true; do
        # Call function directly (not in subshell) - it sets ADD_PROJECT_RESULT
        add_project_group "" "$is_first"
        
        if [ "$ADD_PROJECT_RESULT" = "DONE" ]; then
            break
        elif [ "$ADD_PROJECT_RESULT" = "SKIP" ]; then
            continue
        elif [ -n "$ADD_PROJECT_RESULT" ]; then
            projects+=("$ADD_PROJECT_RESULT")
            is_first="false"
        fi
        
        echo ""
    done
    
    if [ ${#projects[@]} -eq 0 ]; then
        print_warning "No projects configured. Run ./setup.sh again to add projects."
        exit 1
    fi
    
    print_step "Generating Workspace Files"
    
    # Generate individual project workspaces
    for project in "${projects[@]}"; do
        generate_workspace "$project"
        print_success "Created: ${project}.code-workspace"
    done
    
    # Generate "all" workspace
    generate_all_workspace "${projects[@]}"
    print_success "Created: all.code-workspace (all projects combined)"
    
    # Generate "none" workspace
    generate_none_workspace
    print_success "Created: none.code-workspace (command center only)"
    
    # Save config
    save_config "${projects[@]}"
    
    show_completion
}

main "$@"
