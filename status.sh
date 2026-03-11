#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     📊 Cursor Command Center Status                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.command-center"
CONTEXTS_DIR="$DATA_DIR/contexts"
CONFIG_FILE="$DATA_DIR/config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Flags
DO_PULL=false

# Counters
TOTAL_REPOS=0
CLEAN_REPOS=0
PULLED_REPOS=0
SKIPPED_REPOS=0

# Check if setup has been run
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠${NC}  Command Center hasn't been set up yet!"
    echo -e "${DIM}Run ./setup.sh first to configure your projects.${NC}"
    exit 1
fi

print_banner() {
    echo ""
    if [ "$DO_PULL" = true ]; then
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}         ${MAGENTA}📊 Repository Status + Pull${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}         ${MAGENTA}📊 Repository Status${NC}                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    fi
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
    
    local issues=()
    local is_clean=true
    local is_behind=false
    local behind_count=0
    
    # Check for uncommitted changes
    local changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$changes" -gt 0 ]; then
        issues+=("${YELLOW}$changes uncommitted${NC}")
        is_clean=false
    fi
    
    # Check if behind/ahead of remote
    git fetch --quiet 2>/dev/null
    local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    
    if [ "$behind" -gt 0 ]; then
        is_behind=true
        behind_count=$behind
        issues+=("${CYAN}↓ $behind behind${NC}")
    fi
    if [ "$ahead" -gt 0 ]; then
        issues+=("${GREEN}↑ $ahead ahead${NC}")
    fi
    
    # Check current branch
    local branch=$(git branch --show-current 2>/dev/null || echo "detached")
    
    # Handle --pull flag
    if [ "$DO_PULL" = true ] && [ "$is_behind" = true ]; then
        if [ "$is_clean" = true ]; then
            # Safe to pull - no uncommitted changes
            echo -en "  ${CYAN}↓${NC} $repo_name ${DIM}($branch)${NC} - pulling $behind_count commits... "
            if git pull --quiet 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((PULLED_REPOS++))
                return
            else
                echo -e "${RED}failed${NC}"
                ((SKIPPED_REPOS++))
                return
            fi
        else
            # Has uncommitted changes - skip
            local issue_str=$(IFS=', '; echo "${issues[*]}")
            echo -e "  ${YELLOW}⚠${NC} $repo_name ${DIM}($branch)${NC} - $issue_str ${DIM}(skipped: uncommitted changes)${NC}"
            ((SKIPPED_REPOS++))
            return
        fi
    fi
    
    # Build normal output
    if [ ${#issues[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $repo_name ${DIM}($branch)${NC}"
        ((CLEAN_REPOS++))
    else
        local issue_str=$(IFS=', '; echo "${issues[*]}")
        echo -e "  ${YELLOW}⚠${NC} $repo_name ${DIM}($branch)${NC} - $issue_str"
    fi
}

# Main
main() {
    local project_filter=""
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --pull|-p)
                DO_PULL=true
                ;;
            --help|-h)
                return
                ;;
            *)
                project_filter="$arg"
                ;;
        esac
    done
    
    print_banner
    
    # Check if specific project was requested
    if [ -n "$project_filter" ]; then
        local repos_file="$CONTEXTS_DIR/${project_filter}.repos"
        if [ ! -f "$repos_file" ]; then
            echo -e "${RED}✗${NC} Project '$project_filter' not found."
            exit 1
        fi
        
        echo -e "${BOLD}$project_filter:${NC}"
        echo ""
        
        while IFS= read -r repo_entry; do
            if [ -n "$repo_entry" ]; then
                repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                check_repo "$repo_path" "$repo_name"
                ((TOTAL_REPOS++))
            fi
        done < "$repos_file"
    else
        # Check all projects
        for repos_file in "$CONTEXTS_DIR"/*.repos; do
            if [ -f "$repos_file" ]; then
                local project_name=$(basename "$repos_file" .repos)
                [ "$project_name" = "all" ] && continue
                [ "$project_name" = "none" ] && continue
                
                echo -e "${BOLD}${MAGENTA}$project_name:${NC}"
                echo ""
                
                while IFS= read -r repo_entry; do
                    if [ -n "$repo_entry" ]; then
                        repo_name=$(echo "$repo_entry" | cut -d'|' -f1)
                        repo_path=$(echo "$repo_entry" | cut -d'|' -f2)
                        check_repo "$repo_path" "$repo_name"
                        ((TOTAL_REPOS++))
                    fi
                done < "$repos_file"
                
                echo ""
            fi
        done
    fi
    
    echo -e "${DIM}───────────────────────────────────────────────────────────────${NC}"
    if [ "$DO_PULL" = true ]; then
        echo -e "${DIM}Total: $TOTAL_REPOS repos | ${GREEN}$PULLED_REPOS pulled${NC}${DIM} | ${YELLOW}$SKIPPED_REPOS skipped${NC}"
    else
        echo -e "${DIM}Total: $TOTAL_REPOS repos checked${NC}"
    fi
    echo ""
}

# Handle help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: ./status.sh [project] [options]"
    echo ""
    echo "Check git status of all repositories."
    echo ""
    echo "Options:"
    echo "  [project]     Check only repos in this project group"
    echo "  --pull, -p    Auto-pull repos that are behind (if clean)"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Examples:"
    echo "  ./status.sh              # Check all repos"
    echo "  ./status.sh backend      # Check only backend repos"
    echo "  ./status.sh --pull       # Check and pull clean repos"
    echo "  ./status.sh backend --pull  # Pull only backend repos"
    echo ""
    echo "Note: --pull only updates repos with NO uncommitted changes."
    echo "      Repos with local changes are skipped (safe)."
    exit 0
fi

main "$@"
