#!/bin/bash
# Claude Code Backup Setup (macOS / Linux)
# Usage: bash setup.sh <private-repo-url>
#
# Initializes the backup/ folder as a git repo linked to your private backup repository.
# Handles three scenarios:
#   1. Remote empty  → init fresh repo and push
#   2. Remote has data, no local data → clone remote
#   3. Remote has data, local data exists → clone remote, merge local on top (local wins)
#
# Run this once on each machine where you want to use claude-code-backup.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: bash setup.sh <private-repo-url>"
    echo "Example: bash setup.sh git@github.com:you/your-private-repo.git"
    exit 1
fi

REPO_URL="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup"

echo ""
echo "=== Claude Code Backup Setup ==="
echo ""

# Detect if backup/ has existing content (ignoring .git and .gitkeep)
has_local_data() {
    local count
    count=$(find "$BACKUP_DIR" -mindepth 1 \
        ! -path "$BACKUP_DIR/.git" ! -path "$BACKUP_DIR/.git/*" \
        ! -name ".gitkeep" 2>/dev/null | head -1 | wc -l)
    [[ $count -gt 0 ]]
}

# If backup/ already has a .git, check if remote matches
if [[ -d "$BACKUP_DIR/.git" ]]; then
    CURRENT_REMOTE=$(git -C "$BACKUP_DIR" remote get-url origin 2>/dev/null || echo "")

    # Normalize URLs for comparison (strip .git suffix, extract org/repo)
    normalize_repo() { echo "$1" | sed -E 's|\.git$||; s|.*github\.com[:/]||'; }
    CURRENT_REPO=$(normalize_repo "$CURRENT_REMOTE")
    NEW_REPO=$(normalize_repo "$REPO_URL")

    if [[ "$CURRENT_REMOTE" == "$REPO_URL" ]]; then
        echo "  [OK] backup/ already linked to $REPO_URL"
    elif [[ "$CURRENT_REPO" == "$NEW_REPO" ]]; then
        # Same repo, different URL format (e.g. HTTPS → SSH)
        git -C "$BACKUP_DIR" remote set-url origin "$REPO_URL"
        echo "  [OK] Updated remote URL: $CURRENT_REMOTE → $REPO_URL"
    else
        echo "  [WARN] backup/ is linked to a different repo."
        echo "  Current: $CURRENT_REMOTE"
        echo "  New:     $REPO_URL"
        read -rp "  Re-initialize? This will re-link to the new remote (y/N) " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "  Aborted."
            exit 0
        fi
        rm -rf "$BACKUP_DIR/.git"
    fi
fi

# Check if the remote repo has content
echo "  Checking remote repo..."
REMOTE_HAS_DATA=false
if git ls-remote "$REPO_URL" > /dev/null 2>&1 && [[ -n $(git ls-remote "$REPO_URL" 2>/dev/null) ]]; then
    REMOTE_HAS_DATA=true
fi

LOCAL_HAS_DATA=false
if [[ -d "$BACKUP_DIR" ]] && has_local_data; then
    LOCAL_HAS_DATA=true
fi

if [[ "$REMOTE_HAS_DATA" == true ]]; then
    if [[ "$LOCAL_HAS_DATA" == true ]]; then
        # --- Scenario 3: Remote has data AND local has data → merge ---
        echo "  Found existing remote backup AND local data."
        echo "  Merging: clone remote, then overlay local files (local wins)..."
        echo ""

        TEMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TEMP_DIR"' EXIT

        if git clone "$REPO_URL" "$TEMP_DIR/repo" > /dev/null 2>&1; then
            # Copy local data aside
            LOCAL_TEMP=$(mktemp -d)
            rsync -a --exclude='.git' "$BACKUP_DIR/" "$LOCAL_TEMP/"

            # Replace backup/ with the cloned remote
            rm -rf "$BACKUP_DIR"
            mv "$TEMP_DIR/repo" "$BACKUP_DIR"
            git -C "$BACKUP_DIR" config core.longpaths true
            echo "  [OK] Cloned remote into backup/"

            # Overlay local data on top (local wins on conflicts)
            rsync -a "$LOCAL_TEMP/" "$BACKUP_DIR/"
            rm -rf "$LOCAL_TEMP"
            echo "  [OK] Merged local data on top (local wins on conflicts)"

            # Commit the merge if there are changes
            git -C "$BACKUP_DIR" add -A > /dev/null 2>&1
            if [[ -n $(git -C "$BACKUP_DIR" status --porcelain 2>/dev/null) ]]; then
                HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
                git -C "$BACKUP_DIR" commit -m "setup: merge local data from $HOSTNAME" > /dev/null 2>&1
                if git -C "$BACKUP_DIR" push > /dev/null 2>&1; then
                    echo "  [OK] Pushed merged backup to remote"
                else
                    echo "  [WARN] Merge committed locally but push failed."
                    echo "  Run 'cd backup && git push' manually."
                fi
            else
                echo "  [--] Local and remote are identical, nothing to merge"
            fi
        else
            echo "  [ERROR] Clone failed. Check the URL and your credentials."
            exit 1
        fi
    else
        # --- Scenario 2: Remote has data, no local data → simple clone ---
        echo "  Found existing backup repo. Cloning..."
        rm -rf "$BACKUP_DIR"
        if git clone "$REPO_URL" "$BACKUP_DIR" > /dev/null 2>&1; then
            git -C "$BACKUP_DIR" config core.longpaths true
            echo "  [OK] Cloned private repo into backup/"
        else
            echo "  [ERROR] Clone failed. Check the URL and your credentials."
            exit 1
        fi
    fi
else
    # --- Scenario 1: Remote is empty or new → init locally ---
    echo "  Remote is empty. Initializing fresh backup repo..."
    mkdir -p "$BACKUP_DIR"
    cd "$BACKUP_DIR"

    git init -b main > /dev/null 2>&1
    git config core.longpaths true
    git remote add origin "$REPO_URL" > /dev/null 2>&1

    # Create a minimal .gitkeep so we can do an initial commit
    touch .gitkeep
    git add -A > /dev/null 2>&1
    git commit -m "init: claude-code-backup" > /dev/null 2>&1
    if PUSH_OUTPUT=$(git push -u origin main 2>&1); then
        echo "  [OK] Initialized and pushed to private repo"
    else
        echo "  [WARN] Init OK but push failed:"
        echo "  $PUSH_OUTPUT"
        echo ""
        echo "  Tip: GitHub requires a Personal Access Token (not password) for HTTPS."
        echo "  Alternatively, use an SSH URL: git@github.com:user/repo.git"
    fi
fi

echo ""
echo "  Setup complete! Now run backup.sh to create your first backup."
echo ""
echo "=== Done ==="
echo ""
