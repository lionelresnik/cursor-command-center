#!/bin/bash

# Main entry point for Cursor Command Center
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-help}" in
    help|-h|--help|-help)
        "$SCRIPT_DIR/help.sh"
        ;;
    open|o)
        shift
        "$SCRIPT_DIR/open.sh" "$@"
        ;;
    status|s)
        shift
        "$SCRIPT_DIR/status.sh" "$@"
        ;;
    setup)
        "$SCRIPT_DIR/setup.sh"
        ;;
    manage|m)
        shift
        "$SCRIPT_DIR/manage.sh" "$@"
        ;;
    add|a)
        shift
        "$SCRIPT_DIR/manage.sh" add "$@"
        ;;
    remove|rm)
        shift
        "$SCRIPT_DIR/manage.sh" remove "$@"
        ;;
    rename|mv)
        shift
        "$SCRIPT_DIR/manage.sh" rename "$@"
        ;;
    export|backup)
        shift
        "$SCRIPT_DIR/manage.sh" export "$@"
        ;;
    import|restore)
        shift
        "$SCRIPT_DIR/manage.sh" import "$@"
        ;;
    new)
        shift
        "$SCRIPT_DIR/open.sh" --add "$@"
        ;;
    start)
        shift
        "$SCRIPT_DIR/start.sh" "$@"
        ;;
    graph|g)
        shift
        "$SCRIPT_DIR/graph.sh" "$@"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './cc help' for available commands"
        exit 1
        ;;
esac

