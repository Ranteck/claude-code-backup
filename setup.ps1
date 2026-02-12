# Claude Code Backup Setup (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1 -RepoUrl "git@github.com:you/your-private-repo.git"
#
# Initializes the backup/ folder as a git repo linked to your private backup repository.
# Handles three scenarios:
#   1. Remote empty  → init fresh repo and push
#   2. Remote has data, no local data → clone remote
#   3. Remote has data, local data exists → clone remote, merge local on top (local wins)
#
# Run this once on each machine where you want to use claude-code-backup.

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl
)

$BackupDir = "$PSScriptRoot\backup"

Write-Host ""
Write-Host "=== Claude Code Backup Setup ===" -ForegroundColor Cyan
Write-Host ""

# Detect if backup/ has existing content (ignoring .git and .gitkeep)
function Test-HasLocalData {
    if (-not (Test-Path $BackupDir)) { return $false }
    $items = Get-ChildItem -Path $BackupDir -Recurse -Force |
        Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\.git" -and $_.Name -ne ".gitkeep" }
    return ($items.Count -gt 0)
}

# If backup/ already has a .git, check if remote matches
if (Test-Path "$BackupDir\.git") {
    $currentRemote = git -C $BackupDir remote get-url origin 2>$null

    # Normalize URLs for comparison (strip .git suffix, extract org/repo)
    function Get-NormalizedRepo($url) {
        $url -replace '\.git$','' -replace '.*github\.com[:/]',''
    }
    $currentRepo = Get-NormalizedRepo $currentRemote
    $newRepo = Get-NormalizedRepo $RepoUrl

    if ($currentRemote -eq $RepoUrl) {
        Write-Host "  [OK] backup/ already linked to $RepoUrl" -ForegroundColor Green
    } elseif ($currentRepo -eq $newRepo) {
        # Same repo, different URL format (e.g. HTTPS -> SSH)
        git -C $BackupDir remote set-url origin $RepoUrl 2>$null
        Write-Host "  [OK] Updated remote URL: $currentRemote -> $RepoUrl" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] backup/ is linked to a different repo." -ForegroundColor Yellow
        Write-Host "  Current: $currentRemote" -ForegroundColor DarkGray
        Write-Host "  New:     $RepoUrl" -ForegroundColor DarkGray
        $confirm = Read-Host "  Re-initialize? This will re-link to the new remote (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "  Aborted." -ForegroundColor Yellow
            exit 0
        }
        Remove-Item "$BackupDir\.git" -Recurse -Force
    }
}

# Check if the remote repo has content
Write-Host "  Checking remote repo..." -ForegroundColor DarkGray
$lsRemote = git ls-remote $RepoUrl 2>$null
$remoteHasData = ($LASTEXITCODE -eq 0 -and $lsRemote)
$localHasData = Test-HasLocalData

if ($remoteHasData) {
    if ($localHasData) {
        # --- Scenario 3: Remote has data AND local has data → merge ---
        Write-Host "  Found existing remote backup AND local data." -ForegroundColor DarkGray
        Write-Host "  Merging: clone remote, then overlay local files (local wins)..." -ForegroundColor DarkGray
        Write-Host ""

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ccb-setup-$(Get-Random)"
        $localTemp = Join-Path ([System.IO.Path]::GetTempPath()) "ccb-local-$(Get-Random)"

        try {
            # Clone remote into temp
            git clone $RepoUrl $tempDir 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [ERROR] Clone failed. Check the URL and your credentials." -ForegroundColor Red
                exit 1
            }

            # Copy local data aside (exclude .git)
            New-Item -ItemType Directory -Force -Path $localTemp | Out-Null
            Get-ChildItem -Path $BackupDir -Force | Where-Object { $_.Name -ne ".git" } |
                ForEach-Object { Copy-Item $_.FullName -Destination $localTemp -Recurse -Force }

            # Replace backup/ with the cloned remote
            Remove-Item $BackupDir -Recurse -Force
            Rename-Item $tempDir $BackupDir
            git -C $BackupDir config core.longpaths true
            Write-Host "  [OK] Cloned remote into backup/" -ForegroundColor Green

            # Overlay local data on top (local wins on conflicts)
            Get-ChildItem -Path $localTemp -Force |
                ForEach-Object { Copy-Item $_.FullName -Destination $BackupDir -Recurse -Force }
            Remove-Item $localTemp -Recurse -Force
            Write-Host "  [OK] Merged local data on top (local wins on conflicts)" -ForegroundColor Green

            # Commit the merge if there are changes
            git -C $BackupDir add -A 2>&1 | Out-Null
            $status = git -C $BackupDir status --porcelain 2>$null
            if ($status) {
                $hostName = $env:COMPUTERNAME
                git -C $BackupDir commit -m "setup: merge local data from $hostName" 2>&1 | Out-Null
                git -C $BackupDir push 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] Pushed merged backup to remote" -ForegroundColor Green
                } else {
                    Write-Host "  [WARN] Merge committed locally but push failed." -ForegroundColor Yellow
                    Write-Host "  Run 'cd backup && git push' manually." -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [--] Local and remote are identical, nothing to merge" -ForegroundColor DarkGray
            }
        } finally {
            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $localTemp) { Remove-Item $localTemp -Recurse -Force -ErrorAction SilentlyContinue }
        }
    } else {
        # --- Scenario 2: Remote has data, no local data → simple clone ---
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
    }
} else {
    # --- Scenario 1: Remote is empty or new → init locally ---
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
        $pushOutput = git push -u origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Initialized and pushed to private repo" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Init OK but push failed:" -ForegroundColor Yellow
            Write-Host "  $pushOutput" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Tip: GitHub requires a Personal Access Token (not password) for HTTPS." -ForegroundColor Yellow
            Write-Host "  Alternatively, use an SSH URL: git@github.com:user/repo.git" -ForegroundColor Yellow
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
