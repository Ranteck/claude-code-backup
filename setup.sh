#!/bin/bash
# Claude Code Backup Setup (macOS / Linux)
# Usage: bash setup.sh <private-repo-url>
#
# Initializes the backup/ folder as a git repo linked to your private backup repository.
# Run this once on each machine where you want to use claude-code-backup.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: bash setup.sh <private-repo-url>"
    echo "Example: bash setup.sh https://github.com/you/your-private-repo.git"
    exit 1
fi

REPO_URL="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup"

echo ""
echo "=== Claude Code Backup Setup ==="
echo ""

# If backup/ already has a .git, warn
if [[ -d "$BACKUP_DIR/.git" ]]; then
    echo "  [WARN] backup/ is already a git repo."
    REMOTE=$(git -C "$BACKUP_DIR" remote get-url origin 2>/dev/null || echo "unknown")
    echo "  Remote: $REMOTE"
    read -rp "  Re-initialize? This will remove the existing .git (y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "  Aborted."
        exit 0
    fi
    rm -rf "$BACKUP_DIR/.git"
fi

# Check if the remote repo has content
echo "  Checking remote repo..."
if git ls-remote "$REPO_URL" > /dev/null 2>&1 && [[ -n $(git ls-remote "$REPO_URL" 2>/dev/null) ]]; then
    # Remote has commits — clone into backup/
    echo "  Found existing backup repo. Cloning..."
    rm -rf "$BACKUP_DIR"
    if git clone "$REPO_URL" "$BACKUP_DIR" > /dev/null 2>&1; then
        echo "  [OK] Cloned private repo into backup/"
    else
        echo "  [ERROR] Clone failed. Check the URL and your credentials."
        exit 1
    fi
else
    # Remote is empty or new — init locally
    echo "  Remote is empty. Initializing fresh backup repo..."
    mkdir -p "$BACKUP_DIR"
    cd "$BACKUP_DIR"

    git init -b main > /dev/null 2>&1
    git remote add origin "$REPO_URL" > /dev/null 2>&1

    # Create a minimal .gitkeep so we can do an initial commit
    touch .gitkeep
    git add -A > /dev/null 2>&1
    git commit -m "init: claude-code-backup" > /dev/null 2>&1
    if git push -u origin main > /dev/null 2>&1; then
        echo "  [OK] Initialized and pushed to private repo"
    else
        echo "  [WARN] Init OK but push failed. Run 'cd backup && git push -u origin main' manually."
    fi
fi

echo ""
echo "  Setup complete! Now run backup.sh to create your first backup."
echo ""
echo "=== Done ==="
echo ""
