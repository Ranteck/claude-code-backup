# claude-code-backup

Backup and restore your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration, plugins, memory, MCP servers, keybindings, and custom commands.

Your config stays in a **private repo** you control. The scripts live in this **public repo** anyone can fork.

## What gets backed up

| Item | Source | Description |
|------|--------|-------------|
| `settings.json` | `~/.claude/settings.json` | Global settings and permissions |
| `installed_plugins.json` | `~/.claude/plugins/installed_plugins.json` | List of installed plugins |
| `projects/` | `~/.claude/projects/` | Per-project settings, memory, and permissions |
| `mcp.json` | `~/.mcp.json` | Global MCP server configuration |
| `keybindings.json` | `~/.claude/keybindings.json` | Custom keybindings |
| `commands/` | `~/.claude/commands/` | Custom slash commands |

## Architecture

```text
claude-code-backup/           ← public repo (this one)
├── backup.ps1 / backup.sh   ← backup scripts
├── restore.ps1 / restore.sh ← restore scripts
├── setup.ps1 / setup.sh     ← one-time setup
├── .gitignore                ← ignores backup/
└── backup/                   ← private repo (your data)
    ├── settings.json
    ├── installed_plugins.json
    ├── mcp.json
    ├── projects/
    └── commands/
```

**Two repos. Two pushes. Zero connection between them.**

## Quick start

### 1. Fork or clone this repo

```bash
git clone https://github.com/YOUR_USER/claude-code-backup.git
cd claude-code-backup
```

### 2. Create a private repo on GitHub

Create an **empty private repo** (no README, no .gitignore) — e.g. `claude-code-backup-data`.

### 3. Run setup

This links the `backup/` folder to your private repo.

**Windows (PowerShell):**
```powershell
.\setup.ps1 -RepoUrl "https://github.com/YOUR_USER/claude-code-backup-data.git"
```

**macOS / Linux:**
```bash
bash setup.sh https://github.com/YOUR_USER/claude-code-backup-data.git
```

### 4. Run your first backup

**Windows:**
```powershell
.\backup.ps1
```

**macOS / Linux:**
```bash
bash backup.sh
```

The script copies your config into `backup/`, commits, and pushes to your private repo.

## Restore on a new machine

### 1. Clone this repo

```bash
git clone https://github.com/YOUR_USER/claude-code-backup.git
cd claude-code-backup
```

### 2. Run setup (this clones your private backup data)

```powershell
# Windows
.\setup.ps1 -RepoUrl "https://github.com/YOUR_USER/claude-code-backup-data.git"

# macOS / Linux
bash setup.sh https://github.com/YOUR_USER/claude-code-backup-data.git
```

### 3. Restore

```powershell
# Windows
.\restore.ps1

# macOS / Linux
bash restore.sh
```

### 4. Restart Claude Code

Plugins will re-download automatically on first launch.

## Script reference

| Script | Description |
|--------|-------------|
| `setup.ps1` / `setup.sh` | One-time setup: links `backup/` to your private repo |
| `backup.ps1` / `backup.sh` | Copy config → `backup/`, commit + push |
| `restore.ps1` / `restore.sh` | Copy `backup/` → Claude Code config |

### Flags

- **`backup.ps1 -NoPush`** / **`backup.sh --no-push`** — Skip git commit/push (just copy files)
- **`restore.ps1 -Force`** / **`restore.sh --force`** — Skip confirmation prompt

## Security notes

- The `backup/` folder is in `.gitignore` — it will **never** be pushed to the public repo.
- Your config data only goes to the **private** repo you created.
- If you accidentally committed `backup/` to the public repo, see [Cleaning history](#cleaning-history).

## Cleaning history

If sensitive data was already committed to the public repo:

```bash
# Option 1: Nuclear — start fresh
rm -rf .git
git init -b main
git remote add origin https://github.com/YOUR_USER/claude-code-backup.git
git add .
git commit -m "Initial commit (clean history)"
git push --force origin main

# Option 2: Surgical — remove only backup/ from history
git filter-repo --path backup/ --invert-paths
git push --force origin main
```

## License

MIT
