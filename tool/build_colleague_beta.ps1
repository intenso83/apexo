[CmdletBinding()]
param(
    [string]$Version = '0.15.0-beta.3'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$requiredFlutterVersion = '3.47.1'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repositoryRoot 'output\beta'
$releaseName = "Apexo-Clinical-Beta-$Version"
$releaseRoot = Join-Path $outputRoot $releaseName
$archivePath = Join-Path $outputRoot "$releaseName.zip"
$checksumPath = "$archivePath.sha256"

foreach ($existing in @($releaseRoot, $archivePath, $checksumPath)) {
    if (Test-Path -LiteralPath $existing) {
        throw "Refusing to overwrite an existing beta artifact: $existing"
    }
}

$flutterRoot = $null
foreach ($candidate in @(
        (Join-Path $env:USERPROFILE "develop\flutter-$requiredFlutterVersion\flutter"),
        (Join-Path $env:USERPROFILE 'develop\flutter')
    )) {
    $versionFile = Join-Path $candidate 'bin\cache\flutter.version.json'
    if (-not (Test-Path -LiteralPath $versionFile)) {
        continue
    }
    $details = Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json
    if ($details.frameworkVersion -eq $requiredFlutterVersion) {
        $flutterRoot = $candidate
        break
    }
}
if (-not $flutterRoot) {
    throw "Flutter $requiredFlutterVersion was not found in the supported SDK locations."
}

$flutterExecutable = Join-Path $flutterRoot 'bin\flutter.bat'
$flutterBin = Join-Path $flutterRoot 'bin'
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
$vswhere = Join-Path ${env:ProgramFiles(x86)} `
    'Microsoft Visual Studio\Installer\vswhere.exe'
$visualStudioPath = (& $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath).Trim()
if (-not $visualStudioPath) {
    throw 'Visual Studio Desktop development with C++ is required.'
}

$vsDevCmd = Join-Path $visualStudioPath 'Common7\Tools\VsDevCmd.bat'
$baseCommand = @(
    "set `"PATH=$flutterBin;$cargoBin;%PATH%`""
    "set `"FLUTTER_ROOT=$flutterRoot`""
    "call `"$vsDevCmd`" -arch=x64 -host_arch=x64"
    "cd /d `"$repositoryRoot`""
) -join ' && '

& $env:ComSpec /d /s /c "$baseCommand && `"$flutterExecutable`" pub get"
if ($LASTEXITCODE -ne 0) {
    throw "Flutter dependency resolution failed with exit code $LASTEXITCODE."
}

& $env:ComSpec /d /s /c `
    "$baseCommand && `"$flutterExecutable`" build windows --release"
$windowsBuild = Join-Path $repositoryRoot 'build\windows\x64\runner\Release'
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Flutter could not use the registered Visual Studio CMake component; using the verified portable CMake/Ninja fallback.'

    $cmakeVersion = '4.4.3'
    $cmakeHash = '4d52ebab7193a698651639ed80d8d04fd903358843572cf44c7fd234cb7c26ab'
    $toolCache = Join-Path $repositoryRoot 'output\tool-cache'
    $cmakeArchive = Join-Path $toolCache "cmake-$cmakeVersion-windows-x86_64.zip"
    $cmakeExtracted = Join-Path $toolCache "cmake-$cmakeVersion"
    $cmakeRoot = Join-Path $cmakeExtracted "cmake-$cmakeVersion-windows-x86_64"
    $cmakeExecutable = Join-Path $cmakeRoot 'bin\cmake.exe'
    New-Item -ItemType Directory -Path $toolCache -Force | Out-Null
    if (-not (Test-Path -LiteralPath $cmakeArchive)) {
        Invoke-WebRequest `
            -Uri "https://github.com/Kitware/CMake/releases/download/v$cmakeVersion/cmake-$cmakeVersion-windows-x86_64.zip" `
            -OutFile $cmakeArchive
    }
    $actualHash = (Get-FileHash -LiteralPath $cmakeArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $cmakeHash) {
        throw "Portable CMake checksum mismatch: $actualHash"
    }
    if (-not (Test-Path -LiteralPath $cmakeExecutable)) {
        Expand-Archive -LiteralPath $cmakeArchive -DestinationPath $cmakeExtracted
    }
    $ninjaExecutable = Get-ChildItem `
        -LiteralPath (Join-Path $env:LOCALAPPDATA 'Android\sdk\cmake') `
        -Filter ninja.exe -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $ninjaExecutable) {
        throw 'Ninja was not found in the local Android SDK CMake tools.'
    }

    $flutterEngine = Join-Path $flutterRoot 'bin\cache\artifacts\engine\windows-x64'
    Copy-Item -LiteralPath (Join-Path $flutterEngine 'flutter_windows.dll.lib') `
        -Destination (Join-Path $repositoryRoot 'windows\flutter\ephemeral\flutter_windows.dll.lib') `
        -Force

    $flutterConfig = & $flutterExecutable config --machine | ConvertFrom-Json
    $javaHome = $flutterConfig.'jdk-dir'
    if (-not $javaHome) {
        throw 'Flutter must have a JDK configured for the Windows JNI plugin.'
    }

    $fallbackBuild = Join-Path $repositoryRoot "build\beta_windows\$Version\x64"
    $cmakeBin = Join-Path $cmakeRoot 'bin'
    $ninjaBin = Split-Path -Parent $ninjaExecutable
    $fallbackCommand = @(
        "set `"PATH=$flutterBin;$cmakeBin;$ninjaBin;$cargoBin;%PATH%`""
        "set `"FLUTTER_ROOT=$flutterRoot`""
        "set `"JAVA_HOME=$javaHome`""
        "call `"$vsDevCmd`" -arch=x64 -host_arch=x64"
        "cd /d `"$repositoryRoot`""
        "`"$cmakeExecutable`" -S windows -B `"$fallbackBuild`" -G Ninja -DCMAKE_BUILD_TYPE=Release -DFLUTTER_TARGET_PLATFORM=windows-x64"
        "`"$cmakeExecutable`" --build `"$fallbackBuild`" --target install"
    ) -join ' && '
    & $env:ComSpec /d /s /c $fallbackCommand
    if ($LASTEXITCODE -ne 0) {
        throw "The fallback Windows beta build failed with exit code $LASTEXITCODE."
    }
    $windowsBuild = Join-Path $fallbackBuild 'runner'
}

& $env:ComSpec /d /s /c `
    "$baseCommand && `"$flutterExecutable`" build web --release"
if ($LASTEXITCODE -ne 0) {
    throw "The Web beta build failed with exit code $LASTEXITCODE."
}

$webBuild = Join-Path $repositoryRoot 'build\web'
$windowsTarget = Join-Path $releaseRoot 'Apexo-Windows-Portable'
$webTarget = Join-Path $releaseRoot 'Apexo-Web'
New-Item -ItemType Directory -Path $windowsTarget -Force | Out-Null
New-Item -ItemType Directory -Path $webTarget -Force | Out-Null
Copy-Item -Path (Join-Path $windowsBuild '*') -Destination $windowsTarget `
    -Recurse -Force
Copy-Item -Path (Join-Path $webBuild '*') -Destination $webTarget `
    -Recurse -Force
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'docs\BETA_RELEASE_0_15_0.html') `
    -Destination (Join-Path $releaseRoot 'START_HERE.html')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'docs\BETA_RELEASE_0_15_0.md') `
    -Destination (Join-Path $releaseRoot 'RELEASE_NOTES.md')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSE.md') `
    -Destination (Join-Path $releaseRoot 'LICENSE.md')

$sourceArchive = Join-Path $releaseRoot "Apexo-Source-$Version.zip"
& git -C $repositoryRoot archive --format=zip --output=$sourceArchive HEAD
if ($LASTEXITCODE -ne 0) {
    throw 'Could not create the corresponding source archive.'
}

$commit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$manifest = @(
    "Apexo Clinical Beta $Version"
    "Git commit: $commit"
    "Built UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    'Platforms: Windows x64 portable, static web bundle'
    'No credentials, OAuth tokens, PocketBase data, or patient data are included.'
)
Set-Content -LiteralPath (Join-Path $releaseRoot 'BUILD_MANIFEST.txt') `
    -Value $manifest -Encoding utf8

Compress-Archive -LiteralPath $releaseRoot -DestinationPath $archivePath `
    -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  $releaseName.zip" -Encoding ascii

Write-Host "Beta package: $archivePath"
Write-Host "SHA-256: $hash"
