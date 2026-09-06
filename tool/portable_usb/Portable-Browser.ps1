$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-ApexoPortableBrowser {
    [CmdletBinding()]
    param()

    $programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $localAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA')

    # Keep every Edge location ahead of every Chrome location. The portable
    # bundle deliberately uses an installed browser so it does not have to
    # distribute or silently update a second browser binary.
    $candidates = @()
    foreach ($root in @($programFilesX86, $programFiles, $localAppData)) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            $candidates += [PSCustomObject]@{
                Name = 'Microsoft Edge'
                ProcessName = 'msedge'
                Path = Join-Path $root 'Microsoft\Edge\Application\msedge.exe'
            }
        }
    }
    foreach ($root in @($programFiles, $programFilesX86, $localAppData)) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            $candidates += [PSCustomObject]@{
                Name = 'Google Chrome'
                ProcessName = 'chrome'
                Path = Join-Path $root 'Google\Chrome\Application\chrome.exe'
            }
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate.Path -PathType Leaf) {
            $candidate.Path = [IO.Path]::GetFullPath($candidate.Path)
            return $candidate
        }
    }

    throw 'Microsoft Edge or Google Chrome was not found in a standard per-machine or per-user installation. Install Edge (preferred) or Chrome before starting this Web beta.'
}

function ConvertTo-ApexoComparablePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [IO.Path]::GetFullPath($Path).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
}

function Get-ApexoPortableBrowserProcessScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileDirectory
    )

    $targetProfile = ConvertTo-ApexoComparablePath $ProfileDirectory
    $matches = @()
    $warning = ''
    try {
        $processes = @(Get-CimInstance -ClassName Win32_Process `
                -Filter "Name = 'msedge.exe' OR Name = 'chrome.exe'" `
                -ErrorAction Stop)
        $profilePattern = '(?i)(?:^|\s)--user-data-dir(?:=|\s+)(?:"([^"]+)"|([^\s"]+))'
        foreach ($process in $processes) {
            $commandLine = [string]$process.CommandLine
            if ([string]::IsNullOrWhiteSpace($commandLine)) {
                $warning = "Windows returned no command line for Chromium PID $($process.ProcessId); portable-profile ownership cannot be ruled out."
                continue
            }
            foreach ($argumentMatch in [regex]::Matches($commandLine, $profilePattern)) {
                $argumentPath = if ($argumentMatch.Groups[1].Success) {
                    $argumentMatch.Groups[1].Value
                } else {
                    $argumentMatch.Groups[2].Value
                }
                try {
                    $candidateProfile = ConvertTo-ApexoComparablePath $argumentPath
                    if ($candidateProfile.Equals(
                            $targetProfile, [StringComparison]::OrdinalIgnoreCase)) {
                        $matches += [PSCustomObject]@{
                            Id = [int]$process.ProcessId
                            Name = [string]$process.Name
                        }
                        break
                    }
                } catch {
                    # An unrelated malformed browser argument is ignored.
                }
            }
        }
    } catch {
        $warning = "Windows browser process inspection was unavailable: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Processes = @($matches)
        Warning = $warning
    }
}

function Get-ApexoPortableBrowserLockedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileDirectory
    )

    if (-not (Test-Path -LiteralPath $ProfileDirectory -PathType Container)) {
        return $null
    }

    $lockCandidates = @()
    foreach ($name in @('SingletonLock', 'SingletonCookie', 'SingletonSocket')) {
        $candidate = Join-Path $ProfileDirectory $name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $lockCandidates += Get-Item -LiteralPath $candidate -Force
        }
    }
    $lockCandidates += @(Get-ChildItem -LiteralPath $ProfileDirectory -Filter 'LOCK' `
            -File -Recurse -Force -ErrorAction SilentlyContinue)

    foreach ($candidate in @($lockCandidates | Sort-Object FullName -Unique)) {
        $stream = $null
        try {
            $stream = [IO.File]::Open(
                $candidate.FullName,
                [IO.FileMode]::Open,
                [IO.FileAccess]::Read,
                [IO.FileShare]::None
            )
        } catch {
            return $candidate.FullName
        } finally {
            if ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }
    return $null
}

function Get-ApexoPortableBrowserProfileUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileDirectory,

        [Parameter(Mandatory = $true)]
        [string]$SessionMarker
    )

    $scan = Get-ApexoPortableBrowserProcessScan -ProfileDirectory $ProfileDirectory
    if ($scan.Processes.Count -gt 0) {
        $processIds = ($scan.Processes | ForEach-Object { $_.Id }) -join ', '
        return [PSCustomObject]@{
            InUse = $true
            Detail = "Edge/Chrome is using the portable profile (PID: $processIds)"
            InspectionWarning = $scan.Warning
        }
    }

    $lockedFile = Get-ApexoPortableBrowserLockedFile -ProfileDirectory $ProfileDirectory
    if ($null -ne $lockedFile) {
        return [PSCustomObject]@{
            InUse = $true
            Detail = "a portable browser profile lock is held: $lockedFile"
            InspectionWarning = $scan.Warning
        }
    }

    # A marker can become stale, so it is never proof by itself that the
    # profile is live. Conversely, once a profile/session exists, inability to
    # inspect Chromium command lines must fail closed: an unlocked-looking
    # LevelDB file alone is not enough to prove that every browser process quit.
    if (-not [string]::IsNullOrWhiteSpace($scan.Warning) -and
        ((Test-Path -LiteralPath $ProfileDirectory -PathType Container) -or
         (Test-Path -LiteralPath $SessionMarker -PathType Leaf))) {
        return [PSCustomObject]@{
            InUse = $true
            Detail = 'Windows could not verify whether Edge/Chrome still owns the portable profile'
            InspectionWarning = $scan.Warning
        }
    }

    return [PSCustomObject]@{
        InUse = $false
        Detail = ''
        InspectionWarning = $scan.Warning
    }
}
