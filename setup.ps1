# Claude Code Backup Setup (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1 -RepoUrl "https://github.com/you/your-private-repo.git"
#
# Initializes the backup/ folder as a git repo linked to your private backup repository.
# Run this once on each machine where you want to use claude-code-backup.

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl
)

$BackupDir = "$PSScriptRoot\backup"

Write-Host ""
Write-Host "=== Claude Code Backup Setup ===" -ForegroundColor Cyan
Write-Host ""

# If backup/ already has a .git, warn
if (Test-Path "$BackupDir\.git") {
    Write-Host "  [WARN] backup/ is already a git repo." -ForegroundColor Yellow
    $remote = git -C $BackupDir remote get-url origin 2>$null
    if ($remote) {
        Write-Host "  Remote: $remote" -ForegroundColor DarkGray
    }
    $confirm = Read-Host "  Re-initialize? This will remove the existing .git (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "  Aborted." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item "$BackupDir\.git" -Recurse -Force
}

# Check if the remote repo has content
Write-Host "  Checking remote repo..." -ForegroundColor DarkGray
$lsRemote = git ls-remote $RepoUrl 2>$null
if ($LASTEXITCODE -eq 0 -and $lsRemote) {
    # Remote has commits — clone into backup/
    Write-Host "  Found existing backup repo. Cloning..." -ForegroundColor DarkGray
    if (Test-Path $BackupDir) { Remove-Item $BackupDir -Recurse -Force }
    git clone $RepoUrl $BackupDir 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        git -C $BackupDir config core.longpaths true
        Write-Host "  [OK] Cloned private repo into backup/" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Clone failed. Check the URL and your credentials." -ForegroundColor Red
        exit 1
    }
} else {
    # Remote is empty or new — init locally
    Write-Host "  Remote is empty. Initializing fresh backup repo..." -ForegroundColor DarkGray
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    Push-Location $BackupDir
    try {
        git init -b main 2>&1 | Out-Null
        git config core.longpaths true
        git remote add origin $RepoUrl 2>&1 | Out-Null

        # Create a minimal .gitkeep so we can do an initial commit
        "" | Out-File -FilePath ".gitkeep" -Encoding utf8
        git add -A 2>&1 | Out-Null
        git commit -m "init: claude-code-backup" 2>&1 | Out-Null
        git push -u origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Initialized and pushed to private repo" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Init OK but push failed. Run 'cd backup && git push -u origin main' manually." -ForegroundColor Yellow
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "  Setup complete! Now run backup.ps1 to create your first backup." -ForegroundColor Cyan
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
