[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PocketBaseExecutable,

    [string]$WebBuild = 'build\web',

    [string]$OutputDirectory = 'output\portable-usb',

    [string]$Version = '',

    [string]$RequiredPocketBaseVersion = '0.40.1',

    [switch]$AllowStaleWebBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepositoryPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $repositoryRoot $Path)).Path
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionLine = Select-String -LiteralPath (Join-Path $repositoryRoot 'pubspec.yaml') `
        -Pattern '^version:\s*([^+\s]+)' | Select-Object -First 1
    if (-not $versionLine) {
        throw 'Could not read the application version from pubspec.yaml.'
    }
    $Version = $versionLine.Matches[0].Groups[1].Value
}
if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z.-]*$') {
    throw "Unsafe portable beta version: $Version"
}

$pocketBase = Resolve-RepositoryPath $PocketBaseExecutable
$webSource = Resolve-RepositoryPath $WebBuild
$templateSource = Join-Path $PSScriptRoot 'portable_usb'
if (-not (Test-Path -LiteralPath $templateSource -PathType Container)) {
    throw "Portable launcher templates are missing: $templateSource"
}
if ([IO.Path]::GetExtension($pocketBase) -ne '.exe') {
    throw 'PocketBaseExecutable must point to a Windows .exe file.'
}
if (-not (Test-Path -LiteralPath (Join-Path $webSource 'index.html') -PathType Leaf)) {
    throw "The web build does not contain index.html: $webSource"
}
if (-not (Test-Path -LiteralPath (Join-Path $webSource 'main.dart.js') -PathType Leaf)) {
    throw "The web build does not contain main.dart.js: $webSource"
}

$sourceFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'lib') -Recurse -File
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'web') -Recurse -File
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'assets') -Recurse -File
    Get-Item -LiteralPath (Join-Path $repositoryRoot 'pubspec.yaml')
    Get-Item -LiteralPath (Join-Path $repositoryRoot 'pubspec.lock')
)
$newestSource = $sourceFiles | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$webEntrypoint = Get-Item -LiteralPath (Join-Path $webSource 'main.dart.js')
$webBuildIsStale = $webEntrypoint.LastWriteTimeUtc -lt $newestSource.LastWriteTimeUtc
if ($webBuildIsStale -and -not $AllowStaleWebBuild) {
    throw "The web build predates source file $($newestSource.FullName). Run 'flutter build web --release' first."
}

$reportedVersion = (& $pocketBase --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or
    $reportedVersion -notmatch "version\s+$([regex]::Escape($RequiredPocketBaseVersion))$") {
    throw "PocketBase $RequiredPocketBaseVersion is required; executable reported: $reportedVersion"
}

# The template must never accidentally absorb databases, credentials, or a
# previous private portable instance. Only the compiled static web directory,
# the exact PocketBase executable, and tracked server extensions are copied.
$forbiddenWebFiles = Get-ChildItem -LiteralPath $webSource -Recurse -File | Where-Object {
    $_.Name -match '(^\.env($|\.)|\.sqlite3?$|\.db$|\.key$|\.pem$|\.pfx$|\.p12$|\.dcm$|\.mdb$|\.accdb$|credentials|secret)' -or
    $_.FullName -match '(^|[\\/])pb_data([\\/]|$)'
}
if ($forbiddenWebFiles) {
    $names = ($forbiddenWebFiles | Select-Object -ExpandProperty FullName) -join [Environment]::NewLine
    throw "Refusing a web build containing possible private data or credentials:$([Environment]::NewLine)$names"
}

$commit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Could not read the source Git commit.'
}
$workingTreeChanges = @(& git -C $repositoryRoot status --porcelain=v1 `
        --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
    throw 'Could not verify that the source Git working tree is clean.'
}
if ($workingTreeChanges.Count -gt 0) {
    throw 'Refusing to package a dirty Git working tree. Commit the reviewed beta first so the archive can be reproduced from BUILD_MANIFEST.txt.'
}
$workingTreeState = 'CLEAN'

if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    $outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
} else {
    $outputRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
}
$releaseName = "Apexo-Portable-USB-Template-$Version"
$releaseRoot = Join-Path $outputRoot $releaseName
$archivePath = Join-Path $outputRoot "$releaseName.zip"
$checksumPath = "$archivePath.sha256"

foreach ($target in @($releaseRoot, $archivePath, $checksumPath)) {
    if (Test-Path -LiteralPath $target) {
        throw "Refusing to overwrite an existing portable artifact: $target"
    }
}

$webTarget = Join-Path $releaseRoot 'App\Web'
$serverTarget = Join-Path $releaseRoot 'Server'
$dataTarget = Join-Path $releaseRoot 'Data'
$backupTarget = Join-Path $releaseRoot 'Backups'
New-Item -ItemType Directory -Path $webTarget, $serverTarget, $dataTarget, $backupTarget | Out-Null

Copy-Item -Path (Join-Path $webSource '*') -Destination $webTarget -Recurse -Force
Copy-Item -LiteralPath $pocketBase -Destination (Join-Path $serverTarget 'pocketbase.exe')

# Keep these allowlists explicit so an ignored database, credential, or scratch
# file dropped beside the sources can never enter the distributable template.
$serverExtensionFiles = @(
    'pb_hooks\apexo_intake.pb.js'
    'pb_migrations\1788372000_create_patient_intake.js'
    'pb_migrations\1788544800_add_intake_pdf.js'
)
foreach ($relative in $serverExtensionFiles) {
    $source = Join-Path (Join-Path $repositoryRoot 'server\pocketbase') $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required tracked server extension is missing: $source"
    }
    $destination = Join-Path $serverTarget $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
}

$portableTemplateFiles = @(
    'Backup-Apexo.cmd'
    'Backup-Apexo.ps1'
    'Initialize-Apexo.cmd'
    'Initialize-Apexo.ps1'
    'Portable-Browser.ps1'
    'Start-Apexo.cmd'
    'Start-Apexo.ps1'
    'START_HERE.md'
    'Verify-Apexo.cmd'
    'Verify-Apexo.ps1'
)
foreach ($relative in $portableTemplateFiles) {
    $source = Join-Path $templateSource $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required portable launcher file is missing: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $releaseRoot $relative)
}
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'docs\PORTABLE_USB_BETA.md') `
    -Destination (Join-Path $releaseRoot 'PORTABLE_USB_BETA.md')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSE.md') `
    -Destination (Join-Path $releaseRoot 'LICENSE.md')

Set-Content -LiteralPath (Join-Path $dataTarget 'README.txt') -Encoding utf8 -Value @(
    'This distributable template intentionally contains no pb_data or BrowserProfile directory.'
    'Initialize-Apexo creates a private database here; Start-Apexo creates the dedicated Edge/Chrome profile here.'
    'Both directories may contain patient/session data and must remain on the encrypted USB drive.'
    'Never place initialized data in the distributable template or source repository.'
)
Set-Content -LiteralPath (Join-Path $backupTarget 'README.txt') -Encoding utf8 -Value @(
    'Automatic offline backups of pb_data and, once created, BrowserProfile are written here before and after each normal session.'
    'These copies are on the same USB and therefore are not an independent backup.'
    'After stopping Apexo, copy a verified backup to a separate encrypted drive.'
)

$webEntrypointHash = (Get-FileHash -LiteralPath $webEntrypoint.FullName `
        -Algorithm SHA256).Hash.ToLowerInvariant()
$pocketBaseHash = (Get-FileHash -LiteralPath (Join-Path $serverTarget 'pocketbase.exe') `
        -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $serverTarget 'pocketbase.exe.sha256') `
    -Encoding ascii -Value "$pocketBaseHash  pocketbase.exe"

$manifest = @(
    "Apexo portable USB empty template $Version"
    "Git commit: $commit"
    "Git working tree: $workingTreeState"
    "Built UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    "Web main.dart.js SHA-256: $webEntrypointHash"
    "Web freshness: $(if ($webBuildIsStale) { 'STALE OVERRIDE' } else { 'fresh relative to lib/web/assets/pubspec inputs' })"
    "PocketBase: $RequiredPocketBaseVersion"
    "PocketBase SHA-256: $pocketBaseHash"
    'Interface: browser at http://127.0.0.1:61110'
    'Server exposure: IPv4 loopback only'
    'Template data: EMPTY (no pb_data, BrowserProfile, patient data, credentials, or OAuth tokens)'
)
Set-Content -LiteralPath (Join-Path $releaseRoot 'BUILD_MANIFEST.txt') `
    -Value $manifest -Encoding utf8

$hashManifestPath = Join-Path $releaseRoot 'FILE_HASHES.sha256'
$hashLines = Get-ChildItem -LiteralPath $releaseRoot -Recurse -File |
    Where-Object { $_.FullName -ne $hashManifestPath } |
    ForEach-Object {
        $relative = $_.FullName.Substring($releaseRoot.Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $relative"
    } |
    Sort-Object
Set-Content -LiteralPath $hashManifestPath -Value $hashLines -Encoding ascii

Compress-Archive -LiteralPath $releaseRoot -DestinationPath $archivePath `
    -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$archiveHash  $releaseName.zip" -Encoding ascii

Write-Host "Empty portable template: $archivePath"
Write-Host "SHA-256: $archiveHash"
Write-Host 'No patient data or credentials were included.'
