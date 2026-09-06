[CmdletBinding()]
param(
    [string]$Destination = '',
    [ValidatePattern('^[0-9A-Za-z-]+$')]
    [string]$Label = 'manual',
    [int]$LauncherOwnerPid = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bundleRoot = $PSScriptRoot
$dataRoot = Join-Path $bundleRoot 'Data'
$dataDirectory = Join-Path $dataRoot 'pb_data'
$browserProfile = Join-Path $dataRoot 'BrowserProfile'
$database = Join-Path $dataDirectory 'data.db'
$runningMarker = Join-Path $dataRoot 'RUNNING.lock'
$launcherGuard = Join-Path $dataRoot 'LAUNCHER.lock'
$browserSessionMarker = Join-Path $dataRoot 'BROWSER_RUNNING.lock'
$pocketBase = Join-Path $bundleRoot 'Server\pocketbase.exe'
$browserHelper = Join-Path $bundleRoot 'Portable-Browser.ps1'

if (-not (Test-Path -LiteralPath $browserHelper -PathType Leaf)) {
    throw "The portable browser safety helper is missing: $browserHelper"
}
. $browserHelper

function Test-BundledPocketBaseProcess {
    $expected = [IO.Path]::GetFullPath($pocketBase)
    foreach ($process in @(Get-Process -Name 'pocketbase' -ErrorAction SilentlyContinue)) {
        try {
            if ([IO.Path]::GetFullPath($process.Path).Equals(
                    $expected, [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } catch {
            # An inaccessible process is not assumed to own this exact bundle.
        }
    }
    return $false
}

if (Test-Path -LiteralPath $launcherGuard -PathType Leaf) {
    $launcherPid = 0
    $launcherLine = Get-Content -LiteralPath $launcherGuard -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^Launcher PID:\s*(\d+)\s*$' } |
        Select-Object -First 1
    $lineHasPid = $null -ne $launcherLine -and
        $launcherLine -match '^Launcher PID:\s*(\d+)\s*$'
    if ($lineHasPid) {
        $launcherPid = [int]$Matches[1]
    }
    $ownedByCallingLauncher = $lineHasPid -and $LauncherOwnerPid -gt 0 -and
        $launcherPid -eq $LauncherOwnerPid
    if (-not $ownedByCallingLauncher) {
        throw 'Refusing to back up while another Start-Apexo launcher owns this portable instance.'
    }
}

if ((Test-Path -LiteralPath $runningMarker) -or (Test-BundledPocketBaseProcess)) {
    throw 'Refusing an online file copy. Stop Apexo normally before backing up pb_data.'
}
$browserUsage = Get-ApexoPortableBrowserProfileUsage `
    -ProfileDirectory $browserProfile -SessionMarker $browserSessionMarker
if ($browserUsage.InUse) {
    throw "Refusing an online browser-profile copy: $($browserUsage.Detail). Close every dedicated Apexo browser window normally and retry; this script will not force-close it."
}
if (-not [string]::IsNullOrWhiteSpace($browserUsage.InspectionWarning)) {
    Write-Warning $browserUsage.InspectionWarning
    Write-Warning 'No live portable-profile lock was found. Confirm the dedicated Apexo browser window is closed.'
}
if (Test-Path -LiteralPath $browserSessionMarker) {
    Write-Warning 'A stale BROWSER_RUNNING marker exists, but its browser process and profile locks are not active.'
}
if (-not (Test-Path -LiteralPath $database -PathType Leaf)) {
    throw 'No initialized PocketBase database was found to back up.'
}
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path $bundleRoot 'Backups'
}
if (-not [IO.Path]::IsPathRooted($Destination)) {
    $Destination = Join-Path $bundleRoot $Destination
}
$Destination = [IO.Path]::GetFullPath($Destination)
$sourceDirectories = @($dataDirectory)
$sourceNames = @('pb_data')
$includeBrowserProfile = Test-Path -LiteralPath $browserProfile -PathType Container
if ($includeBrowserProfile) {
    $sourceDirectories += $browserProfile
    $sourceNames += 'BrowserProfile'
}
foreach ($sourceDirectory in $sourceDirectories) {
    $sourceFullPath = [IO.Path]::GetFullPath($sourceDirectory)
    if ($Destination.StartsWith($sourceFullPath + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase) -or
        $Destination.Equals($sourceFullPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The backup destination cannot be inside a source data directory: $sourceFullPath"
    }
}

$reparsePoints = @()
foreach ($sourceDirectory in $sourceDirectories) {
    $reparsePoints += @(Get-ChildItem -LiteralPath $sourceDirectory -Force -Recurse |
            Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 })
}
if ($reparsePoints) {
    $names = ($reparsePoints | Select-Object -ExpandProperty FullName) -join [Environment]::NewLine
    throw "Refusing to archive data containing links/reparse points that could escape the portable data directories:$([Environment]::NewLine)$names"
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$sourceFiles = @($sourceDirectories | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -File -Force -Recurse
    })
$sourceMeasure = $sourceFiles | Measure-Object -Property Length -Sum
$sourceBytes = if ($null -eq $sourceMeasure) { 0 } else { $sourceMeasure.Sum }
try {
    $destinationRoot = [IO.Path]::GetPathRoot($Destination)
    $destinationDrive = [IO.DriveInfo]::new($destinationRoot)
    $requiredFreeBytes = [int64]$sourceBytes + 64MB
    if ($destinationDrive.AvailableFreeSpace -lt $requiredFreeBytes) {
        throw "The backup destination has $($destinationDrive.AvailableFreeSpace) bytes free; at least $requiredFreeBytes bytes are required for a safe archive attempt."
    }
} catch {
    if ($_.Exception.Message -like 'The backup destination has *') {
        throw
    }
    Write-Warning "Free-space preflight was unavailable for '$Destination': $($_.Exception.Message)"
}

$existingArchives = @(Get-ChildItem -LiteralPath $Destination `
        -Filter 'Apexo-portable-data-*.zip' -File -ErrorAction SilentlyContinue)
$existingArchiveMeasure = $existingArchives | Measure-Object -Property Length -Sum
$existingArchiveBytes = if ($null -eq $existingArchiveMeasure) {
    0
} else {
    $existingArchiveMeasure.Sum
}
if ($existingArchives.Count -ge 20 -or $existingArchiveBytes -ge 20GB) {
    Write-Warning 'Portable backups are accumulating in this destination. They are never auto-deleted; after verifying independent encrypted copies, review retention and remove obsolete archives manually.'
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$archive = Join-Path $Destination "Apexo-portable-data-$Label-$timestamp.zip"
$checksum = "$archive.sha256"
if ((Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $checksum)) {
    throw "Refusing to overwrite an existing backup: $archive"
}

$tar = Get-Command tar.exe -ErrorAction SilentlyContinue
if ($tar) {
    Push-Location -LiteralPath $dataRoot
    try {
        & $tar.Source -a -c -f $archive @sourceNames
        if ($LASTEXITCODE -ne 0) {
            throw "tar.exe failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
    $listing = @(& $tar.Source -t -f $archive) |
        ForEach-Object { $_.Replace('\', '/') }
    if ($LASTEXITCODE -ne 0 -or -not ($listing -match '(^|/)pb_data/data\.db$')) {
        throw 'The new backup could not be verified as a complete pb_data archive.'
    }
    if ($includeBrowserProfile -and
        -not ($listing -match '(^|/)BrowserProfile(/|$)')) {
        throw 'The new backup could not be verified as containing the portable browser profile.'
    }
} else {
    if ($includeBrowserProfile) {
        throw 'tar.exe is required to safely preserve the portable Chromium profile, but it is unavailable. No complete backup was made.'
    }
    $largestFile = Get-ChildItem -LiteralPath $dataDirectory -Recurse -File |
        Sort-Object Length -Descending | Select-Object -First 1
    if ($largestFile -and $largestFile.Length -ge 2GB) {
        throw 'tar.exe is unavailable and Compress-Archive cannot safely package this database. No backup was made.'
    }
    Compress-Archive -LiteralPath $dataDirectory -DestinationPath $archive `
        -CompressionLevel Optimal
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $hasDatabase = $false
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName.Replace('\', '/') -eq 'pb_data/data.db') {
                $hasDatabase = $true
                break
            }
        }
        if (-not $hasDatabase) {
            throw 'The new backup could not be verified as a complete pb_data archive.'
        }
    } finally {
        $zip.Dispose()
    }
}

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksum -Value "$hash  $([IO.Path]::GetFileName($archive))" -Encoding ascii
Write-Host "Verified offline backup: $archive"
Write-Host "SHA-256: $hash"
if ($includeBrowserProfile) {
    Write-Host 'Included: pb_data and the portable BrowserProfile (including browser-local Apexo data/session state).'
} else {
    Write-Host 'Included: pb_data. No portable browser profile exists yet.'
}

$bundleVolume = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($bundleRoot))
$backupVolume = [IO.Path]::GetPathRoot($archive)
if ($bundleVolume.Equals($backupVolume, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning 'This backup is on the same drive as the database. Copy a verified backup to a separate encrypted drive after the session.'
}
