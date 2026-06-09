param(
    [string]$Repo = "tech-master33/viavoice",
    [string]$LibrariesRepo = "",
    [string]$ReleaseTag = "",
    [string]$LibrariesDir = "",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$workDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tempDir = "$env:TEMP\ViaVoiceSetup"

if ($Uninstall) {
    $instScript = "${env:ProgramFiles(x86)}\ViaVoice\install.ps1"
    if (Test-Path $instScript) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File "$instScript" -Uninstall
    } else {
        Write-Host "ViaVoice is not installed or install.ps1 not found."
    }
    exit
}

function IsAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (IsAdmin)) {
    Write-Host "Restarting as Administrator..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($MyInvocation.BoundParameters.Keys -join ' ')"
    exit
}

Write-Host "=== ViaVoice Setup ==="

# Clean temp
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Force -Path "$tempDir\extract" | Out-Null

if ($ReleaseTag -eq "") { $ReleaseTag = "latest" }

# Step 1: Download release from GitHub
if ($ReleaseTag -eq "latest") {
    $releasesUrl = "https://api.github.com/repos/$Repo/releases/latest"
} else {
    $releasesUrl = "https://api.github.com/repos/$Repo/releases/tags/$ReleaseTag"
}

Write-Host "Fetching release info from $Repo ..."
try {
    $release = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
    $zipUrl = ($release.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1).browser_download_url
    if (-not $zipUrl) { throw "No zip asset found in release" }
    Write-Host "Downloading $($release.tag_name) ..."
    $zipPath = "$tempDir\release.zip"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Extracting ..."
    Expand-Archive -Path $zipPath -DestinationPath "$tempDir\extract"
} catch {
    Write-Host "Failed to download release: $_"
    Write-Host "Falling back to local files in $workDir"
    if ((Test-Path "$workDir\install.ps1") -and (Test-Path "$workDir\bin\ttseng_dyn.dll")) {
        Copy-Item -Recurse -Force "$workDir\*" "$tempDir\extract\"
    } else {
        Write-Host "ERROR: No local distribution found and GitHub download failed."
        exit 1
    }
}

# Step 2: Clone/update libraries repo if configured
if ($LibrariesRepo -ne "") {
    if ($LibrariesDir -eq "") { $LibrariesDir = "$tempDir\libraries" }
    if (Test-Path $LibrariesDir) {
        Write-Host "Updating libraries repo ..."
        Push-Location $LibrariesDir
        git pull 2>$null
        Pop-Location
    } else {
        Write-Host "Cloning libraries repo ..."
        git clone "https://github.com/$LibrariesRepo.git" "$LibrariesDir" 2>$null
    }
    # Copy libraries into bin
    if (Test-Path "$LibrariesDir\IBMECI.dll") {
        Copy-Item -Force "$LibrariesDir\IBMECI.dll" "$tempDir\extract\bin\"
        Write-Host "IBMECI.dll updated from libraries repo"
    }
}

# Step 3: Run install
$installScript = Get-ChildItem -Path "$tempDir\extract" -Recurse -Filter "install.ps1" | Select-Object -First 1
if ($installScript) {
    Write-Host "Running installer ..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$installScript.FullName"
} else {
    Write-Host "ERROR: install.ps1 not found in downloaded package."
    exit 1
}

# Cleanup
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Host "`n=== Setup complete ==="
Write-Host "Voice Manager: Start Menu > ViaVoice Manager"
Write-Host "Uninstall: Run this script with -Uninstall"
