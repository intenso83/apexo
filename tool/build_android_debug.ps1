[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$requiredFlutterVersion = '3.38.1'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutterExecutable = $flutterCommand.Source
} else {
    $flutterExecutable = Join-Path $env:USERPROFILE `
        "develop\flutter-$requiredFlutterVersion\flutter\bin\flutter.bat"
    if (-not (Test-Path -LiteralPath $flutterExecutable)) {
        throw 'Flutter was not found. Add its bin folder to PATH before building Apexo.'
    }
}

$flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterExecutable)
$flutterVersionFile = Join-Path $flutterRoot 'bin\cache\flutter.version.json'
if (-not (Test-Path -LiteralPath $flutterVersionFile)) {
    throw 'Flutter version information was not found. Run flutter doctor once and try again.'
}
$flutterDetails = Get-Content -LiteralPath $flutterVersionFile -Raw | ConvertFrom-Json

if ($flutterDetails.frameworkVersion -ne $requiredFlutterVersion) {
    throw "Flutter $requiredFlutterVersion is required, but $($flutterDetails.frameworkVersion) is active."
}

$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (-not (Test-Path -LiteralPath (Join-Path $cargoBin 'cargo.exe'))) {
    throw 'Cargo was not found. Install Rust with rustup before building Apexo.'
}

# Flutter 3.38.1 contains a Windows launcher typo that can loop while taking
# its startup lock (https://github.com/flutter/flutter/issues/187907). Invoke
# the installed Flutter tool snapshot directly without modifying the SDK.
$dartExecutable = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$flutterToolPackages = Join-Path $flutterRoot `
    'packages\flutter_tools\.dart_tool\package_config.json'
$flutterToolSnapshot = Join-Path $flutterRoot 'bin\cache\flutter_tools.snapshot'
foreach ($requiredFile in @($dartExecutable, $flutterToolPackages, $flutterToolSnapshot)) {
    if (-not (Test-Path -LiteralPath $requiredFile)) {
        throw "Flutter tool file not found: $requiredFile"
    }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
    throw 'Visual Studio Build Tools was not found.'
}

$visualStudioPath = (& $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath).Trim()
if (-not $visualStudioPath) {
    throw 'Install the Visual Studio Desktop development with C++ workload.'
}

$vsDevCmd = Join-Path $visualStudioPath 'Common7\Tools\VsDevCmd.bat'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$quotedVsDevCmd = '"' + $vsDevCmd + '"'
$quotedRepositoryRoot = '"' + $repositoryRoot + '"'
$flutterTool = '"' + $dartExecutable + '" --packages="' + `
    $flutterToolPackages + '" "' + $flutterToolSnapshot + '"'

$buildCommand = @(
    "set `"PATH=$cargoBin;%PATH%`""
    "set `"FLUTTER_ROOT=$flutterRoot`""
    "call $quotedVsDevCmd -arch=x64 -host_arch=x64"
    "cd /d $quotedRepositoryRoot"
    "$flutterTool pub get"
    "$flutterTool build apk --debug"
) -join ' && '

& $env:ComSpec /d /s /c $buildCommand
if ($LASTEXITCODE -ne 0) {
    throw "The Android build failed with exit code $LASTEXITCODE."
}

Write-Host 'Apexo Android debug APK built successfully.'
