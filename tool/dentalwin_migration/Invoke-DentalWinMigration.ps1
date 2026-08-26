[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Inventory', 'SyntheticDryRun', 'PrivateDryRun')]
    [string]$Mode,

    [string]$SourceDirectory,

    [string]$FixturePath,

    [string]$KeyFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'DentalWinMigration.psm1'
Import-Module $modulePath -Force

switch ($Mode) {
    'Inventory' {
        if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
            throw 'Inventory mode requires -SourceDirectory.'
        }
        $result = Invoke-DwInventory -SourceDirectory $SourceDirectory -OutputDirectory $OutputDirectory
        $result | Format-List
        if (-not $result.Complete) {
            exit 2
        }
    }
    'SyntheticDryRun' {
        if ([string]::IsNullOrWhiteSpace($FixturePath)) {
            $FixturePath = Join-Path $PSScriptRoot 'fixtures/synthetic_source.json'
        }

        # This fixed passphrase is acceptable only because the committed fixture
        # is explicitly synthetic. Real staging must use the environment variable.
        $passphrase = 'synthetic-fixture-only-passphrase-v1'
        $result = Invoke-DwSyntheticDryRun -FixturePath $FixturePath -OutputDirectory $OutputDirectory -Passphrase $passphrase
        $result | Format-List
        if (-not $result.Complete) {
            exit 2
        }
    }
    'PrivateDryRun' {
        if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
            throw 'PrivateDryRun mode requires -SourceDirectory.'
        }
        if ([string]::IsNullOrWhiteSpace($KeyFile)) {
            $outputParent = Split-Path -Parent ([System.IO.Path]::GetFullPath($OutputDirectory))
            $KeyFile = Join-Path $outputParent 'keys/dentalwin-phase3.key'
        }
        if (-not (Test-Path -LiteralPath $KeyFile)) {
            $keyResult = New-DwPrivateKeyFile -Path $KeyFile
            Write-Host "Created a restricted private staging key outside the run directory: $($keyResult.Path)"
        }
        $result = Invoke-DwPrivateDryRun `
            -SourceDirectory $SourceDirectory `
            -OutputDirectory $OutputDirectory `
            -KeyFile $KeyFile
        $result | Format-List
        if (-not $result.Complete) {
            exit 2
        }
    }
}
