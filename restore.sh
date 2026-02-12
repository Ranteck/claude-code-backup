#!/bin/bash
# Claude Code Configuration Restore (macOS / Linux)
# Usage: bash restore.sh [--force]
#
# Restores Claude Code config from the backup/ folder.
# Run this after a fresh install of Claude Code.

set -euo pipefail

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup"
CLAUDE_DIR="$HOME/.claude"

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "[ERROR] No backup found at $BACKUP_DIR"
    echo "Run backup.sh first, or setup.sh to clone your private backup repo."
    exit 1
fi

echo ""
echo "=== Claude Code Config Restore ==="
echo ""
echo "  Source:  $BACKUP_DIR"
echo "  Target:  $CLAUDE_DIR"
echo ""

if [[ "$FORCE" == false ]]; then
    read -rp "This will overwrite your current Claude Code config. Continue? (y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

mkdir -p "$CLAUDE_DIR"

RESTORED=0

# settings.json
if [[ -f "$BACKUP_DIR/settings.json" ]]; then
    cp "$BACKUP_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo "  [OK] settings.json"
    ((RESTORED++)) || true
fi

# installed_plugins.json
if [[ -f "$BACKUP_DIR/installed_plugins.json" ]]; then
    mkdir -p "$CLAUDE_DIR/plugins"
    cp "$BACKUP_DIR/installed_plugins.json" "$CLAUDE_DIR/plugins/installed_plugins.json"
    echo "  [OK] installed_plugins.json"
    ((RESTORED++)) || true
fi

# known_marketplaces.json
if [[ -f "$BACKUP_DIR/known_marketplaces.json" ]]; then
    mkdir -p "$CLAUDE_DIR/plugins"
    cp "$BACKUP_DIR/known_marketplaces.json" "$CLAUDE_DIR/plugins/known_marketplaces.json"
    echo "  [OK] known_marketplaces.json"
    ((RESTORED++)) || true
fi

# Projects
if [[ -d "$BACKUP_DIR/projects" ]]; then
    rsync -a --delete "$BACKUP_DIR/projects/" "$CLAUDE_DIR/projects/"
    echo "  [OK] projects/"
    ((RESTORED++)) || true
fi

# Global MCP config
if [[ -f "$BACKUP_DIR/mcp.json" ]]; then
    cp "$BACKUP_DIR/mcp.json" "$HOME/.mcp.json"
    echo "  [OK] .mcp.json (global MCP servers)"
    ((RESTORED++)) || true
fi

# Keybindings
if [[ -f "$BACKUP_DIR/keybindings.json" ]]; then
    cp "$BACKUP_DIR/keybindings.json" "$CLAUDE_DIR/keybindings.json"
    echo "  [OK] keybindings.json"
    ((RESTORED++)) || true
fi

# Custom slash commands
if [[ -d "$BACKUP_DIR/commands" ]]; then
    rsync -a --delete "$BACKUP_DIR/commands/" "$CLAUDE_DIR/commands/"
    echo "  [OK] commands/"
    ((RESTORED++)) || true
fi

# Skills
if [[ -d "$BACKUP_DIR/skills" ]]; then
    rsync -a "$BACKUP_DIR/skills/" "$CLAUDE_DIR/skills/"
    echo "  [OK] skills/"
    ((RESTORED++)) || true
fi

# Todos
if [[ -d "$BACKUP_DIR/todos" ]]; then
    rsync -a "$BACKUP_DIR/todos/" "$CLAUDE_DIR/todos/"
    echo "  [OK] todos/"
    ((RESTORED++)) || true
fi

echo ""
echo "  Restored $RESTORED items"
echo ""
echo "  Restart Claude Code for changes to take effect."
echo "  Plugins will re-download automatically on first launch."
echo ""
echo "=== Done ==="
echo ""
