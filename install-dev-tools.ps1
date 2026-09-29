#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Chocolatey (if missing), then Git, Visual Studio Code, Bruno,
    IntelliJ IDEA Community, Cursor, GitHub Desktop, Eclipse Temurin JDK,
    Node.js LTS, Maven, and Gradle.

.DESCRIPTION
    Fresh-laptop setup script. Double-click install-dev-tools.cmd
    (it requests administrator rights, then runs this script).

    Packages (Chocolatey community repository):
        git                     - Git for Windows
        vscode                  - Visual Studio Code
        bruno                   - Bruno API client
        intellijidea-community  - IntelliJ IDEA Community Edition
        cursoride               - Cursor (installs for the current user)
        github-desktop          - GitHub Desktop (installs for the current user)
        temurin                 - Eclipse Temurin JDK (sets JAVA_HOME)
        nodejs-lts              - Node.js long-term support release, including npm
        maven                   - Apache Maven
        gradle                  - Gradle
#>

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Error "Run this script from an elevated PowerShell window (Run as administrator)."
    exit 1
}

$packages = @(
    "git",
    "vscode",
    "bruno",
    "intellijidea-community",
    "cursoride",
    "github-desktop",
    "nodejs-lts",
    "maven",
    "gradle"
)

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    $javaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
    if ($javaHome) {
        $env:JAVA_HOME = $javaHome
    }
}

function Install-ChocoPackages {
    param(
        [string[]]$PackageNames,
        [string]$Params
    )

    Write-Host "Installing: $($PackageNames -join ', ')"
    if ($Params) {
        choco install @PackageNames -y --no-progress --params $Params
    }
    else {
        choco install @PackageNames -y --no-progress
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Chocolatey exited with code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
}

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Installing it..."
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))

    Update-SessionPath

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Error "Chocolatey install finished, but 'choco' is still not on PATH. Open a new elevated PowerShell and run this script again."
        exit 1
    }
}
else {
    Write-Host "Chocolatey is already installed: $(choco --version)"
}

Install-ChocoPackages -PackageNames @("temurin") -Params "/ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome"
Update-SessionPath
Install-ChocoPackages -PackageNames $packages

Write-Host ""
Write-Host "Done. Close this window and open a new terminal, then check:"
Write-Host "  git --version"
Write-Host "  code --version"
Write-Host "  java -version"
Write-Host "  node --version"
Write-Host "  mvn -version"
Write-Host "  gradle -version"
Write-Host "  Bruno, IntelliJ IDEA, Cursor, and GitHub Desktop should appear in the Start menu."
