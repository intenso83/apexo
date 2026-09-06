[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bundleRoot = $PSScriptRoot
$serverDirectory = Join-Path $bundleRoot 'Server'
$pocketBase = Join-Path $serverDirectory 'pocketbase.exe'
$webIndex = Join-Path $bundleRoot 'App\Web\index.html'
$dataRoot = Join-Path $bundleRoot 'Data'
$database = Join-Path $dataRoot 'pb_data\data.db'
$browserProfile = Join-Path $dataRoot 'BrowserProfile'
$browserSessionMarker = Join-Path $dataRoot 'BROWSER_RUNNING.lock'
$runningMarker = Join-Path $dataRoot 'RUNNING.lock'
$launcherGuard = Join-Path $dataRoot 'LAUNCHER.lock'
$browserHelper = Join-Path $bundleRoot 'Portable-Browser.ps1'
$url = 'http://127.0.0.1:61110'

foreach ($required in @($pocketBase, $webIndex, $browserHelper)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "The portable bundle is incomplete: $required"
    }
}
if (-not (Test-Path -LiteralPath $database -PathType Leaf)) {
    throw 'The server has not been initialized. Run Initialize-Apexo.cmd first.'
}
if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
    throw 'Windows tar.exe is required before starting: the session will create/use BrowserProfile, which must be included safely in pre/post-session ZIP backups.'
}

. $browserHelper

function Test-LoopbackPort {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync('127.0.0.1', 61110)
        return $task.Wait(300) -and $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

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

function Wait-ApexoPortableBrowserProfile {
    $announced = $false
    while ($true) {
        $usage = Get-ApexoPortableBrowserProfileUsage `
            -ProfileDirectory $browserProfile -SessionMarker $browserSessionMarker
        if (-not $usage.InUse) {
            if (-not [string]::IsNullOrWhiteSpace($usage.InspectionWarning)) {
                Write-Warning $usage.InspectionWarning
                Write-Warning 'No live profile lock was found; continuing with the offline backup.'
            }
            return
        }
        if ($usage.Detail -like 'Windows could not verify*') {
            throw "The browser profile cannot be proven offline: $($usage.InspectionWarning) No backup was attempted. Keep the USB connected, close the dedicated browser normally, resolve Windows process-inspection permissions, and run Backup-Apexo.cmd."
        }
        if (-not $announced) {
            Write-Warning "The dedicated Apexo browser profile is still in use: $($usage.Detail)."
            Write-Warning 'Close every Edge/Chrome window opened for Apexo. The browser will not be force-closed; this launcher will wait before backing up.'
            $announced = $true
        }
        Start-Sleep -Seconds 1
    }
}

if (Test-LoopbackPort) {
    throw 'Port 61110 is already in use. Refusing to start a second server.'
}
if (Test-BundledPocketBaseProcess) {
    throw 'This portable PocketBase executable is already running. Refusing to start or back up a second session.'
}
$initialBrowserUsage = Get-ApexoPortableBrowserProfileUsage `
    -ProfileDirectory $browserProfile -SessionMarker $browserSessionMarker
if ($initialBrowserUsage.InUse) {
    throw "The dedicated Apexo browser profile is already in use ($($initialBrowserUsage.Detail)). Close that browser normally before starting another session."
}
if (-not [string]::IsNullOrWhiteSpace($initialBrowserUsage.InspectionWarning)) {
    throw "Browser process inspection is required for safe portable-profile shutdown, but it failed: $($initialBrowserUsage.InspectionWarning)"
}
if (Test-Path -LiteralPath $browserSessionMarker) {
    Write-Warning 'Removing a stale browser session marker left by an earlier interrupted launcher.'
    Remove-Item -LiteralPath $browserSessionMarker -Force
}
if (Test-Path -LiteralPath $launcherGuard) {
    Write-Warning 'Removing a stale launcher guard left by an earlier interrupted session.'
    Remove-Item -LiteralPath $launcherGuard -Force
}
if (Test-Path -LiteralPath $runningMarker) {
    Write-Warning 'Removing a stale RUNNING marker left by an earlier interrupted session.'
    Remove-Item -LiteralPath $runningMarker -Force
}

$serverArguments = @(
    'serve'
    '--http=127.0.0.1:61110'
    '--dir=..\Data\pb_data'
    '--publicDir=..\App\Web'
    '--migrationsDir=pb_migrations'
    '--hooksDir=pb_hooks'
    '--origins=http://127.0.0.1:61110'
)

$guardStream = $null
$serverProcess = $null
$sessionStarted = $false
try {
    try {
        $guardStream = [IO.File]::Open(
            $launcherGuard,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::Read
        )
    } catch [IO.IOException] {
        throw 'Another launcher already owns this portable instance. Refusing a concurrent start.'
    }
    $guardText = [Text.Encoding]::UTF8.GetBytes(
        "Launcher PID: $PID`r`nStarted UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))`r`n"
    )
    $guardStream.Write($guardText, 0, $guardText.Length)
    $guardStream.Flush($true)

    $browser = Get-ApexoPortableBrowser

    # The server is stopped here, so this is an offline, coherent pre-session copy.
    & (Join-Path $bundleRoot 'Backup-Apexo.ps1') `
        -Destination (Join-Path $bundleRoot 'Backups') -Label 'pre-session' `
        -LauncherOwnerPid $PID

    Write-Host ''
    Write-Host "PocketBase will open in its own Apexo Server window, followed by Apexo in a dedicated $($browser.Name) window."
    Write-Host 'The dedicated browser profile is stored on this USB under Data\BrowserProfile.'
    Write-Host 'Keep both command windows open. When finished, first close every dedicated Apexo browser window, then press Ctrl+C in the Apexo Server window.'
    Write-Host 'Wait for the post-session backup message before safely ejecting the USB drive.'
    Write-Host ''

    # A separate visible console is intentional: the user needs to send
    # Ctrl+C directly to PocketBase for its graceful SQLite shutdown. This
    # launcher remains alive, waits for that process, and then backs up.
    $serverProcess = Start-Process -FilePath $pocketBase `
        -ArgumentList $serverArguments `
        -WorkingDirectory $serverDirectory `
        -WindowStyle Normal `
        -PassThru

    Set-Content -LiteralPath $runningMarker -Encoding ascii -Value @(
        "Started UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
        "Computer: $env:COMPUTERNAME"
        "PocketBase PID: $($serverProcess.Id)"
        'Server: http://127.0.0.1:61110'
    )

    for ($attempt = 0; $attempt -lt 600; $attempt++) {
        if ($serverProcess.HasExited) {
            throw "PocketBase stopped during startup with exit code $($serverProcess.ExitCode)."
        }
        if (Test-LoopbackPort) {
            $sessionStarted = $true
            break
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not $sessionStarted) {
        Write-Warning 'PocketBase did not become ready within 60 seconds.'
        Write-Warning 'It will not be force-stopped while it may be migrating or writing SQLite. Inspect the Apexo Server window, press Ctrl+C there, and this launcher will wait before backing up.'
        $serverProcess.WaitForExit()
        throw 'PocketBase never became ready. Review the Apexo Server output before another attempt.'
    }

    New-Item -ItemType Directory -Path $browserProfile -Force | Out-Null
    $quotedBrowserProfile = '"' + $browserProfile + '"'
    $browserArguments = @(
        "--user-data-dir=$quotedBrowserProfile"
        '--no-first-run'
        '--no-default-browser-check'
        '--disable-background-mode'
        '--disable-sync'
        '--new-window'
        $url
    )
    $browserProcess = Start-Process -FilePath $browser.Path `
        -ArgumentList $browserArguments -PassThru
    Set-Content -LiteralPath $browserSessionMarker -Encoding utf8 -Value @(
        "BrowserPid=$($browserProcess.Id)"
        "BrowserPath=$($browser.Path)"
        "ProfilePath=$browserProfile"
        "StartedUtc=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    )
    $browserAcquiredProfile = $false
    for ($attempt = 0; $attempt -lt 150; $attempt++) {
        $browserScan = Get-ApexoPortableBrowserProcessScan `
            -ProfileDirectory $browserProfile
        if (-not [string]::IsNullOrWhiteSpace($browserScan.Warning)) {
            throw "Browser process inspection failed after launch: $($browserScan.Warning)"
        }
        if ($browserScan.Processes.Count -gt 0) {
            $browserAcquiredProfile = $true
            break
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not $browserAcquiredProfile) {
        throw "$($browser.Name) exited before it acquired the portable browser profile. Review browser policy/security software, then try again."
    }
    Write-Host 'Apexo is running. Close the dedicated browser window before stopping the Apexo Server.'
    Write-Host 'This launcher is waiting for the Apexo Server window to close.'
    $serverProcess.WaitForExit()
    if ($serverProcess.ExitCode -notin @(0, 1)) {
        Write-Warning "PocketBase stopped with exit code $($serverProcess.ExitCode)."
    }
} finally {
    try {
        if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
            Write-Warning 'PocketBase is still running after a launcher error.'
            Write-Warning 'It will not be force-stopped. Press Ctrl+C in the Apexo Server window; this launcher will wait before backing up.'
            $serverProcess.WaitForExit()
        }
        if (Test-Path -LiteralPath $runningMarker) {
            Remove-Item -LiteralPath $runningMarker -Force
        }
        if ((Test-Path -LiteralPath $browserSessionMarker) -or
            (Test-Path -LiteralPath $browserProfile -PathType Container)) {
            Wait-ApexoPortableBrowserProfile
        }
        if (Test-Path -LiteralPath $browserSessionMarker) {
            Remove-Item -LiteralPath $browserSessionMarker -Force
        }
        if ($null -ne $serverProcess) {
            try {
                $backupLabel = if ($sessionStarted) {
                    'post-session'
                } else {
                    'post-startup-failure'
                }
                & (Join-Path $bundleRoot 'Backup-Apexo.ps1') `
                    -Destination (Join-Path $bundleRoot 'Backups') `
                    -Label $backupLabel -LauncherOwnerPid $PID
            } catch {
                Write-Warning "Post-session backup failed: $_"
                Write-Warning 'Do not eject the USB until you have made and verified an offline backup.'
                throw
            }
        }
    } finally {
        if ($null -ne $guardStream) {
            $guardStream.Dispose()
        }
        if (Test-Path -LiteralPath $launcherGuard) {
            Remove-Item -LiteralPath $launcherGuard -Force
        }
    }
}
