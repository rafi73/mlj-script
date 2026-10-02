# Prepares coding-session for the next interview.
# This script stays in mlj-script. Git commands always run in the coding-session repo.
#
# 1. Ask for the slot id and check origin: the 4-character slot id must be unused.
# 2. Ask for the scenario (a, b, c, or d) and check that scenario-x exists on origin.
# 3. If the last candidate left uncommitted changes, commit and push that branch.
# 4. Clean the workspace.
# 5. Check out the scenario branch from origin.
# 6. Create and check out a new uppercase branch: slot id, then time,
#    for example A002-101010.
#
# Double-click checkout-session.cmd. It asks for the slot id first, then the scenario.
# Remote stays origin. The slot id does not have to start with the scenario letter.
#
# Usage:
#   .\checkout-session.ps1 -SlotId A002 -Problem d
#   .\checkout-session.ps1 -SlotId A002        (asks for the scenario)
#   .\checkout-session.cmd

[CmdletBinding()]
param(
    [Parameter(Position = 0, HelpMessage = "Slot id, exactly 4 characters, for example A002. The branch becomes A002-101010.")]
    [string]$SlotId,

    [Parameter(Position = 1, HelpMessage = "Scenario letter, for example a or b")]
    [string]$Problem,

    [string]$Remote = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CodingSessionRoot = "C:\Users\Admin\Documents\GitHub\coding-session"

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs
    )

    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Get-ProblemLetter {
    param([Parameter(Mandatory = $true)][string]$ProblemStatement)

    $value = $ProblemStatement.Trim().ToLowerInvariant()
    if ($value -match '^scenario-([a-z])$') {
        return $Matches[1]
    }
    if ($value -match '^[a-z]$') {
        return $value
    }

    throw "Scenario must be a letter such as 'a', 'b', 'c', or 'd'. Got '$ProblemStatement'."
}

function Get-SlotBranchName {
    param([Parameter(Mandatory = $true)][string]$Id)

    $name = $Id.Trim().ToUpperInvariant()
    if ($name -notmatch '^[A-Z][A-Z0-9]{3}$') {
        throw "Slot id must be exactly 4 characters, for example 'A110' or 'B201'. Got '$Id'."
    }

    & git check-ref-format "refs/heads/$name" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Slot id '$name' is not a valid git branch name."
    }

    return $name
}

function Get-ExistingSlotBranches {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$RemoteName
    )

    $refs = & git for-each-ref --format="%(refname:short)" "refs/heads" "refs/remotes/$RemoteName"
    if ($LASTEXITCODE -ne 0) {
        throw "git for-each-ref failed with exit code $LASTEXITCODE."
    }

    $slot = [regex]::Escape($Id)
    $remote = [regex]::Escape($RemoteName)
    $pattern = "(?i)^(?:$remote/)?$slot(?:-[a-z])?(?:-\d{6})?$"
    return @($refs | Where-Object { $_ -match $pattern } | ForEach-Object { $_ -replace "^$remote/", "" } | Select-Object -Unique)
}

function Read-AvailableSlotId {
    param(
        [string]$Id,
        [Parameter(Mandatory = $true)][string]$RemoteName
    )

    $slotIdName = $null
    $pending = $Id
    while ($true) {
        if (-not [string]::IsNullOrWhiteSpace($pending)) {
            try {
                $slotIdName = Get-SlotBranchName -Id $pending
            }
            catch {
                Write-Host $_.Exception.Message
                $slotIdName = $null
            }
        }

        $pending = $null
        if ($slotIdName) {
            $existing = @(Get-ExistingSlotBranches -Id $slotIdName -RemoteName $RemoteName)
            if ($existing.Count -eq 0) {
                return $slotIdName
            }

            $list = $existing -join ", "
            Write-Host "Branch $list already exists. Slot id $slotIdName cannot be used again."
            Write-Host "Please enter a proper slot id."
        }

        $entered = Read-Host "Slot id (exactly 4 characters, for example A002)"
        if ([string]::IsNullOrWhiteSpace($entered)) {
            Write-Host "Slot id is required."
            continue
        }

        $pending = $entered
    }
}

function Get-UniqueSlotBranchName {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$RemoteName
    )

    $availableId = Read-AvailableSlotId -Id $Id -RemoteName $RemoteName
    $stamp = Get-Date -Format "HHmmss"
    return "$availableId-$stamp"
}

function Read-AvailableScenario {
    param(
        [string]$Scenario,
        [Parameter(Mandatory = $true)][string]$RemoteName
    )

    $pending = $Scenario
    while ($true) {
        if ([string]::IsNullOrWhiteSpace($pending)) {
            $pending = Read-Host "Scenario (a, b, c, or d)"
            if ([string]::IsNullOrWhiteSpace($pending)) {
                Write-Host "Scenario is required."
                continue
            }
        }

        $letter = $null
        try {
            $letter = Get-ProblemLetter -ProblemStatement $pending
        }
        catch {
            Write-Host $_.Exception.Message
            $pending = $null
            continue
        }

        $scenarioBranch = "scenario-$letter"
        & git rev-parse --verify --quiet "refs/remotes/$RemoteName/$scenarioBranch" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $letter
        }

        Write-Host "Branch '$scenarioBranch' was not found on remote '$RemoteName'. Please enter a proper scenario."
        $pending = $null
    }
}

function Save-LastCandidateWork {
    param([Parameter(Mandatory = $true)][string]$RemoteName)

    $branch = & git symbolic-ref --short HEAD 2>$null
    $onBranch = $LASTEXITCODE -eq 0

    $changes = & git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed with exit code $LASTEXITCODE."
    }

    if (-not $changes) {
        Write-Host "No uncommitted changes to save."
        return
    }

    if (-not $onBranch) {
        throw "There are uncommitted changes, but HEAD is detached. Commit them on a branch before continuing."
    }

    Write-Host "Committing uncommitted changes on $branch."
    Invoke-Git @("add", "-A")
    Invoke-Git @("commit", "-m", "Save candidate work")
    Write-Host "Pushing $branch to $RemoteName."
    Invoke-Git @("push", "-u", $RemoteName, "HEAD")
}

function Remove-DirectoryIfPresent {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $fullPath = Join-Path (Get-Location) $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        return
    }

    Write-Host "Removing $RelativePath"
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -eq 5) {
                throw
            }
            Start-Sleep -Seconds 1
        }
    }
}

function Test-TextContainsPath {
    param(
        [string]$Text,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if (-not $Text) {
        return $false
    }

    $normalized = $Text.Replace('/', '\')
    while ($normalized.Contains('\\')) {
        $normalized = $normalized.Replace('\\', '\')
    }

    return $normalized.IndexOf($Root, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Test-ProcessUsesRepo {
    param(
        $Process,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if (Test-TextContainsPath -Text $Process.ExecutablePath -Root $Root) {
        return $true
    }
    if (Test-TextContainsPath -Text $Process.CommandLine -Root $Root) {
        return $true
    }

    if ($Process.CommandLine -match '@(?<ArgFile>[A-Za-z]:\\[^\s"]+)') {
        $argFile = $Matches.ArgFile
        if (Test-Path -LiteralPath $argFile) {
            $argText = Get-Content -LiteralPath $argFile -Raw -ErrorAction SilentlyContinue
            if (Test-TextContainsPath -Text $argText -Root $Root) {
                return $true
            }
        }
    }

    return $false
}

function Stop-RepoDevServers {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $root = ([System.IO.Path]::GetFullPath($RepoRoot)).TrimEnd('\')
    $names = @("node.exe", "esbuild.exe", "java.exe", "javaw.exe")

    $running = @(Get-CimInstance Win32_Process | Where-Object {
        $names -contains $_.Name -and (Test-ProcessUsesRepo -Process $_ -Root $root)
    })

    if ($running.Count -eq 0) {
        return
    }

    Write-Host "Stopping dev servers that are locking build files."
    foreach ($process in $running) {
        Write-Host "Stopping $($process.Name) ($($process.ProcessId))"
        & taskkill.exe /F /T /PID $process.ProcessId 2>$null | Out-Null
    }

    Start-Sleep -Seconds 1
}

function Clear-ProjectCaches {
    Remove-DirectoryIfPresent "frontend/node_modules"
    Remove-DirectoryIfPresent "frontend/dist"
    Remove-DirectoryIfPresent "frontend/.vite"
    Remove-DirectoryIfPresent "frontend/tsconfig.tsbuildinfo"
    Remove-DirectoryIfPresent "backend/target"

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Clearing npm cache"
        & npm cache clean --force
        if ($LASTEXITCODE -ne 0) {
            throw "npm cache clean failed with exit code $LASTEXITCODE."
        }
    }
    else {
        Write-Host "npm is not on PATH; skipped npm cache clean."
    }
}

function Stop-InProgressGitOperation {
    $gitDir = (& git rev-parse --git-path .)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to resolve the git directory."
    }

    $gitDir = (Resolve-Path $gitDir).Path
    if ((Test-Path (Join-Path $gitDir "rebase-merge")) -or (Test-Path (Join-Path $gitDir "rebase-apply"))) {
        Write-Host "Aborting in-progress rebase"
        Invoke-Git @("rebase", "--abort")
    }
    if (Test-Path (Join-Path $gitDir "MERGE_HEAD")) {
        Write-Host "Aborting in-progress merge"
        Invoke-Git @("merge", "--abort")
    }
    if (Test-Path (Join-Path $gitDir "CHERRY_PICK_HEAD")) {
        Write-Host "Aborting in-progress cherry-pick"
        Invoke-Git @("cherry-pick", "--abort")
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is not on PATH."
}

if (-not (Test-Path -LiteralPath $CodingSessionRoot -PathType Container)) {
    throw "Coding session folder was not found: $CodingSessionRoot"
}

Push-Location -LiteralPath $CodingSessionRoot
try {
    $repoRoot = & git rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0) {
        throw "Coding session folder is not a git repository: $CodingSessionRoot"
    }

    Set-Location $repoRoot
    $env:GIT_ASK_YESNO = "false"

    Invoke-Git @("remote", "get-url", $Remote) | Out-Null

    Write-Host "Repository: $repoRoot"
    Write-Host "Fetching $Remote"
    Invoke-Git @("fetch", $Remote, "--prune")

    $slotIdName = Read-AvailableSlotId -Id $SlotId -RemoteName $Remote
    Write-Host "Slot id: $slotIdName"

    $problemLetter = Read-AvailableScenario -Scenario $Problem -RemoteName $Remote
    $Branch = "scenario-$problemLetter"
    Write-Host "Scenario: $Branch"
    Write-Host ""

    Save-LastCandidateWork -RemoteName $Remote

    Write-Host "Cleaning the workspace for the next candidate."
    Stop-RepoDevServers -RepoRoot $repoRoot
    Stop-InProgressGitOperation
    Invoke-Git @("reset", "--hard")
    $cleanError = $null
    foreach ($attempt in 1..5) {
        & git clean -fdx
        if ($LASTEXITCODE -eq 0) {
            $cleanError = $null
            break
        }

        $cleanError = "git clean -fdx failed with exit code $LASTEXITCODE."
        Stop-RepoDevServers -RepoRoot $repoRoot
        Start-Sleep -Seconds 1
    }
    if ($cleanError) {
        throw $cleanError
    }
    Clear-ProjectCaches

    Write-Host "Checking out $Remote/$Branch"
    Invoke-Git @("checkout", "-B", $Branch, "$Remote/$Branch")
    Invoke-Git @("branch", "--set-upstream-to=$Remote/$Branch", $Branch)

    $slotBranch = Get-UniqueSlotBranchName -Id $slotIdName -RemoteName $Remote
    Write-Host "Creating branch $slotBranch"
    Invoke-Git @("checkout", "-b", $slotBranch)

    Write-Host ""
    Write-Host "Ready for the next interview."
    Write-Host "  Scenario $Branch checked out from $Remote/$Branch"
    Write-Host "  Working branch $slotBranch"
    Invoke-Git @("status", "-sb")
}
finally {
    Pop-Location
}
