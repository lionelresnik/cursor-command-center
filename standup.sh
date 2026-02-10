#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                   📋 Cursor Command Center Standup                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODOS_FILE="$SCRIPT_DIR/todos.md"
STANDUPS_DIR="$SCRIPT_DIR/standups"
TASK_HISTORY_DIR="$SCRIPT_DIR/task-history"

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

mkdir -p "$STANDUPS_DIR"

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${MAGENTA}📋 Cursor Command Center Standup${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

collect_done_items() {
    if [ ! -f "$TODOS_FILE" ]; then return; fi
    local in_section=false
    while IFS= read -r line; do
        case "$line" in
            "## Done"*) in_section=true; continue ;;
            "## "*) in_section=false ;;
        esac
        if $in_section && echo "$line" | grep -q '^\- \[x\]' 2>/dev/null; then
            echo "$line"
        fi
    done < "$TODOS_FILE"
}

collect_in_progress() {
    if [ ! -f "$TODOS_FILE" ]; then return; fi
    local in_section=false
    while IFS= read -r line; do
        case "$line" in
            "## In Progress"*) in_section=true; continue ;;
            "## "*) in_section=false ;;
        esac
        if $in_section && echo "$line" | grep -q '^\- \[' 2>/dev/null; then
            echo "$line"
        fi
    done < "$TODOS_FILE"
}

collect_pending() {
    if [ ! -f "$TODOS_FILE" ]; then return; fi
    local in_section=false
    local count=0
    while IFS= read -r line; do
        case "$line" in
            "## Pending"*) in_section=true; continue ;;
            "## "*) in_section=false ;;
        esac
        if $in_section && echo "$line" | grep -q '^\- \[' 2>/dev/null; then
            count=$((count + 1))
            [ $count -le 5 ] && echo "$line"
        fi
    done < "$TODOS_FILE"
}

collect_recent_tasks() {
    local days="$1"
    if [ ! -d "$TASK_HISTORY_DIR" ]; then return; fi

    local cutoff
    if date -v -"${days}"d "+%s" >/dev/null 2>&1; then
        cutoff=$(date -v -"${days}"d "+%s")
    else
        cutoff=$(date -d "$days days ago" "+%s" 2>/dev/null || echo "0")
    fi

    find "$TASK_HISTORY_DIR" -name "*.md" -not -name "README.md" 2>/dev/null | while read -r f; do
        local mod_ts
        if stat -f "%m" "$f" >/dev/null 2>&1; then
            mod_ts=$(stat -f "%m" "$f")
        else
            mod_ts=$(stat -c "%Y" "$f" 2>/dev/null || echo "0")
        fi
        if [ "$mod_ts" -ge "$cutoff" ] 2>/dev/null; then
            local ws=$(basename "$(dirname "$f")")
            local name=$(basename "$f" .md)
            echo "[$ws] $name"
        fi
    done
}

format_item() {
    echo "$1" | sed 's/^- \[.\] //' | sed 's/ `#[^`]*`//g' | sed 's/ _(completed [^)]*)//'
}

generate_daily() {
    local today=$(date "+%Y-%m-%d")
    local day_name=$(date "+%A, %B %d, %Y")
    local output_file="$STANDUPS_DIR/$today.md"

    print_banner
    echo -e "${BOLD}Daily Standup — $day_name${NC}"
    echo ""

    local content="# Standup — $day_name"
    content="$content"$'\n'

    # Done items
    content="$content"$'\n'"## Done"
    local done_items=$(collect_done_items)
    local has_done=false
    if [ -n "$done_items" ]; then
        while IFS= read -r item; do
            local text=$(format_item "$item")
            content="$content"$'\n'"- $text"
            echo -e "  ${GREEN}✓${NC} $text"
            has_done=true
        done <<< "$done_items"
    fi
    if ! $has_done; then
        content="$content"$'\n'"- (no completed items)"
        echo -e "  ${DIM}(no completed items)${NC}"
    fi

    echo ""

    # In progress
    content="$content"$'\n'$'\n'"## In Progress"
    local ip_items=$(collect_in_progress)
    local has_ip=false
    if [ -n "$ip_items" ]; then
        while IFS= read -r item; do
            local text=$(format_item "$item")
            content="$content"$'\n'"- $text"
            echo -e "  ${YELLOW}→${NC} $text"
            has_ip=true
        done <<< "$ip_items"
    fi
    if ! $has_ip; then
        content="$content"$'\n'"- (nothing in progress)"
        echo -e "  ${DIM}(nothing in progress)${NC}"
    fi

    echo ""

    # Up next
    content="$content"$'\n'$'\n'"## Up Next"
    local pending_items=$(collect_pending)
    local has_pending=false
    if [ -n "$pending_items" ]; then
        while IFS= read -r item; do
            local text=$(format_item "$item")
            content="$content"$'\n'"- $text"
            echo -e "  ${CYAN}○${NC} $text"
            has_pending=true
        done <<< "$pending_items"
    fi
    if ! $has_pending; then
        content="$content"$'\n'"- (backlog clear)"
        echo -e "  ${DIM}(backlog clear)${NC}"
    fi

    echo ""

    # Recent task files
    local recent=$(collect_recent_tasks 1)
    if [ -n "$recent" ]; then
        content="$content"$'\n'$'\n'"## Recent Task Activity"
        while IFS= read -r task; do
            content="$content"$'\n'"- $task"
        done <<< "$recent"
    fi

    echo "$content" > "$output_file"
    echo -e "${GREEN}✓${NC}  Saved to ${DIM}standups/$today.md${NC}"
    echo ""
}

generate_weekly() {
    local today=$(date "+%Y-%m-%d")
    local week_num=$(date "+%V")
    local year=$(date "+%Y")
    local output_file="$STANDUPS_DIR/$year-W$week_num.md"

    print_banner
    echo -e "${BOLD}Weekly Recap — Week $week_num, $year${NC}"
    echo ""

    local content="# Weekly Recap — Week $week_num, $year"
    content="$content"$'\n'

    # Done items
    content="$content"$'\n'"## Completed"
    local done_items=$(collect_done_items)
    local done_count=0
    if [ -n "$done_items" ]; then
        while IFS= read -r item; do
            local text=$(format_item "$item")
            content="$content"$'\n'"- $text"
            echo -e "  ${GREEN}✓${NC} $text"
            done_count=$((done_count + 1))
        done <<< "$done_items"
    fi
    if [ $done_count -eq 0 ]; then
        content="$content"$'\n'"- (no completed items this week)"
        echo -e "  ${DIM}(no completed items this week)${NC}"
    else
        echo -e "\n  ${DIM}$done_count items completed${NC}"
    fi

    echo ""

    # Still in progress
    content="$content"$'\n'$'\n'"## Still In Progress"
    local ip_items=$(collect_in_progress)
    local has_ip=false
    if [ -n "$ip_items" ]; then
        while IFS= read -r item; do
            local text=$(format_item "$item")
            content="$content"$'\n'"- $text"
            echo -e "  ${YELLOW}→${NC} $text"
            has_ip=true
        done <<< "$ip_items"
    fi
    if ! $has_ip; then
        content="$content"$'\n'"- (nothing carried over)"
        echo -e "  ${DIM}(nothing carried over)${NC}"
    fi

    echo ""

    # Next week
    content="$content"$'\n'$'\n'"## Next Week"
    local pending_items=$(collect_pending)
    local has_pending=false
    if [ -n "$pending_items" ]; then
        while IFS= read -r item; do
            local text=$(format_item "$item")
            content="$content"$'\n'"- $text"
            echo -e "  ${CYAN}○${NC} $text"
            has_pending=true
        done <<< "$pending_items"
    fi
    if ! $has_pending; then
        content="$content"$'\n'"- (backlog clear)"
        echo -e "  ${DIM}(backlog clear)${NC}"
    fi

    echo ""

    # Task activity for the week
    local recent=$(collect_recent_tasks 7)
    if [ -n "$recent" ]; then
        content="$content"$'\n'$'\n'"## Task Activity This Week"
        while IFS= read -r task; do
            content="$content"$'\n'"- $task"
        done <<< "$recent"
    fi

    echo "$content" > "$output_file"
    echo -e "${GREEN}✓${NC}  Saved to ${DIM}standups/$year-W$week_num.md${NC}"
    echo ""
}

view_standup() {
    local file="$1"
    if [ -z "$file" ]; then
        # Find most recent standup
        file=$(ls -t "$STANDUPS_DIR"/*.md 2>/dev/null | head -1)
    fi
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo -e "${DIM}No standups yet. Run ${NC}${GREEN}./cc standup daily${NC}${DIM} to generate one.${NC}"
        return
    fi
    echo ""
    cat "$file"
    echo ""
}

show_help() {
    echo ""
    echo -e "${BOLD}Usage:${NC} ./cc standup ${GREEN}<command>${NC}"
    echo ""
    printf "  ${GREEN}%-12s${NC} %s\n" "daily" "Generate today's standup (default)"
    printf "  ${GREEN}%-12s${NC} %s\n" "weekly" "Generate weekly recap"
    printf "  ${GREEN}%-12s${NC} %s\n" "view" "View most recent standup"
    printf "  ${GREEN}%-12s${NC} %s\n" "list" "List all standup files"
    echo ""
    echo -e "  ${DIM}Standups are saved to standups/ as markdown files.${NC}"
    echo -e "  ${DIM}Data is pulled from todos.md and task-history/.${NC}"
    echo ""
}

# Main
case "${1:-daily}" in
    daily|d)
        generate_daily
        ;;
    weekly|w)
        generate_weekly
        ;;
    view|v)
        view_standup "$2"
        ;;
    list|ls)
        echo ""
        if ls "$STANDUPS_DIR"/*.md >/dev/null 2>&1; then
            echo -e "${BOLD}Standups:${NC}"
            for f in "$STANDUPS_DIR"/*.md; do
                echo -e "  ${CYAN}•${NC} $(basename "$f")"
            done
        else
            echo -e "${DIM}No standups yet.${NC}"
        fi
        echo ""
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown standup command: $1${NC}"
        show_help
        exit 1
        ;;
esac
