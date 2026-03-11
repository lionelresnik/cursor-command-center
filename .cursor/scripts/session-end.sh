#!/usr/bin/env bash
set -euo pipefail

CC_DIR="$HOME/.command-center"
CONTEXT_FILE=".cursor/cc-context.json"
PR_DETECT_FILE=".cursor/cc-last-pr.txt"
STATE_FILE="$CC_DIR/session-state.json"

mkdir -p "$CC_DIR"

# Read current workspace from context
workspace=""
if [ -f "$CONTEXT_FILE" ]; then
    workspace=$(grep -o '"workspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONTEXT_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
fi

# Preserve lastSessionStart if it exists
last_session_start=""
if [ -f "$STATE_FILE" ]; then
    last_session_start=$(grep -o '"lastSessionStart"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([0-9T:Z-]*\)".*/\1/' || echo "")
fi

# Save session state for next session's recap
cat > "$STATE_FILE" << EOF
{
  "lastSessionEnd": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lastSessionStart": "${last_session_start}",
  "lastWorkspace": "$workspace"
}
EOF

# Clean up temp files
if [ -f "$PR_DETECT_FILE" ]; then
    rm -f "$PR_DETECT_FILE"
fi
