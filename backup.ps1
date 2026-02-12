# Claude Code Configuration Backup (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File backup.ps1
#
# This script copies Claude Code config files into the backup/ folder
# and optionally commits + pushes to your private backup repo.

param(
    [switch]$NoPush  # Skip git commit/push
)

$ClaudeDir = "$env:USERPROFILE\.claude"
$BackupDir = "$PSScriptRoot\backup"

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

Write-Host ""
Write-Host "=== Claude Code Config Backup ===" -ForegroundColor Cyan
Write-Host ""

$backedUp = @()

# settings.json
if (Test-Path "$ClaudeDir\settings.json") {
    Copy-Item "$ClaudeDir\settings.json" "$BackupDir\settings.json" -Force
    Write-Host "  [OK] settings.json" -ForegroundColor Green
    $backedUp += "settings.json"
}

# installed_plugins.json
if (Test-Path "$ClaudeDir\plugins\installed_plugins.json") {
    Copy-Item "$ClaudeDir\plugins\installed_plugins.json" "$BackupDir\installed_plugins.json" -Force
    Write-Host "  [OK] installed_plugins.json" -ForegroundColor Green
    $backedUp += "installed_plugins.json"
}

# Projects (per-project settings, memory, permissions)
if (Test-Path "$ClaudeDir\projects") {
    if (Test-Path "$BackupDir\projects") { Remove-Item "$BackupDir\projects" -Recurse -Force }
    Copy-Item "$ClaudeDir\projects" "$BackupDir\projects" -Recurse -Force
    Write-Host "  [OK] projects/" -ForegroundColor Green
    $backedUp += "projects/"
}

# Global MCP config
if (Test-Path "$env:USERPROFILE\.mcp.json") {
    Copy-Item "$env:USERPROFILE\.mcp.json" "$BackupDir\mcp.json" -Force
    Write-Host "  [OK] mcp.json (global MCP servers)" -ForegroundColor Green
    $backedUp += "mcp.json"
}

# Keybindings
if (Test-Path "$ClaudeDir\keybindings.json") {
    Copy-Item "$ClaudeDir\keybindings.json" "$BackupDir\keybindings.json" -Force
    Write-Host "  [OK] keybindings.json" -ForegroundColor Green
    $backedUp += "keybindings.json"
}

# Custom slash commands
if (Test-Path "$ClaudeDir\commands") {
    if (Test-Path "$BackupDir\commands") { Remove-Item "$BackupDir\commands" -Recurse -Force }
    Copy-Item "$ClaudeDir\commands" "$BackupDir\commands" -Recurse -Force
    Write-Host "  [OK] commands/" -ForegroundColor Green
    $backedUp += "commands/"
}

if ($backedUp.Count -eq 0) {
    Write-Host "  [WARN] No Claude Code config found at $ClaudeDir" -ForegroundColor Yellow
    Write-Host "  Make sure Claude Code is installed and has been run at least once." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "  Backed up $($backedUp.Count) items to $BackupDir" -ForegroundColor Cyan

# --- Git commit + push to private repo ---
if (-not $NoPush) {
    $gitDir = Join-Path $BackupDir ".git"
    if (Test-Path $gitDir) {
        Write-Host ""
        Write-Host "=== Pushing to private repo ===" -ForegroundColor Cyan
        Write-Host ""

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Push-Location $BackupDir
        try {
            git add -A 2>&1 | Out-Null

            $status = git status --porcelain 2>&1
            if ($status) {
                git commit -m "backup: $timestamp" 2>&1 | Out-Null
                git push 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] Pushed to private repo" -ForegroundColor Green
                } else {
                    Write-Host "  [WARN] Push failed. Run 'cd backup && git push' manually." -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [--] No changes to commit" -ForegroundColor DarkGray
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host ""
        Write-Host "  [INFO] backup/ is not a git repo. Run setup.ps1 first to enable auto-push." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
