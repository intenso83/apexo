[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$migratorRoot = Split-Path -Parent $PSScriptRoot
$runnerPath = Join-Path $migratorRoot 'MigrationRunner.ps1'
$tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $tempPrefix ("apexo-dentalwin-migrator-tests-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

$script:Passed = 0

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
    $script:Passed++
    Write-Host "[PASS] $Message"
}

function Invoke-RunnerFixture {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Inventory', 'SyntheticDryRun')][string]$Mode,
        [Parameter(Mandatory = $true)][string]$ResultPath,
        [Parameter(Mandatory = $true)][string]$ModulePath
    )

    $arguments = @(
        '-NoProfile',
        '-File', $runnerPath,
        '-Mode', $Mode,
        '-ModulePath', $ModulePath,
        '-ResultPath', $ResultPath,
        '-SourceDirectory', $testRoot,
        '-OutputDirectory', (Join-Path $testRoot "$Mode-output"),
        '-FixturePath', (Join-Path $testRoot 'fixture.json')
    )
    & pwsh @arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Migration runner fixture '$Mode' failed with exit code $LASTEXITCODE."
    }
    return Get-Content -LiteralPath $ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

try {
    $fixtureModule = Join-Path $testRoot 'FixtureMigration.psm1'
    $fixtureModuleText = @'
function Invoke-DwInventory {
    param([string]$SourceDirectory, [string]$OutputDirectory)
    [pscustomobject]@{
        Complete = $true
        Mode = 'Inventory'
        OutputDirectory = $OutputDirectory
        SourceHashesUnchanged = $true
        DatabaseCount = 2
    }
}

function Invoke-DwSyntheticDryRun {
    param([string]$FixturePath, [string]$OutputDirectory, [string]$Passphrase)
    [pscustomobject]@{
        Complete = $true
        Mode = 'SyntheticDryRun'
        OutputDirectory = $OutputDirectory
        SourceHashUnchanged = $true
    }
}

Export-ModuleMember -Function Invoke-DwInventory, Invoke-DwSyntheticDryRun
'@
    [System.IO.File]::WriteAllText(
        $fixtureModule,
        $fixtureModuleText,
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $testRoot 'fixture.json'),
        '{}',
        [System.Text.UTF8Encoding]::new($false)
    )

    $inventoryResult = Invoke-RunnerFixture `
        -Mode Inventory `
        -ResultPath (Join-Path $testRoot 'inventory-result.json') `
        -ModulePath $fixtureModule
    Assert-True -Condition $inventoryResult.success -Message 'inventory runner succeeds'
    Assert-True -Condition $inventoryResult.source_hashes_unchanged -Message 'plural inventory hash result is preserved'

    $syntheticResult = Invoke-RunnerFixture `
        -Mode SyntheticDryRun `
        -ResultPath (Join-Path $testRoot 'synthetic-result.json') `
        -ModulePath $fixtureModule
    Assert-True -Condition $syntheticResult.success -Message 'synthetic runner succeeds'
    Assert-True -Condition $syntheticResult.source_hashes_unchanged -Message 'singular synthetic hash result remains supported'

    Write-Host "DentalWin migrator runner tests passed: $script:Passed assertions."
}
finally {
    $resolvedRoot = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolvedRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedRoot).StartsWith('apexo-dentalwin-migrator-tests-')) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
