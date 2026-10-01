# Checks out a scenario branch from a problem letter, then creates a working branch
# named for the slot id. Local changes, untracked files, and project build caches
# are removed first.
#
# Usage:
#   .\checkout-session.ps1 -Problem a -SlotId A110
#   .\checkout-session.ps1 b B110 -Remote origin

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Problem statement letter, for example a or b")]
    [ValidateNotNullOrEmpty()]
    [string]$Problem,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Slot id, for example A110 or B110")]
    [ValidateNotNullOrEmpty()]
    [string]$SlotId,

    [string]$Remote = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

    throw "Problem statement must be a letter such as 'a' or 'b'. Got '$ProblemStatement'."
}

function Get-SlotBranchName {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$ProblemLetter
    )

    $name = $Id.Trim()
    if ($name -notmatch '^[A-Za-z][A-Za-z0-9]+$') {
        throw "Slot id must look like 'A110' or 'B110'. Got '$Id'."
    }

    $slotLetter = $name.Substring(0, 1).ToLowerInvariant()
    if ($slotLetter -ne $ProblemLetter) {
        $expected = $ProblemLetter.ToUpperInvariant()
        throw "Slot id '$name' does not match problem '$ProblemLetter'. Expected an id starting with '$expected', for example ${expected}110."
    }

    & git check-ref-format "refs/heads/$name" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Slot id '$name' is not a valid git branch name."
    }

    return $name
}

function Remove-DirectoryIfPresent {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $fullPath = Join-Path (Get-Location) $RelativePath
    if (Test-Path -LiteralPath $fullPath) {
        Write-Host "Removing $RelativePath"
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
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
    if (Test-Path (Join-Path $gitDir "rebase-merge") -or Test-Path (Join-Path $gitDir "rebase-apply")) {
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

$repoRoot = & git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    throw "Run this script from inside the coding-session repository."
}

Set-Location $repoRoot

Invoke-Git @("remote", "get-url", $Remote) | Out-Null

$problemLetter = Get-ProblemLetter -ProblemStatement $Problem
$Branch = "scenario-$problemLetter"
$slotBranch = Get-SlotBranchName -Id $SlotId -ProblemLetter $problemLetter
$scriptName = Split-Path -Leaf $PSCommandPath

Write-Host "Repository: $repoRoot"
Write-Host "Problem: $problemLetter"
Write-Host "Remote branch: $Remote/$Branch"
Write-Host "Slot id: $slotBranch"
Write-Host "Cleaning the workspace and caches before checkout."

Stop-InProgressGitOperation
Invoke-Git @("reset", "--hard")
Invoke-Git @("clean", "-fdx", "-e", $scriptName)
Clear-ProjectCaches

Write-Host "Fetching $Remote"
Invoke-Git @("fetch", $Remote, "--prune")

& git rev-parse --verify --quiet "refs/remotes/$Remote/$Branch" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Branch '$Branch' was not found on remote '$Remote'."
}

Write-Host "Checking out $Remote/$Branch"
Invoke-Git @("checkout", "-B", $Branch, "$Remote/$Branch")
Invoke-Git @("branch", "--set-upstream-to=$Remote/$Branch", $Branch)

Write-Host "Creating $slotBranch"
Invoke-Git @("checkout", "-B", $slotBranch)

Write-Host ""
Write-Host "Ready."
Write-Host "  Problem $problemLetter checked out from $Remote/$Branch"
Write-Host "  Working branch $slotBranch"
Invoke-Git @("status", "-sb")
