#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     📊 Cursor Command Center Status                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXTS_DIR="$SCRIPT_DIR/contexts"
CONFIG_FILE="$SCRIPT_DIR/config.json"

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

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${MAGENTA}📊 Repository Status${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check a single repo's status
check_repo() {
    local repo_path="$1"
    local repo_name="$2"
    
    if [ ! -d "$repo_path/.git" ]; then
        echo -e "  ${RED}✗${NC} $repo_name ${DIM}(not a git repo)${NC}"
        return
    fi
    
    cd "$repo_path" || return
    
    local status_line=""
    local issues=()
    
    # Check for uncommitted changes
    local changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$changes" -gt 0 ]; then
        issues+=("${YELLOW}$changes uncommitted${NC}")
    fi
    
    # Check if behind/ahead of remote
    git fetch --quiet 2>/dev/null
    local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    
    if [ "$behind" -gt 0 ]; then
        issues+=("${CYAN}↓ $behind behind${NC}")
    fi
    if [ "$ahead" -gt 0 ]; then
        issues+=("${GREEN}↑ $ahead ahead${NC}")
    fi
    
    # Check current branch
    local branch=$(git branch --show-current 2>/dev/null || echo "detached")
    
    # Build output
    if [ ${#issues[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $repo_name ${DIM}($branch)${NC}"
    else
        local issue_str=$(IFS=', '; echo "${issues[*]}")
        echo -e "  ${YELLOW}⚠${NC} $repo_name ${DIM}($branch)${NC} - $issue_str"
    fi
}

# Main
main() {
    print_banner
    
    local total_repos=0
    local clean_repos=0
    
    # Check if specific project was requested
    if [ -n "$1" ]; then
        local repos_file="$CONTEXTS_DIR/${1}.repos"
        if [ ! -f "$repos_file" ]; then
            echo -e "${RED}✗${NC} Project '$1' not found."
            exit 1
        fi
        
        echo -e "${BOLD}$1:${NC}"
        echo ""
        
        while IFS= read -r repo_entry; do
            if [ -n "$repo_entry" ]; then
                repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                check_repo "$repo_path" "$repo_name"
                ((total_repos++))
            fi
        done < "$repos_file"
    else
        # Check all projects
        for repos_file in "$CONTEXTS_DIR"/*.repos; do
            if [ -f "$repos_file" ]; then
                local project_name=$(basename "$repos_file" .repos)
                
                echo -e "${BOLD}${MAGENTA}$project_name:${NC}"
                echo ""
                
                while IFS= read -r repo_entry; do
                    if [ -n "$repo_entry" ]; then
                        repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                        repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                        check_repo "$repo_path" "$repo_name"
                        ((total_repos++))
                    fi
                done < "$repos_file"
                
                echo ""
            fi
        done
    fi
    
    echo -e "${DIM}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${DIM}Total: $total_repos repos checked${NC}"
    echo ""
}

# Handle help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: ./status.sh [project]"
    echo ""
    echo "Check git status of all repositories."
    echo ""
    echo "Options:"
    echo "  [project]     Check only repos in this project group"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Examples:"
    echo "  ./status.sh         # Check all repos"
    echo "  ./status.sh backend # Check only backend repos"
    exit 0
fi

main "$@"

