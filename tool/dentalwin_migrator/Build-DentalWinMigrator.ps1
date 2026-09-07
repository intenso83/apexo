[CmdletBinding()]
param(
    [string]$OutputDirectory = 'output/dentalwin-migrator'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$output = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
[System.IO.Directory]::CreateDirectory($output) | Out-Null

$cscCandidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe')
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($csc)) {
    throw 'The Windows .NET Framework C# compiler was not found.'
}

$source = Join-Path $PSScriptRoot 'DentalWinMigrator.cs'
$runner = Join-Path $PSScriptRoot 'MigrationRunner.ps1'
$module = Join-Path $repositoryRoot 'tool/dentalwin_migration/DentalWinMigration.psm1'
$fixture = Join-Path $repositoryRoot 'tool/dentalwin_migration/fixtures/synthetic_source.json'
$icon = Join-Path $repositoryRoot 'windows/runner/resources/app_icon.ico'
$executable = Join-Path $output 'ApexoDentalWinMigrator.exe'

$arguments = @(
    '/nologo',
    '/optimize+',
    '/target:winexe',
    '/platform:anycpu',
    '/codepage:65001',
    "/out:$executable",
    "/win32icon:$icon",
    '/reference:System.dll',
    '/reference:System.Core.dll',
    '/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll',
    '/reference:System.Web.Extensions.dll',
    "/resource:$module,Apexo.DentalWin.Engine",
    "/resource:$runner,Apexo.DentalWin.Runner",
    "/resource:$fixture,Apexo.DentalWin.Fixture",
    $source
)

& $csc @arguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executable)) {
    throw "DentalWin migrator compilation failed with exit code $LASTEXITCODE."
}

$tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$selfTestOutput = Join-Path $tempPrefix ("apexo-dentalwin-migrator-selftest-" + [guid]::NewGuid().ToString('N'))
$selfTestResult = $selfTestOutput + '.self-test.txt'
try {
    $selfTestProcess = Start-Process `
        -FilePath $executable `
        -ArgumentList @('--engine-self-test', ('"' + $selfTestOutput + '"')) `
        -Wait `
        -PassThru `
        -WindowStyle Hidden
    if ($selfTestProcess.ExitCode -ne 0) {
        $details = if (Test-Path -LiteralPath $selfTestResult) {
            Get-Content -LiteralPath $selfTestResult -Raw -Encoding UTF8
        }
        else {
            'The executable did not create a self-test result.'
        }
        throw "DentalWin migrator embedded-engine self-test failed: $details"
    }
}
finally {
    $resolvedSelfTestOutput = [System.IO.Path]::GetFullPath($selfTestOutput)
    if ($resolvedSelfTestOutput.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedSelfTestOutput).StartsWith('apexo-dentalwin-migrator-selftest-')) {
        if (Test-Path -LiteralPath $resolvedSelfTestOutput) {
            Remove-Item -LiteralPath $resolvedSelfTestOutput -Recurse -Force
        }
        if (Test-Path -LiteralPath $selfTestResult) {
            Remove-Item -LiteralPath $selfTestResult -Force
        }
    }
}

$hash = Get-FileHash -LiteralPath $executable -Algorithm SHA256
$manifest = [ordered]@{
    product = 'Apexo DentalWin Migrator'
    version = '0.1.1'
    built_utc = [DateTime]::UtcNow.ToString('o')
    executable = [System.IO.Path]::GetFileName($executable)
    size_bytes = (Get-Item -LiteralPath $executable).Length
    sha256 = $hash.Hash.ToLowerInvariant()
    embedded_engine = 'DentalWinMigration.psm1'
    source_policy = 'read-only; source hashes checked before and after operations'
    target_policy = 'no Apexo writes in v0.1'
}
$manifestPath = Join-Path $output 'build-manifest.json'
[System.IO.File]::WriteAllText(
    $manifestPath,
    (ConvertTo-Json -InputObject $manifest -Depth 10),
    [System.Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    Executable = $executable
    SizeBytes = $manifest.size_bytes
    Sha256 = $manifest.sha256
    Manifest = $manifestPath
}
