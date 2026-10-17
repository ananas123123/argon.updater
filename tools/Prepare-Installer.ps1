[CmdletBinding()]
param(
    [string]$PayloadZip = "",
    [string]$PayloadDirectory = "",
    [string]$AppVersion = "0.1.0-dev",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PayloadZip) -eq [string]::IsNullOrWhiteSpace($PayloadDirectory)) {
    throw "Specify exactly one of -PayloadZip or -PayloadDirectory."
}
if ($PayloadZip -and -not (Test-Path -LiteralPath $PayloadZip -PathType Leaf)) {
    throw "Payload ZIP was not found: $PayloadZip"
}
if ($PayloadDirectory -and -not (Test-Path -LiteralPath $PayloadDirectory -PathType Container)) {
    throw "Payload directory was not found: $PayloadDirectory"
}
if ($AppVersion -notmatch '^[0-9A-Za-z][0-9A-Za-z.+_-]*$') {
    throw "Invalid AppVersion '$AppVersion'. Use a simple version such as 0.1.0-test.1."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot "dist"
$payloadRoot = Join-Path $distRoot "payload"
$manifestPath = Join-Path $distRoot "payload-manifest.json"
$verificationPath = Join-Path $distRoot "payload-verification.iss"
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

if ((Test-Path -LiteralPath $payloadRoot) -and -not $Force) {
    throw "Staging already exists: $payloadRoot. Re-run with -Force to replace only this generated payload."
}

$workingRoot = Join-Path $distRoot (".payload-staging-" + [Guid]::NewGuid().ToString("N"))
$inputRoot = $PayloadDirectory

function Find-AppDirectory([string]$Root) {
    $directExecutable = Join-Path $Root "Argon.exe"
    if (Test-Path -LiteralPath $directExecutable -PathType Leaf) {
        return (Get-Item -LiteralPath $Root).FullName
    }

    $candidateExe = @(Get-ChildItem -LiteralPath $Root -Filter "Argon.exe" -File -Recurse -Force |
        Where-Object { $_.Directory.Name -ieq "App" })
    if ($candidateExe.Count -ne 1) {
        throw "Expected exactly one App\Argon.exe in '$Root'; found $($candidateExe.Count). Supply the root of a single deployed Argon bundle."
    }

    return $candidateExe[0].Directory.FullName
}

try {
    New-Item -ItemType Directory -Path $workingRoot -Force | Out-Null

    if ($PayloadZip) {
        $resolvedZip = (Resolve-Path -LiteralPath $PayloadZip).Path
        $extractedRoot = Join-Path $workingRoot "extracted"
        New-Item -ItemType Directory -Path $extractedRoot -Force | Out-Null
        Expand-Archive -LiteralPath $resolvedZip -DestinationPath $extractedRoot -Force
        $inputRoot = $extractedRoot
    } else {
        $inputRoot = (Resolve-Path -LiteralPath $PayloadDirectory).Path
    }

    $appSource = Find-AppDirectory $inputRoot
    $appParent = Split-Path -Parent $appSource
    $bundleRoot = $appParent

    if ((Split-Path -Leaf $appSource) -ieq "App") {
        $bundleRoot = $appParent
    } elseif ($PayloadDirectory -and (Test-Path -LiteralPath (Join-Path $appParent "App"))) {
        $bundleRoot = $appParent
    }

    $stagePayload = Join-Path $workingRoot "payload"
    $stageApp = Join-Path $stagePayload "App"
    New-Item -ItemType Directory -Path $stageApp -Force | Out-Null
    Get-ChildItem -LiteralPath $appSource -Force | Copy-Item -Destination $stageApp -Recurse -Force

    $requiredRelativeFiles = @(
        "Argon.exe",
        "Qt6Core.dll",
        "Qt6Gui.dll",
        "Qt6Qml.dll",
        "Qt6Quick.dll",
        "Qt6QuickControls2.dll",
        "Qt6Pdf.dll",
        "Qt6PdfQuick.dll",
        "platforms\qwindows.dll",
        "libstdc++-6.dll",
        "libgcc_s_seh-1.dll",
        "libwinpthread-1.dll"
    )
    $missing = @($requiredRelativeFiles | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $stageApp $_) -PathType Leaf)
    })
    if ($missing.Count -gt 0) {
        $missingLines = @("The Argon release is incomplete. Missing required deployed runtime file(s):") +
            @($missing | ForEach-Object { " - $_" }) +
            @("Build Argon with build.bat/windeployqt, or publish a complete Argon-Windows-x64.zip release asset.")
        throw ($missingLines -join [Environment]::NewLine)
    }

    $qmlRoot = Join-Path $stageApp "qml"
    if (-not (Test-Path -LiteralPath $qmlRoot -PathType Container)) {
        throw "Qt QML deployment folder is missing: $qmlRoot. Ensure windeployqt was run with the Argon QML directory."
    }

    foreach ($subdirectory in @("Updater", "Bootstrap")) {
        $sourceDirectory = Join-Path $bundleRoot $subdirectory
        $targetDirectory = Join-Path $stagePayload $subdirectory
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

        if (Test-Path -LiteralPath $sourceDirectory -PathType Container) {
            Get-ChildItem -LiteralPath $sourceDirectory -Force | Copy-Item -Destination $targetDirectory -Recurse -Force
        }

        $expectedExe = if ($subdirectory -eq "Updater") { "ArgonUpdater.exe" } else { "ArgonBootstrap.exe" }
        if (-not (Test-Path -LiteralPath (Join-Path $targetDirectory $expectedExe) -PathType Leaf)) {
            $notice = Join-Path $targetDirectory "README.txt"
            @"
This folder is reserved for the future Argon $subdirectory component.
No executable is included in this build. This is intentional; do not rename or fabricate a placeholder executable.
"@ | Set-Content -LiteralPath $notice -Encoding UTF8
            Write-Warning "$expectedExe is not present. The installer will not ship a fake executable; updater/bootstrap functionality is not included yet."
        }
    }

    $files = @(Get-ChildItem -LiteralPath $stagePayload -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $relativePath = $_.FullName.Substring($stagePayload.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $relativePath = $relativePath.Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        [PSCustomObject]@{
            path = $relativePath
            size = $_.Length
            sha256 = $hash
        }
    })

    if ($files.Count -eq 0) {
        throw "Payload staging unexpectedly contains no files."
    }

    $manifest = [ordered]@{
        schemaVersion = 1
        product = "Argon"
        appVersion = $AppVersion
        sourceRepository = "https://github.com/ananas123123/argon.app"
        generatedUtc = [DateTime]::UtcNow.ToString("o")
        hashAlgorithm = "SHA-256"
        trustNote = "Hashes detect corruption relative to this manifest; without a signed release manifest they do not authenticate the publisher."
        files = $files
    }
    $manifestJson = $manifest | ConvertTo-Json -Depth 8
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $manifestTemp = Join-Path $workingRoot "payload-manifest.json"
    $verificationTemp = Join-Path $workingRoot "payload-verification.iss"
    [IO.File]::WriteAllText($manifestTemp, $manifestJson + [Environment]::NewLine, $utf8NoBom)

    $codeLines = New-Object 'System.Collections.Generic.List[string]'
    $codeLines.Add("function GetPayloadFileCount: Integer;")
    $codeLines.Add("begin")
    $codeLines.Add("  Result := $($files.Count);")
    $codeLines.Add("end;")
    $codeLines.Add("")
    $codeLines.Add("function GetPayloadFilePath(Index: Integer): String;")
    $codeLines.Add("begin")
    $codeLines.Add("  Result := '';")
    $codeLines.Add("  case Index of")
    for ($index = 0; $index -lt $files.Count; $index++) {
        $pascalPath = ([string]$files[$index].path).Replace('/', '\').Replace("'", "''")
        $codeLines.Add("    " + $index + ": Result := '$pascalPath';")
    }
    $codeLines.Add("  end;")
    $codeLines.Add("end;")
    $codeLines.Add("")
    $codeLines.Add("function GetPayloadFileHash(Index: Integer): String;")
    $codeLines.Add("begin")
    $codeLines.Add("  Result := '';")
    $codeLines.Add("  case Index of")
    for ($index = 0; $index -lt $files.Count; $index++) {
        $pascalHash = ([string]$files[$index].sha256).Replace("'", "''")
        $codeLines.Add("    " + $index + ": Result := '$pascalHash';")
    }
    $codeLines.Add("  end;")
    $codeLines.Add("end;")
    [IO.File]::WriteAllText($verificationTemp, ($codeLines -join [Environment]::NewLine) + [Environment]::NewLine, $utf8NoBom)

    # Swap payload, manifest and verification include as a unit. Restore the prior set if any activation fails.
    $suffix = [Guid]::NewGuid().ToString("N")
    $backupPayload = Join-Path $distRoot (".payload-previous-" + $suffix)
    $backupManifest = Join-Path $distRoot (".manifest-previous-" + $suffix)
    $backupVerification = Join-Path $distRoot (".verification-previous-" + $suffix)
    $hadPayload = Test-Path -LiteralPath $payloadRoot
    $hadManifest = Test-Path -LiteralPath $manifestPath
    $hadVerification = Test-Path -LiteralPath $verificationPath

    $newPayloadActivated = $false
    $newManifestActivated = $false
    $newVerificationActivated = $false

    try {
        if ($hadPayload) { Move-Item -LiteralPath $payloadRoot -Destination $backupPayload }
        if ($hadManifest) { Move-Item -LiteralPath $manifestPath -Destination $backupManifest }
        if ($hadVerification) { Move-Item -LiteralPath $verificationPath -Destination $backupVerification }

        Move-Item -LiteralPath $stagePayload -Destination $payloadRoot
        $newPayloadActivated = $true
        Move-Item -LiteralPath $manifestTemp -Destination $manifestPath
        $newManifestActivated = $true
        Move-Item -LiteralPath $verificationTemp -Destination $verificationPath
        $newVerificationActivated = $true
    } catch {
        if ($newPayloadActivated -and (Test-Path -LiteralPath $payloadRoot)) { Remove-Item -LiteralPath $payloadRoot -Recurse -Force -ErrorAction SilentlyContinue }
        if ($newManifestActivated -and (Test-Path -LiteralPath $manifestPath)) { Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue }
        if ($newVerificationActivated -and (Test-Path -LiteralPath $verificationPath)) { Remove-Item -LiteralPath $verificationPath -Force -ErrorAction SilentlyContinue }

        if ($hadPayload -and (Test-Path -LiteralPath $backupPayload)) { Move-Item -LiteralPath $backupPayload -Destination $payloadRoot }
        if ($hadManifest -and (Test-Path -LiteralPath $backupManifest)) { Move-Item -LiteralPath $backupManifest -Destination $manifestPath }
        if ($hadVerification -and (Test-Path -LiteralPath $backupVerification)) { Move-Item -LiteralPath $backupVerification -Destination $verificationPath }
        throw
    }

    foreach ($backup in @($backupPayload, $backupManifest, $backupVerification)) {
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Write-Host "Payload preparation succeeded." -ForegroundColor Green
    Write-Host "Payload:    $payloadRoot"
    Write-Host "Manifest:   $manifestPath"
    Write-Host "Files:      $($files.Count)"
    Write-Host "Version:    $AppVersion"
    $updaterState = if (Test-Path -LiteralPath (Join-Path $payloadRoot 'Updater\ArgonUpdater.exe')) { 'present' } else { 'not included yet' }
    Write-Host "Updater:    $updaterState"
} finally {
    if (Test-Path -LiteralPath $workingRoot) {
        Remove-Item -LiteralPath $workingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
