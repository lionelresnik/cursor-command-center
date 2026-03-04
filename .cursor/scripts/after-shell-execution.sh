#!/usr/bin/env bash
set -euo pipefail

# Detect PR creation from shell output.
# Triggered after `gh pr create` or `git push` commands.
# Extracts PR URL if found and writes it to a temp file
# for the agent to pick up and add to the task file.

PR_DETECT_FILE=".cursor/cc-last-pr.txt"

# Read stdin (shell command output) if available
output=""
if [ ! -t 0 ]; then
    output=$(cat)
fi

# Look for GitHub PR URL in output
pr_url=$(echo "$output" | grep -oE 'https://github.com/[^[:space:]]+/pull/[0-9]+' | head -1 || true)

if [ -n "$pr_url" ]; then
    mkdir -p .cursor
    echo "$pr_url" > "$PR_DETECT_FILE"
fi
