[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "Argon"),
    [string]$DataRoot = (Join-Path $env:LOCALAPPDATA "Argon")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
    throw "Install root was not found: $InstallRoot"
}

$manifestPath = Join-Path $InstallRoot "payload-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "payload-manifest.json is missing from '$InstallRoot'. The installer may be incomplete."
}

try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} catch {
    throw "Could not parse payload manifest '$manifestPath': $($_.Exception.Message)"
}

if ($manifest.schemaVersion -ne 1 -or $manifest.hashAlgorithm -ne "SHA-256") {
    throw "Unsupported payload manifest schema or hash algorithm."
}
if (-not $manifest.files -or @($manifest.files).Count -eq 0) {
    throw "The payload manifest contains no file entries."
}

$failures = New-Object 'System.Collections.Generic.List[string]'
foreach ($entry in $manifest.files) {
    $relative = ([string]$entry.path).Replace('/', '\')
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|\\)\.\.(\\|$)') {
        $failures.Add("Unsafe manifest path: $relative")
        continue
    }

    $filePath = Join-Path $InstallRoot $relative
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        $failures.Add("Missing: $relative")
        continue
    }

    $file = Get-Item -LiteralPath $filePath
    if ([Int64]$entry.size -ne $file.Length) {
        $failures.Add("Size mismatch: $relative")
        continue
    }

    $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
        $failures.Add("SHA-256 mismatch: $relative")
    }
}

$requiredRuntimeDirectories = @(
    "UserData\Settings",
    "UserData\Cache",
    "UserData\Search QR",
    "UserData\Documents",
    "UserData\Accounts",
    "UserData\Analytics\Daily",
    "Updates\Downloads",
    "Updates\Staging",
    "Updates\Backups",
    "Logs"
)
foreach ($relative in $requiredRuntimeDirectories) {
    $path = Join-Path $DataRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        $failures.Add("Missing runtime directory: $path")
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Argon installation verification FAILED:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

$executable = Join-Path $InstallRoot "App\Argon.exe"
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Argon.exe is missing from the expected application folder."
}

Write-Host "Argon installation verification PASSED." -ForegroundColor Green
Write-Host "Version:       $($manifest.appVersion)"
Write-Host "Install root:  $InstallRoot"
Write-Host "Data root:     $DataRoot"
Write-Host "Verified files: $(@($manifest.files).Count)"
Write-Host "Executable:    $executable"
$updaterState = if (Test-Path -LiteralPath (Join-Path $InstallRoot 'Updater\ArgonUpdater.exe')) { 'present' } else { 'not installed yet (expected for the current placeholder phase)' }
Write-Host "Updater:       $updaterState"
