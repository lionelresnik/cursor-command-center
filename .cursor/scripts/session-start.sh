#!/usr/bin/env bash
set -euo pipefail

CC_DIR="$HOME/.command-center"
CONTEXT_FILE=".cursor/cc-context.json"
STATE_FILE="$CC_DIR/session-state.json"
PROFILE_FILE="$CC_DIR/profile.json"
TODOS_FILE="$CC_DIR/todos.md"

mkdir -p "$CC_DIR" .cursor

# Read profile (name + work week preference)
user_name=""
work_week="mon-fri"
if [ -f "$PROFILE_FILE" ]; then
    user_name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROFILE_FILE" 2>/dev/null | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
    ww=$(grep -o '"workWeek"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROFILE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
    [ -n "$ww" ] && work_week="$ww"
fi

# Check idle time
idle_hours=0
last_end=""
if [ -f "$STATE_FILE" ]; then
    last_end=$(grep -o '"lastSessionEnd"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([0-9T:Z-]*\)".*/\1/' || echo "")
    if [ -n "$last_end" ]; then
        if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_end" "+%s" >/dev/null 2>&1; then
            last_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_end" "+%s")
        else
            last_ts=$(date -d "$last_end" "+%s" 2>/dev/null || echo "0")
        fi
        now_ts=$(date "+%s")
        if [ "$last_ts" != "0" ]; then
            idle_seconds=$((now_ts - last_ts))
            idle_hours=$((idle_seconds / 3600))
        fi
    fi
fi

# Count todos by section
todos_pending=0
todos_in_progress=0
todos_done=0
if [ -f "$TODOS_FILE" ]; then
    current_section=""
    while IFS= read -r line; do
        case "$line" in
            "## In Progress"*) current_section="in_progress" ;;
            "## Pending"*) current_section="pending" ;;
            "## Done"*) current_section="done" ;;
            "## "*) current_section="" ;;
        esac
        if echo "$line" | grep -q '^\- \[' 2>/dev/null; then
            case "$current_section" in
                in_progress) todos_in_progress=$((todos_in_progress + 1)) ;;
                pending) todos_pending=$((todos_pending + 1)) ;;
                done) todos_done=$((todos_done + 1)) ;;
            esac
        fi
    done < "$TODOS_FILE"
fi

# Detect workspace
workspace=""
last_workspace=""
if [ -f "$STATE_FILE" ]; then
    last_workspace=$(grep -o '"lastWorkspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
fi
if [ -d "$CC_DIR/workspaces" ]; then
    for ws_file in "$CC_DIR/workspaces"/*.code-workspace; do
        [ -f "$ws_file" ] || continue
        workspace=$(basename "$ws_file" .code-workspace)
    done
fi
[ -z "$workspace" ] && workspace="$last_workspace"

# Determine greeting context
hour=$(date "+%H")
if [ "$hour" -ge 5 ] && [ "$hour" -lt 12 ]; then
    time_of_day="morning"
elif [ "$hour" -ge 12 ] && [ "$hour" -lt 17 ]; then
    time_of_day="afternoon"
elif [ "$hour" -ge 17 ] && [ "$hour" -lt 21 ]; then
    time_of_day="evening"
else
    time_of_day="night"
fi

# Detect new day (compared to last session)
is_new_day=false
last_date=""
if [ -n "$last_end" ]; then
    if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_end" "+%Y-%m-%d" >/dev/null 2>&1; then
        last_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_end" "+%Y-%m-%d")
    else
        last_date=$(date -d "$last_end" "+%Y-%m-%d" 2>/dev/null || echo "")
    fi
fi
today_date=$(date "+%Y-%m-%d")
[ "$last_date" != "$today_date" ] && is_new_day=true

# Detect start of work week
is_start_of_week=false
day_of_week=$(date "+%u")  # 1=Mon ... 7=Sun
if [ "$work_week" = "sun-thu" ]; then
    [ "$day_of_week" = "7" ] && [ "$is_new_day" = "true" ] && is_start_of_week=true
else
    [ "$day_of_week" = "1" ] && [ "$is_new_day" = "true" ] && is_start_of_week=true
fi

# Ensure standups directory exists
mkdir -p "$CC_DIR/standups"

# Write context for agent
cat > "$CONTEXT_FILE" << EOF
{
  "workspace": "$workspace",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "task_history": "$CC_DIR/task-history/$workspace",
  "docs": "$CC_DIR/docs/$workspace",
  "userName": "$user_name",
  "profileExists": $([ -f "$PROFILE_FILE" ] && echo "true" || echo "false"),
  "idleHours": $idle_hours,
  "timeOfDay": "$time_of_day",
  "todosPending": $todos_pending,
  "todosInProgress": $todos_in_progress,
  "todosDone": $todos_done,
  "lastWorkspace": "$last_workspace",
  "isNewDay": $is_new_day,
  "isStartOfWeek": $is_start_of_week,
  "workWeek": "$work_week"
}
EOF
