#!/bin/bash
# Claude Code Configuration Backup (macOS / Linux)
# Usage: bash backup.sh [--no-push]
#
# This script copies Claude Code config files into the backup/ folder
# and optionally commits + pushes to your private backup repo.

set -euo pipefail

NO_PUSH=false
if [[ "${1:-}" == "--no-push" ]]; then
    NO_PUSH=true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$BACKUP_DIR"

echo ""
echo "=== Claude Code Config Backup ==="
echo ""

# Pull latest from private repo before copying (merge strategy)
if [[ -d "$BACKUP_DIR/.git" ]]; then
    if git -C "$BACKUP_DIR" pull --ff-only > /dev/null 2>&1; then
        echo "  [OK] Pulled latest from private repo"
    else
        echo "  [WARN] Pull failed. Continuing with local copy..."
    fi
    echo ""
fi

BACKED_UP=0

# settings.json
if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
    cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/settings.json"
    echo "  [OK] settings.json"
    ((BACKED_UP++))
fi

# installed_plugins.json
if [[ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ]]; then
    cp "$CLAUDE_DIR/plugins/installed_plugins.json" "$BACKUP_DIR/installed_plugins.json"
    echo "  [OK] installed_plugins.json"
    ((BACKED_UP++))
fi

# Projects (per-project settings, memory, permissions)
# Non-destructive: overwrites existing files but preserves remote-only projects
if [[ -d "$CLAUDE_DIR/projects" ]]; then
    rsync -a "$CLAUDE_DIR/projects/" "$BACKUP_DIR/projects/"
    echo "  [OK] projects/ (merged)"
    ((BACKED_UP++))
fi

# Global MCP config
if [[ -f "$HOME/.mcp.json" ]]; then
    cp "$HOME/.mcp.json" "$BACKUP_DIR/mcp.json"
    echo "  [OK] mcp.json (global MCP servers)"
    ((BACKED_UP++))
fi

# Keybindings
if [[ -f "$CLAUDE_DIR/keybindings.json" ]]; then
    cp "$CLAUDE_DIR/keybindings.json" "$BACKUP_DIR/keybindings.json"
    echo "  [OK] keybindings.json"
    ((BACKED_UP++))
fi

# Custom slash commands (non-destructive merge)
if [[ -d "$CLAUDE_DIR/commands" ]]; then
    rsync -a "$CLAUDE_DIR/commands/" "$BACKUP_DIR/commands/"
    echo "  [OK] commands/ (merged)"
    ((BACKED_UP++))
fi

if [[ $BACKED_UP -eq 0 ]]; then
    echo "  [WARN] No Claude Code config found at $CLAUDE_DIR"
    echo "  Make sure Claude Code is installed and has been run at least once."
    exit 1
fi

echo ""
echo "  Backed up $BACKED_UP items to $BACKUP_DIR"

# --- Git commit + push to private repo ---
if [[ "$NO_PUSH" == false ]] && [[ -d "$BACKUP_DIR/.git" ]]; then
    echo ""
    echo "=== Pushing to private repo ==="
    echo ""

    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    cd "$BACKUP_DIR"

    git add -A > /dev/null 2>&1

    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        git commit -m "backup: $TIMESTAMP" > /dev/null 2>&1
        if git push > /dev/null 2>&1; then
            echo "  [OK] Pushed to private repo"
        else
            echo "  [WARN] Push failed. Run 'cd backup && git push' manually."
        fi
    else
        echo "  [--] No changes to commit"
    fi
elif [[ "$NO_PUSH" == false ]]; then
    echo ""
    echo "  [INFO] backup/ is not a git repo. Run setup.sh first to enable auto-push."
fi

echo ""
echo "=== Done ==="
echo ""
