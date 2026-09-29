#Requires -Version 5.1
<#
.SYNOPSIS
    Reports whether Chocolatey, Git, VS Code, Bruno, IntelliJ IDEA Community,
    Cursor, GitHub Desktop, Temurin JDK, Node.js, Maven, and Gradle are
    installed. Does not install or change anything.

.DESCRIPTION
    Double-click check-dev-tools.cmd, or run:

        powershell -NoProfile -ExecutionPolicy Bypass -File .\check-dev-tools.ps1
#>

$ErrorActionPreference = "Continue"
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

function Get-UninstallApps {
    $roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($root in $roots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, InstallLocation
    }
}

function Get-FirstExistingPath {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Get-ChocoVersions {
    $versions = @{}
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        return $versions
    }

    $lines = & choco list --local-only --limit-output 2>$null
    foreach ($line in $lines) {
        if ($line -match "^(?<id>[^|]+)\|(?<version>.+)$") {
            $versions[$Matches.id.ToLower()] = $Matches.version.Trim()
        }
    }

    return $versions
}

function Get-ProductVersion {
    param([string]$Path)

    if (-not $Path) {
        return $null
    }

    $info = (Get-Item -LiteralPath $Path).VersionInfo
    if ($info.ProductVersion) {
        return $info.ProductVersion
    }

    return $info.FileVersion
}

$apps = Get-UninstallApps
$chocoVersions = Get-ChocoVersions

$githubDesktopExes = @()
$githubDesktopRoot = Join-Path $env:LocalAppData "GitHubDesktop"
if (Test-Path -LiteralPath $githubDesktopRoot) {
    $githubDesktopExes = @(Join-Path $githubDesktopRoot "GitHubDesktop.exe")
    $githubDesktopExes += Get-ChildItem -Path $githubDesktopRoot -Directory -Filter "app-*" -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "GitHubDesktop.exe" }
}

$ideaExes = @()
$jetbrainsRoot = Join-Path $env:ProgramFiles "JetBrains"
if (Test-Path -LiteralPath $jetbrainsRoot) {
    $ideaExes = Get-ChildItem -Path $jetbrainsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "IntelliJ IDEA*" } |
        ForEach-Object { Join-Path $_.FullName "bin\idea64.exe" }
}

$javaExes = @()
foreach ($javaRoot in @(
        (Join-Path $env:ProgramFiles "Eclipse Adoptium"),
        (Join-Path $env:ProgramFiles "Java"),
        (Join-Path ${env:ProgramFiles(x86)} "Java")
    )) {
    if (Test-Path -LiteralPath $javaRoot) {
        $javaExes += Get-ChildItem -Path $javaRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "bin\java.exe" }
    }
}

$checks = @(
    @{
        Name    = "Chocolatey"
        ChocoId = $null
        Command = "choco"
        Paths   = @("$env:ProgramData\chocolatey\bin\choco.exe")
        Pattern = "^Chocolatey"
    },
    @{
        Name    = "Git"
        ChocoId = "git"
        Command = "git"
        Paths   = @("$env:ProgramFiles\Git\cmd\git.exe")
        Pattern = "^Git( version .*)?$"
    },
    @{
        Name    = "Visual Studio Code"
        ChocoId = "vscode"
        Command = "code"
        Paths   = @(
            "$env:ProgramFiles\Microsoft VS Code\Code.exe",
            "$env:LocalAppData\Programs\Microsoft VS Code\Code.exe"
        )
        Pattern = "^Microsoft Visual Studio Code"
    },
    @{
        Name    = "Bruno"
        ChocoId = "bruno"
        Command = $null
        Paths   = @(
            "$env:ProgramFiles\Bruno\Bruno.exe",
            "${env:ProgramFiles(x86)}\Bruno\Bruno.exe",
            "$env:LocalAppData\Programs\Bruno\Bruno.exe"
        )
        Pattern = "^Bruno"
    },
    @{
        Name    = "IntelliJ IDEA Community"
        ChocoId = "intellijidea-community"
        Command = $null
        Paths   = @($ideaExes)
        Pattern = "^IntelliJ IDEA"
    },
    @{
        Name    = "Cursor"
        ChocoId = "cursoride"
        Command = $null
        Paths   = @(
            "$env:LocalAppData\Programs\cursor\Cursor.exe",
            "$env:LocalAppData\Programs\Cursor\Cursor.exe",
            "$env:ProgramFiles\cursor\Cursor.exe",
            "$env:ProgramFiles\Cursor\Cursor.exe"
        )
        Pattern = "^Cursor$"
    },
    @{
        Name    = "GitHub Desktop"
        ChocoId = "github-desktop"
        Command = $null
        Paths   = @($githubDesktopExes)
        Pattern = "^GitHub Desktop$"
    },
    @{
        Name    = "Java (Temurin JDK)"
        ChocoId = "temurin"
        Command = "java"
        Paths   = @($javaExes)
        Pattern = "Eclipse Temurin|Adoptium"
    },
    @{
        Name    = "Node.js"
        ChocoId = "nodejs-lts"
        Command = "node"
        Paths   = @("$env:ProgramFiles\nodejs\node.exe")
        Pattern = "^Node\.js"
    },
    @{
        Name    = "Maven"
        ChocoId = "maven"
        Command = "mvn"
        Paths   = @("$env:ProgramData\chocolatey\bin\mvn.cmd", "$env:ProgramData\chocolatey\bin\mvn.exe")
        Pattern = "^Apache Maven"
    },
    @{
        Name    = "Gradle"
        ChocoId = "gradle"
        Command = "gradle"
        Paths   = @("$env:ProgramData\chocolatey\bin\gradle.bat", "$env:ProgramData\chocolatey\bin\gradle.exe")
        Pattern = "^Gradle"
    }
)

$results = foreach ($check in $checks) {
    $registry = $apps | Where-Object { $_.DisplayName -match $check.Pattern } | Select-Object -First 1

    $candidates = @($check.Paths)
    if ($registry.InstallLocation) {
        $root = $registry.InstallLocation.TrimEnd("\")
        $candidates += @(
            (Join-Path $root "Bruno.exe"),
            (Join-Path $root "Code.exe"),
            (Join-Path $root "Cursor.exe"),
            (Join-Path $root "bin\idea64.exe"),
            (Join-Path $root "cmd\git.exe"),
            (Join-Path $root "GitHubDesktop.exe"),
            (Join-Path $root "bin\java.exe"),
            (Join-Path $root "node.exe")
        )
    }

    $path = Get-FirstExistingPath -Candidates $candidates
    $onPath = $false
    $commandInfo = $null
    if ($check.Command) {
        $commandInfo = Get-Command $check.Command -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -notlike "*\WindowsApps\*" } |
            Select-Object -First 1
        $onPath = [bool]$commandInfo
    }

    $version = $null
    if ($check.ChocoId -and $chocoVersions.ContainsKey($check.ChocoId)) {
        $version = $chocoVersions[$check.ChocoId]
    }
    elseif ($registry.DisplayVersion) {
        $version = $registry.DisplayVersion
    }
    elseif ($check.Name -eq "Chocolatey" -and $onPath) {
        $version = (& choco --version 2>$null | Select-Object -First 1)
    }

    if (-not $version -and $path) {
        $version = Get-ProductVersion -Path $path
    }

    $status = "MISSING"
    $detail = "Not installed"
    if ($path -or $registry -or $onPath) {
        $status = "OK"
        $detail = $path
        if (-not $detail -and $registry.InstallLocation) {
            $detail = $registry.InstallLocation
        }
        if (-not $detail -and $onPath) {
            $detail = $commandInfo.Source
        }
        if ($check.Command -and -not $onPath) {
            $status = "WARN"
            $detail = "Installed, but '$($check.Command)' is not on PATH. Open a new terminal."
        }
    }
    elseif ($check.ChocoId -and $chocoVersions.ContainsKey($check.ChocoId)) {
        $status = "WARN"
        $detail = "Chocolatey package '$($check.ChocoId)' is recorded, but the app was not found."
    }

    [pscustomobject]@{
        Name    = $check.Name
        Status  = $status
        Version = $(if ($version) { $version } else { "-" })
        Detail  = $(if ($detail) { $detail } else { "-" })
    }
}

Write-Host ""
Write-Host "Dev tools review"
Write-Host "----------------"
Write-Host ("{0,-28} {1,-8} {2,-18} {3}" -f "Item", "Status", "Version", "Detail")
Write-Host ("{0,-28} {1,-8} {2,-18} {3}" -f "----", "------", "-------", "------")

foreach ($result in $results) {
    $color = switch ($result.Status) {
        "OK" { "Green" }
        "WARN" { "Yellow" }
        default { "Red" }
    }
    Write-Host ("{0,-28} {1,-8} {2,-18} {3}" -f $result.Name, $result.Status, $result.Version, $result.Detail) -ForegroundColor $color
}

$ok = @($results | Where-Object { $_.Status -eq "OK" }).Count
$warn = @($results | Where-Object { $_.Status -eq "WARN" }).Count
$missing = @($results | Where-Object { $_.Status -eq "MISSING" }).Count

Write-Host ""
Write-Host ("OK: {0}    Warning: {1}    Missing: {2}" -f $ok, $warn, $missing)

if ($missing -gt 0 -or $warn -gt 0) {
    exit 1
}

exit 0
