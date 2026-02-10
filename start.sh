#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                     🚀 Start Cursor Command Center                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# Opens Cursor with your Command Center and all configured repos as context.
# Run this after completing setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACES_DIR="$SCRIPT_DIR/workspaces"

# Check if setup has been run
if [ ! -f "$SCRIPT_DIR/config.json" ]; then
    echo "⚠️  Setup not complete. Run ./setup.sh first."
    exit 1
fi

# Default to 'all' workspace, or use argument
WORKSPACE="${1:-all}"
WORKSPACE_FILE="$WORKSPACES_DIR/${WORKSPACE}.code-workspace"

if [ ! -f "$WORKSPACE_FILE" ]; then
    echo "⚠️  Workspace '$WORKSPACE' not found."
    echo "Available workspaces:"
    for ws in "$WORKSPACES_DIR"/*.code-workspace; do
        echo "  - $(basename "$ws" .code-workspace)"
    done
    exit 1
fi

echo "🚀 Opening Command Center with '$WORKSPACE' context..."
cursor "$WORKSPACE_FILE"

