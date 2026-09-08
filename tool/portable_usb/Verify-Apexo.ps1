[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-ApexoManifestCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $normalizedRelative = $RelativePath.Replace('\', '/')
    $segments = @($normalizedRelative -split '/')
    if ([string]::IsNullOrWhiteSpace($normalizedRelative) -or
        [IO.Path]::IsPathRooted($normalizedRelative) -or
        $normalizedRelative.Contains(':') -or
        $segments -contains '' -or
        $segments -contains '.' -or
        $segments -contains '..') {
        throw "Unsafe checksum path in manifest: $RelativePath"
    }

    $rootFullPath = [IO.Path]::GetFullPath($Root)
    $rootPrefix = $rootFullPath.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    $platformRelative = $normalizedRelative.Replace(
        '/',
        [IO.Path]::DirectorySeparatorChar
    )
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFullPath $platformRelative))
    if (-not $candidate.StartsWith(
            $rootPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Unsafe checksum path in manifest: $RelativePath"
    }
    return $candidate
}

function ConvertTo-ApexoManifestRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $rootFullPath = [IO.Path]::GetFullPath($Root)
    $rootPrefix = $rootFullPath.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath($FullPath)
    if (-not $candidate.StartsWith(
            $rootPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Path is outside the portable bundle: $FullPath"
    }
    return $candidate.Substring($rootPrefix.Length).Replace('\', '/')
}

$bundleRoot = $PSScriptRoot
$pocketBase = Join-Path $bundleRoot 'Server\pocketbase.exe'
$expectedHashFile = Join-Path $bundleRoot 'Server\pocketbase.exe.sha256'
$fileHashManifest = Join-Path $bundleRoot 'FILE_HASHES.sha256'
$browserHelper = Join-Path $bundleRoot 'Portable-Browser.ps1'
$required = @(
    $pocketBase
    $expectedHashFile
    $fileHashManifest
    (Join-Path $bundleRoot 'App\Web\index.html')
    (Join-Path $bundleRoot 'App\Web\google_calendar_oauth.js')
    (Join-Path $bundleRoot 'Start-Apexo.ps1')
    (Join-Path $bundleRoot 'Backup-Apexo.ps1')
    $browserHelper
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Portable bundle verification failed; missing: $path"
    }
}

. $browserHelper

$expectedHash = ((Get-Content -LiteralPath $expectedHashFile -Raw).Trim() -split '\s+')[0]
$actualHash = (Get-FileHash -LiteralPath $pocketBase -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expectedHash -ne $actualHash) {
    throw 'PocketBase checksum mismatch. Do not run this bundle.'
}

$manifestPaths = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase
)
foreach ($line in Get-Content -LiteralPath $fileHashManifest) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
        throw "Invalid checksum manifest line: $line"
    }
    $expected = $Matches[1].ToLowerInvariant()
    $manifestRelative = $Matches[2].Replace('\', '/')
    $null = $manifestPaths.Add($manifestRelative)
    $relative = $manifestRelative.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $candidate = Resolve-ApexoManifestCandidate `
        -Root $bundleRoot -RelativePath $manifestRelative
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Portable bundle checksum failed; missing: $relative"
    }
    $candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($candidateHash -ne $expected) {
        throw "Portable bundle checksum mismatch: $relative"
    }
}

# Data and Backups intentionally gain private/runtime files after first use.
# Everything at bundle root and beneath App/Server is immutable executable or
# documentation content: reject additions there, including an unmanifested
# PocketBase hook/migration that would otherwise execute despite hash checks.
$immutableItems = @(
    Get-ChildItem -LiteralPath $bundleRoot -Force
    Get-ChildItem -LiteralPath (Join-Path $bundleRoot 'App') -Force -Recurse
    Get-ChildItem -LiteralPath (Join-Path $bundleRoot 'Server') -Force -Recurse
)
$unexpectedReparsePoint = $immutableItems |
    Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 } |
    Select-Object -First 1
if ($null -ne $unexpectedReparsePoint) {
    throw "Portable bundle verification failed; links/reparse points are not allowed in immutable content: $($unexpectedReparsePoint.FullName)"
}
$unexpectedFiles = @($immutableItems | Where-Object {
        -not $_.PSIsContainer -and $_.FullName -ne $fileHashManifest
    } | Where-Object {
        $relative = ConvertTo-ApexoManifestRelativePath `
            -Root $bundleRoot -FullPath $_.FullName
        -not $manifestPaths.Contains($relative)
    } | ForEach-Object {
        ConvertTo-ApexoManifestRelativePath `
            -Root $bundleRoot -FullPath $_.FullName
    })
if ($unexpectedFiles) {
    throw "Portable bundle verification failed; unmanifested immutable file(s): $($unexpectedFiles -join ', ')"
}

$reportedVersion = (& $pocketBase --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'PocketBase could not be executed.'
}

$database = Join-Path $bundleRoot 'Data\pb_data\data.db'
$runningMarker = Join-Path $bundleRoot 'Data\RUNNING.lock'
$browserProfile = Join-Path $bundleRoot 'Data\BrowserProfile'
$browserSessionMarker = Join-Path $bundleRoot 'Data\BROWSER_RUNNING.lock'
$browserProfileExists = Test-Path -LiteralPath $browserProfile -PathType Container
$browserProfileItem = Get-ChildItem -LiteralPath $browserProfile -Force `
    -ErrorAction SilentlyContinue | Select-Object -First 1
$browserProfilePopulated = $null -ne $browserProfileItem
$databaseExists = Test-Path -LiteralPath $database -PathType Leaf
$state = if ($databaseExists -or $browserProfileExists -or
    (Test-Path -LiteralPath $browserSessionMarker)) {
    'PRIVATE/INITIALIZED - this copy may contain clinical data'
} else {
    'EMPTY TEMPLATE - no initialized database or portable browser profile'
}

Write-Host 'Portable bundle verification passed (all packaged files match the manifest).'
Write-Host $reportedVersion
Write-Host "Data state: $state"
Write-Host 'Server exposure when started: 127.0.0.1:61110 only'
if ($browserProfilePopulated) {
    Write-Host 'Browser data: PORTABLE - Data\BrowserProfile contains the dedicated Edge/Chrome profile.'
} else {
    Write-Host 'Browser data: NOT CREATED - the dedicated profile is created on first start.'
}
if (Test-Path -LiteralPath $runningMarker) {
    Write-Warning 'A RUNNING marker exists. Confirm Apexo is stopped before backup or USB removal.'
}
$browserUsage = Get-ApexoPortableBrowserProfileUsage `
    -ProfileDirectory $browserProfile -SessionMarker $browserSessionMarker
if ($browserUsage.InUse) {
    Write-Warning "The portable browser profile is still in use: $($browserUsage.Detail). Close it normally before backup or USB removal."
} elseif (Test-Path -LiteralPath $browserSessionMarker) {
    Write-Warning 'A stale BROWSER_RUNNING marker exists. No matching process/profile lock was found; run Start-Apexo normally to clear it.'
}
if (-not [string]::IsNullOrWhiteSpace($browserUsage.InspectionWarning)) {
    Write-Warning $browserUsage.InspectionWarning
}

if ($browserProfilePopulated) {
    $browserReparsePoint = Get-ChildItem -LiteralPath $browserProfile -Force -Recurse |
        Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 } |
        Select-Object -First 1
    if ($null -ne $browserReparsePoint) {
        Write-Warning "The portable browser profile contains a link/reparse point and cannot be safely archived: $($browserReparsePoint.FullName)"
    }
}

try {
    $volumeRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($bundleRoot))
    $bitLocker = Get-BitLockerVolume -MountPoint $volumeRoot -ErrorAction Stop
    Write-Host "BitLocker protection: $($bitLocker.ProtectionStatus)"
    if ($bitLocker.ProtectionStatus -ne 'On') {
        Write-Warning 'Do not place real patient data on this drive until full-volume encryption is enabled.'
    }
} catch {
    Write-Warning 'BitLocker status could not be verified. Confirm the entire USB volume is encrypted before using real patient data.'
}
