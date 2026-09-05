[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Preflight', 'Inventory', 'PrivateDryRun', 'SyntheticDryRun')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$ModulePath,

    [Parameter(Mandatory = $true)]
    [string]$ResultPath,

    [string]$SourceDirectory,
    [string]$OutputDirectory,
    [string]$KeyFile,
    [string]$FixturePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Write-RunnerResult {
    param([Parameter(Mandatory = $true)]$Value)

    $parent = Split-Path -Parent $ResultPath
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $json = ConvertTo-Json -InputObject $Value -Depth 20
    [System.IO.File]::WriteAllText(
        $ResultPath,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-RunnerProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

try {
    if ($Mode -eq 'Preflight') {
        $providers = [System.Collections.ArrayList]::new()
        $reader = [System.Data.OleDb.OleDbEnumerator]::GetRootEnumerator()
        try {
            while ($reader.Read()) {
                $name = [string]$reader.GetValue(0)
                if ($name -like 'Microsoft.ACE.OLEDB.*') {
                    [void]$providers.Add($name)
                }
            }
        }
        finally {
            $reader.Close()
        }

        $mdbCount = 0
        if (-not [string]::IsNullOrWhiteSpace($SourceDirectory) -and
            (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
            $mdbCount = @(Get-ChildItem -LiteralPath $SourceDirectory -Recurse -File -Filter '*.mdb').Count
        }

        $result = [ordered]@{
            success = $true
            mode = 'Preflight'
            powershell_bits = [IntPtr]::Size * 8
            powershell_version = $PSVersionTable.PSVersion.ToString()
            access_providers = @($providers | Sort-Object -Unique)
            has_access_provider = $providers.Count -gt 0
            source_directory_exists = -not [string]::IsNullOrWhiteSpace($SourceDirectory) -and (Test-Path -LiteralPath $SourceDirectory -PathType Container)
            mdb_count = $mdbCount
            writes_to_dentalwin = $false
            writes_to_apexo = $false
        }
        Write-RunnerResult -Value $result
        $result | ConvertTo-Json -Depth 10
        exit 0
    }

    Import-Module $ModulePath -Force

    switch ($Mode) {
        'Inventory' {
            $operation = Invoke-DwInventory `
                -SourceDirectory $SourceDirectory `
                -OutputDirectory $OutputDirectory
        }
        'PrivateDryRun' {
            if (-not (Test-Path -LiteralPath $KeyFile)) {
                New-DwPrivateKeyFile -Path $KeyFile | Out-Null
            }
            $operation = Invoke-DwPrivateDryRun `
                -SourceDirectory $SourceDirectory `
                -OutputDirectory $OutputDirectory `
                -KeyFile $KeyFile
        }
        'SyntheticDryRun' {
            $operation = Invoke-DwSyntheticDryRun `
                -FixturePath $FixturePath `
                -OutputDirectory $OutputDirectory `
                -Passphrase 'synthetic-fixture-only-passphrase-v1'
        }
    }

    $result = [ordered]@{
        success = [bool](Get-RunnerProperty -InputObject $operation -Name 'Complete' -Default $false)
        mode = [string](Get-RunnerProperty -InputObject $operation -Name 'Mode' -Default $Mode)
        output_directory = [string](Get-RunnerProperty -InputObject $operation -Name 'OutputDirectory' -Default $OutputDirectory)
        batch_id = [string](Get-RunnerProperty -InputObject $operation -Name 'BatchId' -Default '')
        source_hashes_unchanged = [bool](Get-RunnerProperty -InputObject $operation -Name 'SourceHashUnchanged' -Default $false)
        review_item_count = [int](Get-RunnerProperty -InputObject $operation -Name 'ReviewItemCount' -Default 0)
        database_count = [int](Get-RunnerProperty -InputObject $operation -Name 'DatabaseCount' -Default 0)
        extracted_table_count = [int](Get-RunnerProperty -InputObject $operation -Name 'ExtractedTableCount' -Default 0)
        writes_to_dentalwin = $false
        writes_to_apexo = $false
    }
    Write-RunnerResult -Value $result
    $result | ConvertTo-Json -Depth 10
    if (-not $result.success) { exit 2 }
    exit 0
}
catch {
    $failure = [ordered]@{
        success = $false
        mode = $Mode
        error = $_.Exception.Message
        error_type = $_.Exception.GetType().FullName
        writes_to_dentalwin = $false
        writes_to_apexo = $false
    }
    try {
        Write-RunnerResult -Value $failure
    }
    catch {
        # Preserve the original operation error if even the result file fails.
    }
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
