#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     ✅ Cursor Command Center Todos                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODOS_FILE="$SCRIPT_DIR/todos.md"

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
    echo -e "${CYAN}║${NC}        ${MAGENTA}✅ Cursor Command Center Todos${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

init_todos() {
    if [ ! -f "$TODOS_FILE" ]; then
        cat > "$TODOS_FILE" << 'EOF'
# Todos

## In Progress

## Pending

## Done
EOF
        echo -e "${GREEN}✓${NC}  Created todos.md"
    fi
}

count_items() {
    local section="$1"
    local count=0
    local in_section=false
    while IFS= read -r line; do
        case "$line" in
            "## $section"*) in_section=true ;;
            "## "*) in_section=false ;;
        esac
        if $in_section && echo "$line" | grep -q '^\- \[' 2>/dev/null; then
            count=$((count + 1))
        fi
    done < "$TODOS_FILE"
    echo "$count"
}

list_section() {
    local section="$1"
    local color="$2"
    local in_section=false
    local idx=0
    while IFS= read -r line; do
        case "$line" in
            "## $section"*) in_section=true; continue ;;
            "## "*) in_section=false ;;
        esac
        if $in_section && echo "$line" | grep -q '^\- \[' 2>/dev/null; then
            idx=$((idx + 1))
            local text=$(echo "$line" | sed 's/^- \[.\] //')
            printf "  ${color}%2d.${NC} %s\n" "$idx" "$text"
        fi
    done < "$TODOS_FILE"
    if [ $idx -eq 0 ]; then
        echo -e "  ${DIM}(none)${NC}"
    fi
}

show_todos() {
    print_banner

    local ip=$(count_items "In Progress")
    local pending=$(count_items "Pending")
    local done=$(count_items "Done")

    echo -e "${YELLOW}In Progress ($ip)${NC}"
    list_section "In Progress" "$YELLOW"
    echo ""
    echo -e "${CYAN}Pending ($pending)${NC}"
    list_section "Pending" "$CYAN"
    echo ""
    echo -e "${GREEN}Done ($done)${NC}"
    list_section "Done" "$GREEN"
    echo ""
}

detect_workspace() {
    local ws=""
    if [ -f "$SCRIPT_DIR/.last-workspace" ]; then
        ws=$(cat "$SCRIPT_DIR/.last-workspace" 2>/dev/null | tr -d '[:space:]')
    fi
    [ -z "$ws" ] && ws="shared"
    echo "$ws"
}

add_todo() {
    init_todos
    local workspace=""
    local priority="medium"
    local description=""

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w|--workspace) workspace="$2"; shift 2 ;;
            -p|--priority) priority="$2"; shift 2 ;;
            *) description="$description $1"; shift ;;
        esac
    done
    description=$(echo "$description" | sed 's/^ //')

    if [ -z "$description" ]; then
        echo -en "${YELLOW}?${NC} Todo description: "
        read -r description
    fi
    if [ -z "$description" ]; then
        echo -e "${RED}✗${NC}  No description provided"
        exit 1
    fi

    [ -z "$workspace" ] && workspace=$(detect_workspace)

    local entry="- [ ] **[$workspace]** $description \`#priority-$priority\`"

    # Insert into Pending section
    local tmp=$(mktemp)
    local inserted=false
    while IFS= read -r line; do
        echo "$line" >> "$tmp"
        if [ "$line" = "## Pending" ] && ! $inserted; then
            echo "$entry" >> "$tmp"
            inserted=true
        fi
    done < "$TODOS_FILE"
    mv "$tmp" "$TODOS_FILE"

    echo -e "${GREEN}✓${NC}  Added: ${BOLD}$description${NC} ${DIM}[$workspace, $priority]${NC}"
}

start_todo() {
    init_todos
    local num="$1"
    if [ -z "$num" ]; then
        echo -e "${CYAN}Pending items:${NC}"
        list_section "Pending" "$CYAN"
        echo ""
        echo -en "${YELLOW}?${NC} Which number to start? "
        read -r num
    fi

    local item=$(get_item_from_section "Pending" "$num")
    if [ -z "$item" ]; then
        echo -e "${RED}✗${NC}  Item #$num not found in Pending"
        exit 1
    fi

    remove_item_from_section "Pending" "$num"
    insert_into_section "In Progress" "$item"

    local text=$(echo "$item" | sed 's/^- \[.\] //')
    echo -e "${GREEN}✓${NC}  Started: ${BOLD}$text${NC}"
}

done_todo() {
    init_todos
    local num="$1"
    local section="$2"
    [ -z "$section" ] && section="In Progress"

    if [ -z "$num" ]; then
        echo -e "${YELLOW}In Progress:${NC}"
        list_section "In Progress" "$YELLOW"
        echo ""
        echo -en "${YELLOW}?${NC} Which number to mark done? "
        read -r num
    fi

    local item=$(get_item_from_section "$section" "$num")
    if [ -z "$item" ]; then
        echo -e "${RED}✗${NC}  Item #$num not found in $section"
        exit 1
    fi

    remove_item_from_section "$section" "$num"
    local date_str=$(date +%Y-%m-%d)
    local done_item=$(echo "$item" | sed "s/^- \[ \]/- [x]/" | sed "s/\$/ _(completed $date_str)_/")
    insert_into_section "Done" "$done_item"

    local text=$(echo "$item" | sed 's/^- \[.\] //')
    echo -e "${GREEN}✓${NC}  Done: ${BOLD}$text${NC}"
}

get_item_from_section() {
    local section="$1"
    local target="$2"
    local in_section=false
    local idx=0
    while IFS= read -r line; do
        case "$line" in
            "## $section"*) in_section=true; continue ;;
            "## "*) in_section=false ;;
        esac
        if $in_section && echo "$line" | grep -q '^\- \[' 2>/dev/null; then
            idx=$((idx + 1))
            if [ "$idx" = "$target" ]; then
                echo "$line"
                return
            fi
        fi
    done < "$TODOS_FILE"
}

remove_item_from_section() {
    local section="$1"
    local target="$2"
    local tmp=$(mktemp)
    local in_section=false
    local idx=0
    while IFS= read -r line; do
        case "$line" in
            "## $section"*) in_section=true ;;
            "## "*) in_section=false ;;
        esac
        if $in_section && echo "$line" | grep -q '^\- \[' 2>/dev/null; then
            idx=$((idx + 1))
            if [ "$idx" = "$target" ]; then
                continue
            fi
        fi
        echo "$line" >> "$tmp"
    done < "$TODOS_FILE"
    mv "$tmp" "$TODOS_FILE"
}

insert_into_section() {
    local section="$1"
    local item="$2"
    local tmp=$(mktemp)
    local inserted=false
    while IFS= read -r line; do
        echo "$line" >> "$tmp"
        if [ "$line" = "## $section" ] && ! $inserted; then
            echo "$item" >> "$tmp"
            inserted=true
        fi
    done < "$TODOS_FILE"
    mv "$tmp" "$TODOS_FILE"
}

next_todo() {
    init_todos
    local ip=$(count_items "In Progress")
    if [ "$ip" -gt 0 ]; then
        echo -e "${YELLOW}Currently working on:${NC}"
        list_section "In Progress" "$YELLOW"
    else
        local pending=$(count_items "Pending")
        if [ "$pending" -gt 0 ]; then
            echo -e "${CYAN}Next up:${NC}"
            local in_section=false
            while IFS= read -r line; do
                case "$line" in
                    "## Pending"*) in_section=true; continue ;;
                    "## "*) in_section=false ;;
                esac
                if $in_section && echo "$line" | grep -q '^\- \[' 2>/dev/null; then
                    local text=$(echo "$line" | sed 's/^- \[.\] //')
                    echo -e "  ${CYAN}→${NC} $text"
                    return
                fi
            done < "$TODOS_FILE"
        else
            echo -e "${DIM}Nothing pending. All clear!${NC}"
        fi
    fi
}

show_help() {
    echo ""
    echo -e "${BOLD}Usage:${NC} ./cc todo ${GREEN}<command>${NC} ${DIM}[options]${NC}"
    echo ""
    printf "  ${GREEN}%-20s${NC} %s\n" "list" "Show all todos (default)"
    printf "  ${GREEN}%-20s${NC} %s\n" "add <desc>" "Add a new todo"
    printf "  ${DIM}%-20s${NC} %s\n" "  -w <workspace>" "Set workspace (default: last used)"
    printf "  ${DIM}%-20s${NC} %s\n" "  -p <high|med|low>" "Set priority (default: medium)"
    printf "  ${GREEN}%-20s${NC} %s\n" "start [n]" "Move item from Pending → In Progress"
    printf "  ${GREEN}%-20s${NC} %s\n" "done [n]" "Mark item as done"
    printf "  ${GREEN}%-20s${NC} %s\n" "next" "Show what's next"
    echo ""
    echo -e "  ${DIM}Examples:${NC}"
    echo -e "  ${DIM}\$${NC} ./cc todo add fix auth bug -w backend -p high"
    echo -e "  ${DIM}\$${NC} ./cc todo start 2"
    echo -e "  ${DIM}\$${NC} ./cc todo done 1"
    echo -e "  ${DIM}\$${NC} ./cc todo next"
    echo ""
}

# Main
case "${1:-list}" in
    list|ls|show)
        init_todos
        show_todos
        ;;
    add|a)
        shift
        add_todo "$@"
        ;;
    start|s)
        start_todo "$2"
        ;;
    done|d|complete)
        done_todo "$2"
        ;;
    next|n)
        next_todo
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown todo command: $1${NC}"
        show_help
        exit 1
        ;;
esac
