[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $toolRoot 'DentalWinMigration.psm1'
$entryPath = Join-Path $toolRoot 'Invoke-DentalWinMigration.ps1'
$fixturePath = Join-Path $toolRoot 'fixtures/synthetic_source.json'
Import-Module $modulePath -Force

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

function Assert-Equal {
    param(
        $Expected,
        $Actual,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Expected -ne $Actual) {
        throw "ASSERTION FAILED: $Message. Expected '$Expected', received '$Actual'."
    }
    $script:Passed++
    Write-Host "[PASS] $Message"
}

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $thrown = $false
    try {
        & $Action
    }
    catch {
        $thrown = $true
    }
    Assert-True -Condition $thrown -Message $Message
}

function Invoke-SyntheticSql {
    param(
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection,
        [Parameter(Mandatory = $true)][string[]]$Statements
    )
    foreach ($statement in $Statements) {
        $command = $Connection.CreateCommand()
        try {
            $command.CommandText = $statement
            [void]$command.ExecuteNonQuery()
        }
        finally {
            $command.Dispose()
        }
    }
}

function New-SyntheticAccessDatabase {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet('clinical', 'calendar')][string]$Role
    )

    $catalog = New-Object -ComObject ADOX.Catalog
    $active = $null
    try {
        $null = $catalog.Create("Provider=Microsoft.ACE.OLEDB.16.0;Data Source=$Path;Jet OLEDB:Engine Type=5;")
        $active = $catalog.ActiveConnection
        if ($null -ne $active -and $active.State -ne 0) {
            $active.Close()
        }
    }
    finally {
        if ($null -ne $active) {
            [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($active)
        }
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($catalog)
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }

    $connection = [System.Data.OleDb.OleDbConnection]::new(
        "Provider=Microsoft.ACE.OLEDB.16.0;Data Source=$Path;Persist Security Info=False;"
    )
    try {
        $connection.Open()
        if ($Role -eq 'clinical') {
            Invoke-SyntheticSql -Connection $connection -Statements @(
                'CREATE TABLE Customers ([id] LONG, [EPON] VARCHAR(36), [NAME] VARCHAR(50), [LAST] VARCHAR(50))',
                'CREATE TABLE WorksPelati ([id] LONG, [kodikosPelati] LONG, [guidsspelati] VARCHAR(36), [ergasia] VARCHAR(255))',
                "INSERT INTO Customers ([id], [EPON], [NAME], [LAST]) VALUES (1, '00000000-0000-0000-0000-000000000001', 'SYNTHETIC', 'ONE')",
                "INSERT INTO Customers ([id], [EPON], [NAME], [LAST]) VALUES (2, '00000000-0000-0000-0000-000000000002', 'SYNTHETIC', 'TWO')",
                "INSERT INTO WorksPelati ([id], [kodikosPelati], [guidsspelati], [ergasia]) VALUES (10, 1, '00000000-0000-0000-0000-000000000001', 'SYNTHETIC WORK')"
            )
        }
        else {
            Invoke-SyntheticSql -Connection $connection -Statements @(
                'CREATE TABLE Appointments2 ([id] LONG, [guidsspelati] VARCHAR(36), [Subject] VARCHAR(255), [StartTime] DATETIME, [EndTime] DATETIME)',
                "INSERT INTO Appointments2 ([id], [guidsspelati], [Subject]) VALUES (20, '00000000-0000-0000-0000-000000000001', 'SYNTHETIC APPOINTMENT')"
            )
        }
    }
    finally {
        $connection.Close()
        $connection.Dispose()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

$tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $tempPrefix ("apexo-dentalwin-phase3-tests-" + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

try {
    Write-Host 'Running encrypted synthetic dry-run tests...'
    $fixtureHashBefore = Get-DwFileHashHex -Path $fixturePath
    $stageOne = Join-Path $testRoot 'stage-one'
    $stageTwo = Join-Path $testRoot 'stage-two'
    $passphrase = 'synthetic-fixture-only-passphrase-v1'
    $resultOne = Invoke-DwSyntheticDryRun -FixturePath $fixturePath -OutputDirectory $stageOne -Passphrase $passphrase
    $resultTwo = Invoke-DwSyntheticDryRun -FixturePath $fixturePath -OutputDirectory $stageTwo -Passphrase $passphrase

    Assert-True -Condition $resultOne.Complete -Message 'synthetic dry run completes'
    Assert-Equal -Expected 0 -Actual $resultOne.DuplicateExternalKeys -Message 'external source keys are unique'
    Assert-Equal -Expected $resultOne.BatchId -Actual $resultTwo.BatchId -Message 'repeat run has the same deterministic batch identity'
    Assert-Equal -Expected $fixtureHashBefore -Actual (Get-DwFileHashHex -Path $fixturePath) -Message 'synthetic source hash is unchanged'

    $reportOne = Get-Content -LiteralPath (Join-Path $stageOne 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $reportTwo = Get-Content -LiteralPath (Join-Path $stageTwo 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Expected 3 -Actual $reportOne.staged_counts.patients -Message 'all synthetic patients are staged'
    Assert-Equal -Expected 4 -Actual $reportOne.staged_counts.patient_contacts -Message 'all synthetic contacts are accounted for'
    Assert-Equal -Expected 4 -Actual $reportOne.staged_counts.clinical_events_and_plan_items -Message 'all synthetic work rows are preserved'
    Assert-Equal -Expected 3 -Actual $reportOne.staged_counts.appointments -Message 'all synthetic appointments are preserved'
    Assert-Equal -Expected ($reportOne.staged_counts | ConvertTo-Json -Compress) -Actual ($reportTwo.staged_counts | ConvertTo-Json -Compress) -Message 'repeat run produces the same staged counts'
    Assert-Equal -Expected 1 -Actual $reportOne.review_reason_counts.appointment_name_match_candidate -Message 'name-only appointment remains a review candidate'
    Assert-Equal -Expected 1 -Actual $reportOne.review_reason_counts.appointment_patient_missing -Message 'unmatched appointment is retained for review'
    Assert-Equal -Expected 2 -Actual $reportOne.review_reason_counts.unmatched_catalog_work -Message 'legacy custom works are retained and reported'
    Assert-Equal -Expected 1 -Actual $reportOne.review_reason_counts.ambiguous_or_invalid_tooth -Message 'ambiguous tooth value is retained for review'

    $patientsPath = Join-Path $stageOne 'protected/normalized/patients.jsonl.enc.json'
    $eventsPath = Join-Path $stageOne 'protected/normalized/clinical_events_and_plan_items.jsonl.enc.json'
    $reviewsPath = Join-Path $stageOne 'protected/normalized/review_items.jsonl.enc.json'
    $externalPath = Join-Path $stageOne 'protected/normalized/external_identifiers.jsonl.enc.json'
    $patients = @(Read-DwProtectedJsonLines -Path $patientsPath -Passphrase $passphrase)
    $events = @(Read-DwProtectedJsonLines -Path $eventsPath -Passphrase $passphrase)
    $reviews = @(Read-DwProtectedJsonLines -Path $reviewsPath -Passphrase $passphrase)
    $external = @(Read-DwProtectedJsonLines -Path $externalPath -Passphrase $passphrase)
    Assert-Equal -Expected 3 -Actual $patients.Count -Message 'protected patient staging decrypts with the correct passphrase'
    Assert-Equal -Expected 1 -Actual @($events | Where-Object event_kind -eq 'treatment_plan_item').Count -Message 'treatment-plan membership is preserved'
    Assert-Equal -Expected 16 -Actual $reviews.Count -Message 'protected review rows reconcile with aggregate report'
    Assert-Equal -Expected $external.Count -Actual @($external.external_key | Sort-Object -Unique).Count -Message 'decrypted external keys contain no duplicates'

    $protectedText = Get-Content -LiteralPath $patientsPath -Raw -Encoding UTF8
    Assert-True -Condition (-not $protectedText.Contains('ΔΟΚΙΜΗ')) -Message 'protected files do not expose synthetic patient names as plaintext'
    Assert-True -Condition (-not $protectedText.Contains('SYN-0001')) -Message 'protected files do not expose synthetic identifiers as plaintext'
    Assert-Throws -Action { Read-DwProtectedJsonLines -Path $patientsPath -Passphrase 'wrong-passphrase-value' | Out-Null } -Message 'wrong staging passphrase is rejected'

    $tamperedPath = Join-Path $testRoot 'tampered.enc.json'
    $envelope = Get-Content -LiteralPath $patientsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $cipherBytes = [Convert]::FromBase64String($envelope.ciphertext)
    $cipherBytes[0] = $cipherBytes[0] -bxor 1
    $envelope.ciphertext = [Convert]::ToBase64String($cipherBytes)
    [System.IO.File]::WriteAllText($tamperedPath, ($envelope | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
    Assert-Throws -Action { Read-DwProtectedJsonLines -Path $tamperedPath -Passphrase $passphrase | Out-Null } -Message 'tampered protected staging is rejected'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $stageOne 'checksums.sha256')) -Message 'staging checksum manifest is created'

    Write-Host 'Running synthetic Microsoft Access inventory tests...'
    $sourceDirectory = Join-Path $testRoot 'synthetic-access-source'
    [System.IO.Directory]::CreateDirectory($sourceDirectory) | Out-Null
    $clinicalPath = Join-Path $sourceDirectory 'synthetic-clinical.mdb'
    $calendarPath = Join-Path $sourceDirectory 'synthetic-calendar.mdb'
    New-SyntheticAccessDatabase -Path $clinicalPath -Role clinical
    New-SyntheticAccessDatabase -Path $calendarPath -Role calendar
    $clinicalHashBefore = Get-DwFileHashHex -Path $clinicalPath
    $calendarHashBefore = Get-DwFileHashHex -Path $calendarPath
    $inventoryOutput = Join-Path $testRoot 'inventory-output'
    $inventoryResult = Invoke-DwInventory -SourceDirectory $sourceDirectory -OutputDirectory $inventoryOutput
    $inventoryManifest = Get-Content -LiteralPath (Join-Path $inventoryOutput 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True -Condition $inventoryResult.Complete -Message 'synthetic Access inventory completes'
    Assert-Equal -Expected 2 -Actual $inventoryResult.DatabaseCount -Message 'both synthetic Access databases are inventoried'
    Assert-True -Condition (@($inventoryManifest.databases.role) -contains 'clinical') -Message 'clinical Access database role is identified'
    Assert-True -Condition (@($inventoryManifest.databases.role) -contains 'calendar') -Message 'calendar Access database role is identified'
    Assert-Equal -Expected $clinicalHashBefore -Actual (Get-DwFileHashHex -Path $clinicalPath) -Message 'clinical Access database hash is unchanged after inventory'
    Assert-Equal -Expected $calendarHashBefore -Actual (Get-DwFileHashHex -Path $calendarPath) -Message 'calendar Access database hash is unchanged after inventory'
    Assert-Throws -Action { Invoke-DwInventory -SourceDirectory $sourceDirectory -OutputDirectory (Join-Path $sourceDirectory 'forbidden-output') | Out-Null } -Message 'inventory refuses to write inside the source folder'
    Write-Host 'Running private read-only Access dry-run tests...'
    $keyPath = Join-Path $testRoot 'keys/private-test.key'
    $keyResult = New-DwPrivateKeyFile -Path $keyPath
    Assert-True -Condition $keyResult.Created -Message 'a separate private key file is created'
    Assert-True -Condition $keyResult.PermissionsRestricted -Message 'private key permissions are restricted'
    $privateOutput = Join-Path $testRoot 'private-stage'
    $privateResult = Invoke-DwPrivateDryRun -SourceDirectory $sourceDirectory -OutputDirectory $privateOutput -KeyFile $keyPath
    Assert-True -Condition $privateResult.Complete -Message 'private Access dry run completes'
    Assert-Equal -Expected 2 -Actual $privateResult.DatabaseCount -Message 'private dry run accounts for both databases'
    Assert-Equal -Expected 3 -Actual $privateResult.ExtractedTableCount -Message 'private dry run extracts approved tables that exist'
    Assert-True -Condition $privateResult.SourceHashesUnchanged -Message 'all Access source hashes remain unchanged after extraction'
    Assert-True -Condition (-not $privateResult.WritesToApexo) -Message 'private dry run performs no Apexo writes'
    $privateReport = Get-Content -LiteralPath (Join-Path $privateOutput 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Expected 'private_dry_run' -Actual $privateReport.mode -Message 'private report records the correct mode'
    Assert-True -Condition $privateReport.contains_real_patient_data -Message 'private staging is marked as containing real patient data'
    Assert-Equal -Expected 2 -Actual $privateReport.staged_counts.patients -Message 'private Access patient rows are staged'
    Assert-Equal -Expected 1 -Actual $privateReport.staged_counts.clinical_events_and_plan_items -Message 'private Access clinical rows are staged'
    Assert-Equal -Expected 1 -Actual $privateReport.staged_counts.appointments -Message 'private Access appointment rows are staged'
    $privatePassphrase = [System.IO.File]::ReadAllText($keyPath).Trim()
    $privatePatients = @(Read-DwProtectedJsonLines -Path (Join-Path $privateOutput 'protected/normalized/patients.jsonl.enc.json') -Passphrase $privatePassphrase)
    Assert-Equal -Expected 2 -Actual $privatePatients.Count -Message 'private protected staging decrypts with its separate key'
    $privateEnvelopeText = Get-Content -LiteralPath (Join-Path $privateOutput 'protected/normalized/patients.jsonl.enc.json') -Raw -Encoding UTF8
    Assert-True -Condition (-not $privateEnvelopeText.Contains('SYNTHETIC')) -Message 'private protected staging does not expose patient names in plaintext'
    Assert-Equal -Expected $clinicalHashBefore -Actual (Get-DwFileHashHex -Path $clinicalPath) -Message 'clinical Access database hash is unchanged after private dry run'
    Assert-Equal -Expected $calendarHashBefore -Actual (Get-DwFileHashHex -Path $calendarPath) -Message 'calendar Access database hash is unchanged after private dry run'
    Assert-Throws -Action { Invoke-DwPrivateDryRun -SourceDirectory $sourceDirectory -OutputDirectory (Join-Path $sourceDirectory 'forbidden-private-output') -KeyFile $keyPath | Out-Null } -Message 'private dry run refuses to write inside the source folder'

    Write-Host "Phase 3 tests passed: $script:Passed assertions."
}
finally {
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    $resolvedRoot = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolvedRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedRoot).StartsWith('apexo-dentalwin-phase3-tests-')) {
        try {
            Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Temporary synthetic test directory could not be removed: $resolvedRoot"
        }
    }
}
