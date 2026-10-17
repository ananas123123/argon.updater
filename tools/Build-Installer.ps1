[CmdletBinding()]
param(
    [string]$ReleaseTag = "latest",
    [string]$ReleaseAssetName = "Argon-Windows-x64.zip",
    [string]$PayloadZip = "",
    [string]$PayloadDirectory = "",
    [string]$AppVersion = "",
    [string]$ISCCPath = "",
    [switch]$PrepareOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PayloadZip -and $PayloadDirectory) {
    throw "Specify only one of -PayloadZip or -PayloadDirectory."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot "dist"
$downloadRoot = Join-Path $distRoot "downloads"
$prepareScript = Join-Path $PSScriptRoot "Prepare-Installer.ps1"
$installerScript = Join-Path $repoRoot "installer\argon-installer.iss"
New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

$release = $null
$sourceDescription = ""

if (-not $PayloadZip -and -not $PayloadDirectory) {
    $apiBase = "https://api.github.com/repos/ananas123123/argon.app/releases"
    $releaseUrl = if ($ReleaseTag -eq "latest") {
        "$apiBase/latest"
    } else {
        "$apiBase/tags/$([Uri]::EscapeDataString($ReleaseTag))"
    }

    try {
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{
            "User-Agent" = "Argon-Installer-Builder"
            "Accept" = "application/vnd.github+json"
        }
    } catch {
        throw "Could not read Argon release '$ReleaseTag' from $releaseUrl. The Argon app repository currently may not have a published release. Publish a release with '$ReleaseAssetName', or pass -PayloadDirectory to build from a local Argon-sim folder. Details: $($_.Exception.Message)"
    }

    $asset = @($release.assets | Where-Object { $_.name -ceq $ReleaseAssetName } | Select-Object -First 1)
    if ($asset.Count -eq 0) {
        $available = @($release.assets | ForEach-Object { $_.name })
        $availableText = if ($available.Count -gt 0) { $available -join ", " } else { "(no release assets)" }
        throw "Argon release '$($release.tag_name)' does not contain '$ReleaseAssetName'. Available assets: $availableText. Publish the complete deployed Windows x64 app as that ZIP, or pass -PayloadDirectory for a local smoke test."
    }

    $PayloadZip = Join-Path $downloadRoot $ReleaseAssetName
    Write-Host "Downloading $ReleaseAssetName from Argon release $($release.tag_name)..."
    Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $PayloadZip -Headers @{
        "User-Agent" = "Argon-Installer-Builder"
        "Accept" = "application/octet-stream"
    }
    if (-not (Test-Path -LiteralPath $PayloadZip -PathType Leaf)) {
        throw "Release asset download did not create the expected file: $PayloadZip"
    }
    if ([string]::IsNullOrWhiteSpace($AppVersion)) {
        $AppVersion = ([string]$release.tag_name).TrimStart('v', 'V')
    }
    $sourceDescription = "GitHub release $($release.tag_name)"
} elseif ($PayloadZip) {
    $PayloadZip = (Resolve-Path -LiteralPath $PayloadZip).Path
    $sourceDescription = "local ZIP $PayloadZip"
} else {
    $PayloadDirectory = (Resolve-Path -LiteralPath $PayloadDirectory).Path
    $sourceDescription = "local directory $PayloadDirectory"
}

if ([string]::IsNullOrWhiteSpace($AppVersion)) {
    $AppVersion = "0.1.0-dev"
}
if ($AppVersion -notmatch '^[0-9A-Za-z][0-9A-Za-z.+_-]*
    AppVersion = $AppVersion
    Force = $true
}
if ($PayloadZip) {
    $prepareArgs.PayloadZip = $PayloadZip
} else {
    $prepareArgs.PayloadDirectory = $PayloadDirectory
}

Write-Host "Preparing installer payload from $sourceDescription..."
& $prepareScript @prepareArgs

if ($PrepareOnly) {
    Write-Host "Preparation complete. Inno Setup compilation was skipped."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ISCCPath)) {
    $candidates = @()
    $programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
    $programFiles = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
    if ($programFilesX86) {
        $candidates += Join-Path $programFilesX86 "Inno Setup 6\ISCC.exe"
    }
    if ($programFiles) {
        $candidates += Join-Path $programFiles "Inno Setup 6\ISCC.exe"
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"
    }
    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }

    $ISCCPath = $candidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($ISCCPath) -or -not (Test-Path -LiteralPath $ISCCPath -PathType Leaf)) {
    throw "Inno Setup compiler (ISCC.exe) was not found. Install Inno Setup 6 or pass -ISCCPath 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'. Payload preparation succeeded, so you can debug that stage separately."
}

$outputDirectory = Join-Path $distRoot "output"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
Push-Location $repoRoot
try {
    Write-Host "Compiling installer with $ISCCPath..."
    & $ISCCPath "/DAppVersion=$AppVersion" "/DAppFileVersion=$fileVersion" $installerScript
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup failed with exit code $LASTEXITCODE. Review the compiler diagnostics above."
    }
} finally {
    Pop-Location
}

$installerPath = Join-Path $outputDirectory "ArgonInstaller-$AppVersion-x64.exe"
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw "Inno Setup returned success but the installer was not found at the expected path: $installerPath"
}

$hash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ""
Write-Host "INSTALLER BUILD SUCCEEDED" -ForegroundColor Green
Write-Host "Installer: $installerPath"
Write-Host "SHA-256:   $hash"
Write-Host "Version:   $AppVersion"
Write-Host "File version metadata: $fileVersion"
Write-Host "Source:    $sourceDescription"
Write-Host "NOTE: This build is unsigned until a trusted signing configuration is added."
) {
    throw "Invalid AppVersion '$AppVersion'."
}

# Windows version-resource fields are numeric. Keep the display version (which may
# include "-test.1") separate from the four-part executable metadata version.
$fileVersion = "0.1.0.0"
if ($AppVersion -match '^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?') {
    $numericParts = @($Matches[1], $Matches[2], $Matches[3], $Matches[4])
    for ($index = 0; $index -lt 4; $index++) {
        if ([string]::IsNullOrWhiteSpace($numericParts[$index])) {
            $numericParts[$index] = "0"
        }
    }
    $fileVersion = $numericParts -join "."
}

$prepareArgs = @{
    AppVersion = $AppVersion
    Force = $true
}
if ($PayloadZip) {
    $prepareArgs.PayloadZip = $PayloadZip
} else {
    $prepareArgs.PayloadDirectory = $PayloadDirectory
}

Write-Host "Preparing installer payload from $sourceDescription..."
& $prepareScript @prepareArgs

if ($PrepareOnly) {
    Write-Host "Preparation complete. Inno Setup compilation was skipped."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ISCCPath)) {
    $candidates = @()
    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $programFiles = [Environment]::GetFolderPath("ProgramFiles")
    if ($programFilesX86) {
        $candidates += Join-Path $programFilesX86 "Inno Setup 6\ISCC.exe"
    }
    if ($programFiles) {
        $candidates += Join-Path $programFiles "Inno Setup 6\ISCC.exe"
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"
    }
    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }

    $ISCCPath = $candidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($ISCCPath) -or -not (Test-Path -LiteralPath $ISCCPath -PathType Leaf)) {
    throw "Inno Setup compiler (ISCC.exe) was not found. Install Inno Setup 6 or pass -ISCCPath 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'. Payload preparation succeeded, so you can debug that stage separately."
}

$outputDirectory = Join-Path $distRoot "output"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
Push-Location $repoRoot
try {
    Write-Host "Compiling installer with $ISCCPath..."
    & $ISCCPath "/DAppVersion=$AppVersion" $installerScript
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup failed with exit code $LASTEXITCODE. Review the compiler diagnostics above."
    }
} finally {
    Pop-Location
}

$installerPath = Join-Path $outputDirectory "ArgonInstaller-$AppVersion-x64.exe"
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw "Inno Setup returned success but the installer was not found at the expected path: $installerPath"
}

$hash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ""
Write-Host "INSTALLER BUILD SUCCEEDED" -ForegroundColor Green
Write-Host "Installer: $installerPath"
Write-Host "SHA-256:   $hash"
Write-Host "Version:   $AppVersion"
Write-Host "Source:    $sourceDescription"
Write-Host "NOTE: This build is unsigned until a trusted signing configuration is added."
