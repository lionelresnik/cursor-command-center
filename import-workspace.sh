#!/bin/bash

# Import existing .code-workspace files into Command Center
# Adds ~/.command-center/ to the workspace and moves the file to central location

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.command-center"
WORKSPACES_DIR="$DATA_DIR/workspaces"
CONTEXTS_DIR="$DATA_DIR/contexts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   ${BOLD}Import Workspace to Command Center${NC}   ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${DIM}$1${NC}"; }

import_workspace() {
    local source_file="$1"
    
    # Expand ~ if present
    source_file="${source_file/#\~/$HOME}"
    
    # Check if file exists
    if [ ! -f "$source_file" ]; then
        print_error "File not found: $source_file"
        return 1
    fi
    
    # Check if it's a .code-workspace file
    if [[ ! "$source_file" == *.code-workspace ]]; then
        print_error "Not a workspace file (must end with .code-workspace)"
        return 1
    fi
    
    # Get workspace name from filename
    local filename
    filename=$(basename "$source_file")
    local workspace_name="${filename%.code-workspace}"
    
    # Check if already exists in Command Center
    local dest_file="$WORKSPACES_DIR/$filename"
    if [ -f "$dest_file" ]; then
        echo -e "${YELLOW}!${NC} Workspace '${BOLD}$workspace_name${NC}' already exists in Command Center"
        echo -en "${YELLOW}?${NC} Overwrite? [y/N]: "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            echo -e "${DIM}Skipped.${NC}"
            return 0
        fi
    fi
    
    # Ensure directories exist
    mkdir -p "$WORKSPACES_DIR" "$CONTEXTS_DIR"
    
    # Read current workspace content
    local content
    content=$(cat "$source_file")
    
    # Check if ~/.command-center/ is already in the workspace
    if echo "$content" | grep -q "\.command-center"; then
        print_info "Workspace already includes Command Center"
    else
        # Add ~/.command-center/ as the first folder
        echo -e "${BLUE}→${NC} Adding Command Center to workspace..."
        
        # Use jq if available, otherwise use sed
        if command -v jq &> /dev/null; then
            content=$(echo "$content" | jq '.folders = [{"name": "Command Center", "path": "'"$DATA_DIR"'"}] + .folders')
        else
            # Fallback: insert after "folders": [
            content=$(echo "$content" | sed 's/"folders"[[:space:]]*:[[:space:]]*\[/"folders": [\n    { "name": "Command Center", "path": "'"${DATA_DIR//\//\\/}"'" },/')
        fi
    fi
    
    # Write to destination
    echo "$content" > "$dest_file"
    print_success "Workspace saved to: $dest_file"
    
    # Extract repo paths and create .repos file
    local repos_file="$CONTEXTS_DIR/$workspace_name.repos"
    echo -e "${BLUE}→${NC} Creating repo index..."
    
    # Extract paths from workspace file (excluding Command Center)
    if command -v jq &> /dev/null; then
        echo "$content" | jq -r '.folders[] | select(.path != "'"$DATA_DIR"'") | "\(.name // (.path | split("/") | .[-1]))|\(.path)"' > "$repos_file"
    else
        # Fallback: grep for paths
        grep -oE '"path"[[:space:]]*:[[:space:]]*"[^"]+"' "$dest_file" | \
            grep -v "command-center" | \
            sed 's/"path"[[:space:]]*:[[:space:]]*"//' | \
            sed 's/"$//' | \
            while read -r path; do
                local name
                name=$(basename "$path")
                echo "$name|$path"
            done > "$repos_file"
    fi
    
    local repo_count
    repo_count=$(wc -l < "$repos_file" | tr -d ' ')
    print_success "Indexed $repo_count repos in: $repos_file"
    
    # Ask about original file
    if [ "$source_file" != "$dest_file" ]; then
        echo ""
        echo -e "${YELLOW}?${NC} What to do with the original file?"
        echo "    1) Keep it (you'll have two copies)"
        echo "    2) Delete it (use Command Center copy only)"
        echo -en "    Choice [1]: "
        read -r choice
        
        if [ "$choice" = "2" ]; then
            rm "$source_file"
            print_success "Deleted original: $source_file"
        else
            print_info "Original kept at: $source_file"
        fi
    fi
    
    echo ""
    print_success "Workspace '${BOLD}$workspace_name${NC}' imported!"
    echo ""
    echo -e "Open it with: ${BOLD}cc open $workspace_name${NC}"
    echo -e "Or run:       ${BOLD}cursor $dest_file${NC}"
}

scan_for_workspaces() {
    print_banner
    echo -e "${BOLD}Scanning for existing workspaces...${NC}\n"
    
    local found=()
    local search_dirs=("$HOME/Projects" "$HOME/Workspaces" "$HOME/Code" "$HOME/Developer" "$HOME")
    
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' file; do
                # Skip if already in Command Center
                if [[ "$file" == *"/.command-center/"* ]]; then
                    continue
                fi
                found+=("$file")
            done < <(find "$dir" -maxdepth 3 -name "*.code-workspace" -print0 2>/dev/null)
        fi
    done
    
    if [ ${#found[@]} -eq 0 ]; then
        echo -e "${DIM}No workspace files found outside Command Center.${NC}"
        echo ""
        echo "You can create a new workspace with: ${BOLD}cc setup${NC}"
        return 0
    fi
    
    echo -e "Found ${BOLD}${#found[@]}${NC} workspace file(s):\n"
    
    local i=1
    for file in "${found[@]}"; do
        local name
        name=$(basename "$file" .code-workspace)
        echo -e "  ${BOLD}$i)${NC} $name"
        echo -e "     ${DIM}$file${NC}"
        ((i++))
    done
    
    echo ""
    echo -e "  ${BOLD}a)${NC} Import all"
    echo -e "  ${BOLD}q)${NC} Cancel"
    echo ""
    echo -en "${YELLOW}?${NC} Which to import? (e.g., 1,3 or 1-3 or 'a' for all): "
    read -r selection
    
    if [ "$selection" = "q" ] || [ -z "$selection" ]; then
        echo -e "${DIM}Cancelled.${NC}"
        return 0
    fi
    
    local to_import=()
    
    if [ "$selection" = "a" ] || [ "$selection" = "all" ]; then
        to_import=("${found[@]}")
    else
        # Parse selection (supports: 1,3,5 or 1-3 or 1,3-5)
        IFS=',' read -ra parts <<< "$selection"
        for part in "${parts[@]}"; do
            if [[ "$part" == *-* ]]; then
                local start end
                start=$(echo "$part" | cut -d'-' -f1)
                end=$(echo "$part" | cut -d'-' -f2)
                for ((j=start; j<=end; j++)); do
                    if [ $j -ge 1 ] && [ $j -le ${#found[@]} ]; then
                        to_import+=("${found[$((j-1))]}")
                    fi
                done
            else
                if [ "$part" -ge 1 ] 2>/dev/null && [ "$part" -le ${#found[@]} ]; then
                    to_import+=("${found[$((part-1))]}")
                fi
            fi
        done
    fi
    
    if [ ${#to_import[@]} -eq 0 ]; then
        echo -e "${RED}✗${NC} No valid selection"
        return 1
    fi
    
    echo ""
    for file in "${to_import[@]}"; do
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        import_workspace "$file"
    done
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_success "Import complete!"
    echo ""
    echo "Your workspaces are now in: ${BOLD}~/.command-center/workspaces/${NC}"
    echo "Open any with: ${BOLD}cc open <name>${NC}"
}

# Main
case "${1:-}" in
    --scan|-s|scan)
        scan_for_workspaces
        ;;
    --help|-h|help)
        echo "Usage: cc import-workspace [options] [file]"
        echo ""
        echo "Import existing .code-workspace files into Command Center."
        echo "Adds ~/.command-center/ to the workspace for sidebar access."
        echo ""
        echo "Options:"
        echo "  --scan, -s    Scan common directories for workspace files"
        echo "  --help, -h    Show this help"
        echo ""
        echo "Examples:"
        echo "  cc import-workspace ~/Projects/my-app.code-workspace"
        echo "  cc import-workspace --scan"
        ;;
    "")
        scan_for_workspaces
        ;;
    *)
        print_banner
        import_workspace "$1"
        ;;
esac
