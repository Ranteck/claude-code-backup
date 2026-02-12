# Claude Code Configuration Restore (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File restore.ps1
#
# Restores Claude Code config from the backup/ folder.
# Run this after a fresh install of Claude Code.

param(
    [switch]$Force  # Skip confirmation prompt
)

$ClaudeDir = "$env:USERPROFILE\.claude"
$BackupDir = "$PSScriptRoot\backup"

if (-not (Test-Path $BackupDir)) {
    Write-Host "[ERROR] No backup found at $BackupDir" -ForegroundColor Red
    Write-Host "Run backup.ps1 first, or setup.ps1 to clone your private backup repo." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== Claude Code Config Restore ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Source:  $BackupDir" -ForegroundColor DarkGray
Write-Host "  Target:  $ClaudeDir" -ForegroundColor DarkGray
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "This will overwrite your current Claude Code config. Continue? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

$restored = @()

# settings.json
if (Test-Path "$BackupDir\settings.json") {
    Copy-Item "$BackupDir\settings.json" "$ClaudeDir\settings.json" -Force
    Write-Host "  [OK] settings.json" -ForegroundColor Green
    $restored += "settings.json"
}

# installed_plugins.json
if (Test-Path "$BackupDir\installed_plugins.json") {
    New-Item -ItemType Directory -Force -Path "$ClaudeDir\plugins" | Out-Null
    Copy-Item "$BackupDir\installed_plugins.json" "$ClaudeDir\plugins\installed_plugins.json" -Force
    Write-Host "  [OK] installed_plugins.json" -ForegroundColor Green
    $restored += "installed_plugins.json"
}

# Projects
if (Test-Path "$BackupDir\projects") {
    if (Test-Path "$ClaudeDir\projects") { Remove-Item "$ClaudeDir\projects" -Recurse -Force }
    Copy-Item "$BackupDir\projects" "$ClaudeDir\projects" -Recurse -Force
    Write-Host "  [OK] projects/" -ForegroundColor Green
    $restored += "projects/"
}

# Global MCP config
if (Test-Path "$BackupDir\mcp.json") {
    Copy-Item "$BackupDir\mcp.json" "$env:USERPROFILE\.mcp.json" -Force
    Write-Host "  [OK] .mcp.json (global MCP servers)" -ForegroundColor Green
    $restored += "mcp.json"
}

# Keybindings
if (Test-Path "$BackupDir\keybindings.json") {
    Copy-Item "$BackupDir\keybindings.json" "$ClaudeDir\keybindings.json" -Force
    Write-Host "  [OK] keybindings.json" -ForegroundColor Green
    $restored += "keybindings.json"
}

# Custom slash commands
if (Test-Path "$BackupDir\commands") {
    if (Test-Path "$ClaudeDir\commands") { Remove-Item "$ClaudeDir\commands" -Recurse -Force }
    Copy-Item "$BackupDir\commands" "$ClaudeDir\commands" -Recurse -Force
    Write-Host "  [OK] commands/" -ForegroundColor Green
    $restored += "commands/"
}

Write-Host ""
Write-Host "  Restored $($restored.Count) items" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Restart Claude Code for changes to take effect." -ForegroundColor Yellow
Write-Host "  Plugins will re-download automatically on first launch." -ForegroundColor Yellow
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
