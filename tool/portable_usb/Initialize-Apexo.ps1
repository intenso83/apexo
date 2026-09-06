[CmdletBinding()]
param(
    [string]$AdminEmail = '',
    [Security.SecureString]$AdminPassword
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bundleRoot = $PSScriptRoot
$serverDirectory = Join-Path $bundleRoot 'Server'
$pocketBase = Join-Path $serverDirectory 'pocketbase.exe'
$dataDirectory = Join-Path $bundleRoot 'Data\pb_data'
$browserProfile = Join-Path $bundleRoot 'Data\BrowserProfile'
$runningMarker = Join-Path $bundleRoot 'Data\RUNNING.lock'

if (-not (Test-Path -LiteralPath $pocketBase -PathType Leaf)) {
    throw "PocketBase is missing: $pocketBase"
}
if (Test-Path -LiteralPath $runningMarker) {
    throw 'Apexo may still be running. Stop it and run Verify-Apexo before initializing.'
}
if (Test-Path -LiteralPath $browserProfile) {
    throw 'Refusing to initialize beside an existing portable browser profile. Start from a verified empty template, or restore BrowserProfile together with its matching pb_data instead.'
}
if (Test-Path -LiteralPath $dataDirectory) {
    $existing = Get-ChildItem -LiteralPath $dataDirectory -Force
    if ($existing) {
        throw 'Refusing to initialize over an existing database. No files were changed.'
    }
} else {
    New-Item -ItemType Directory -Path $dataDirectory | Out-Null
}

if ([string]::IsNullOrWhiteSpace($AdminEmail)) {
    $AdminEmail = (Read-Host 'New Apexo administrator email').Trim()
}
try {
    $null = [Net.Mail.MailAddress]::new($AdminEmail)
} catch {
    throw 'Enter a valid administrator email address.'
}

if ($null -eq $AdminPassword) {
    $AdminPassword = Read-Host 'New administrator password (minimum 10 characters)' -AsSecureString
    $confirmation = Read-Host 'Repeat the new administrator password' -AsSecureString
    $first = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
    $second = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmation)
    try {
        $firstText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($first)
        $secondText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($second)
        if ($firstText -cne $secondText) {
            throw 'The passwords did not match.'
        }
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($first)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($second)
        $firstText = $null
        $secondText = $null
    }
}

$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
try {
    $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if ($passwordText.Length -lt 10) {
        throw 'The administrator password must contain at least 10 characters.'
    }
    Push-Location -LiteralPath $serverDirectory
    try {
        & $pocketBase superuser create $AdminEmail $passwordText `
            '--dir=..\Data\pb_data' `
            '--migrationsDir=pb_migrations' `
            '--hooksDir=pb_hooks'
        if ($LASTEXITCODE -ne 0) {
            throw "PocketBase initialization failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
} finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    $passwordText = $null
}

Write-Host ''
Write-Host 'The empty local server is initialized. No password was saved by this script.'
Write-Host 'Next: run Start-Apexo.cmd and use the bootstrap superuser once to initialize Apexo.'
Write-Host 'Then create a normal Apexo user with only the permissions needed for daily work, sign out, and use that account instead of the superuser.'
