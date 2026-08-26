Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$migrationModule = Join-Path $PSScriptRoot 'DentalWinMigration.psm1'
Import-Module $migrationModule -Force

function Get-DwImportProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $Default
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Write-DwImportJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $text = ConvertTo-Json -InputObject $Value -Depth 50
    [System.IO.File]::WriteAllText(
        $Path,
        $text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-DwImportRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    return [System.IO.Path]::GetRelativePath(
        [System.IO.Path]::GetFullPath($BasePath),
        [System.IO.Path]::GetFullPath($Path)
    )
}

function Assert-DwLoopbackTestServerUrl {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ServerUrl)

    $uri = [Uri]$ServerUrl
    if ($uri.Scheme -ne 'http' -or
        $uri.Host -ne '127.0.0.1' -or
        $uri.IsDefaultPort -or
        ($uri.AbsolutePath -ne '/')) {
        throw 'Safety lock: Phase 4 accepts only an explicit http://127.0.0.1:<port>/ server root.'
    }
    return $uri.AbsoluteUri.TrimEnd('/')
}

function Get-DwDeterministicPocketBaseId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$BatchId,
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$StageKey
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$BatchId|$Store|$StageKey")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hex = ([Convert]::ToHexString($sha.ComputeHash($bytes))).ToLowerInvariant()
        return 'd' + $hex.Substring(0, 14)
    }
    finally {
        $sha.Dispose()
    }
}

function Get-DwTestServerAuth {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $storedSecret = [System.IO.File]::ReadAllText(
        (Resolve-Path -LiteralPath $PasswordFile).Path,
        [System.Text.Encoding]::UTF8
    ).Trim()
    if ($storedSecret.Length -lt 16) {
        throw 'The separate test-server password file is invalid.'
    }
    $password = $storedSecret.Substring(0, [Math]::Min(64, $storedSecret.Length))
    try {
        $body = ConvertTo-Json -InputObject ([ordered]@{
                identity = $Email
                password = $password
            })
        $auth = Invoke-RestMethod `
            -Method Post `
            -Uri "$ServerUrl/api/collections/_superusers/auth-with-password" `
            -ContentType 'application/json' `
            -Body $body `
            -TimeoutSec 15
        if ([string]::IsNullOrWhiteSpace([string]$auth.token)) {
            throw 'The isolated test server did not return an authentication token.'
        }
        return @{ Authorization = [string]$auth.token }
    }
    finally {
        $password = $null
        $storedSecret = $null
    }
}

function New-DwEmptyTestServerBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$DataDirectory,
        [Parameter(Mandatory = $true)][string]$BackupDirectory
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    try {
        Invoke-RestMethod -Uri "$server/api/health" -TimeoutSec 2 | Out-Null
        throw 'Safety lock: stop the isolated test server before taking its pre-import backup.'
    }
    catch {
        if ($_.Exception.Message -like 'Safety lock:*') { throw }
    }

    $source = (Resolve-Path -LiteralPath $DataDirectory).Path
    if (-not (Test-Path -LiteralPath (Join-Path $source 'data.db'))) {
        throw 'The PocketBase data directory does not contain data.db.'
    }
    $backup = [System.IO.Path]::GetFullPath($BackupDirectory)
    if (Test-Path -LiteralPath $backup) {
        if (@(Get-ChildItem -LiteralPath $backup -Force).Count -gt 0) {
            throw 'The pre-import backup directory already exists and is not empty.'
        }
    }
    else {
        [System.IO.Directory]::CreateDirectory($backup) | Out-Null
    }

    foreach ($entry in @(Get-ChildItem -LiteralPath $source -Force)) {
        Copy-Item -LiteralPath $entry.FullName -Destination $backup -Recurse -Force
    }
    $files = [System.Collections.ArrayList]::new()
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File | Sort-Object FullName) {
        $relative = Get-DwImportRelativePath -BasePath $source -Path $file.FullName
        $copy = Join-Path $backup $relative
        if (-not (Test-Path -LiteralPath $copy)) {
            throw 'The pre-import backup is missing a source file.'
        }
        $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $backupHash = (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceHash -ne $backupHash) {
            throw 'The pre-import backup failed checksum verification.'
        }
        [void]$files.Add([ordered]@{
                relative_path = $relative
                size_bytes = $file.Length
                sha256 = $sourceHash
            })
    }
    $manifest = [ordered]@{
        format = 'apexo-dentalwin-test-backup-v1'
        created_utc = [DateTime]::UtcNow.ToString('o')
        source_server = $server
        state = 'empty-schema-only'
        file_count = $files.Count
        files = @($files)
        verified = $true
    }
    Write-DwImportJson -Path (Join-Path $backup 'backup-manifest.json') -Value $manifest
    return [pscustomobject]@{
        BackupDirectory = $backup
        FileCount = $files.Count
        Verified = $true
    }
}

function Test-DwEmptyBackupManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [Parameter(Mandatory = $true)][string]$ExpectedServerUrl
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ExpectedServerUrl
    $backup = (Resolve-Path -LiteralPath $BackupDirectory).Path
    $manifestPath = Join-Path $backup 'backup-manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.format -ne 'apexo-dentalwin-test-backup-v1' -or
        $manifest.verified -ne $true -or
        $manifest.state -ne 'empty-schema-only' -or
        $manifest.source_server -ne $server -or
        [int]$manifest.file_count -ne @($manifest.files).Count) {
        throw 'Safety lock: the empty-server backup manifest is invalid.'
    }

    $backupPrefix = $backup.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    foreach ($item in @($manifest.files)) {
        $relative = [string]$item.relative_path
        if ([string]::IsNullOrWhiteSpace($relative) -or [System.IO.Path]::IsPathRooted($relative)) {
            throw 'Safety lock: the backup manifest contains an unsafe path.'
        }
        $path = [System.IO.Path]::GetFullPath((Join-Path $backup $relative))
        if (-not $path.StartsWith($backupPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw 'Safety lock: a backup file is missing or outside the backup directory.'
        }
        $file = Get-Item -LiteralPath $path
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($file.Length -ne [long]$item.size_bytes -or $actualHash -ne [string]$item.sha256) {
            throw 'Safety lock: the empty-server backup failed integrity verification.'
        }
    }

    return [pscustomobject]@{
        ManifestPath = $manifestPath
        FileCount = @($manifest.files).Count
        Verified = $true
    }
}

function New-DwTestServerGuard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$TestServerDirectory,
        [Parameter(Mandatory = $true)][string]$DataDirectory,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    $root = (Resolve-Path -LiteralPath $TestServerDirectory).Path
    $data = (Resolve-Path -LiteralPath $DataDirectory).Path
    $rootPrefix = $root.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $data.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Safety lock: the PocketBase data directory must be inside the isolated test-server directory.'
    }
    $backupRoot = (Resolve-Path -LiteralPath $BackupDirectory).Path
    if (-not $backupRoot.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Safety lock: the pre-import backup must be inside the isolated test-server directory.'
    }
    $backupVerification = Test-DwEmptyBackupManifest -BackupDirectory $backupRoot -ExpectedServerUrl $server
    $backupManifestPath = $backupVerification.ManifestPath
    $backupManifest = Get-Content -LiteralPath $backupManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $staging = (Resolve-Path -LiteralPath $StagingDirectory).Path
    $summary = Get-Content -LiteralPath (Join-Path $staging 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($summary.mode -ne 'private_dry_run' -or
        $summary.contains_real_patient_data -ne $true -or
        $summary.writes_to_apexo -ne $false -or
        -not $summary.source_hash_unchanged) {
        throw 'Safety lock: the selected staging batch is not a verified private dry run.'
    }
    $health = Invoke-RestMethod -Uri "$server/api/health" -TimeoutSec 5
    if ($health.code -ne 200) { throw 'The isolated test server is not healthy.' }
    $headers = Get-DwTestServerAuth -ServerUrl $server -Email $Email -PasswordFile $PasswordFile
    $dataRows = Invoke-RestMethod -Uri "$server/api/collections/data/records?perPage=1" -Headers $headers -TimeoutSec 10
    if ($dataRows.totalItems -ne 0) {
        throw 'Safety lock: the server is not empty before the pilot import.'
    }

    $markerPath = Join-Path $root '.dentalwin-phase4-test-guard.json'
    if (Test-Path -LiteralPath $markerPath) {
        throw 'A Phase 4 guard already exists for this test-server directory.'
    }
    $marker = [ordered]@{
        format = 'apexo-dentalwin-phase4-test-guard-v1'
        marker_id = [Guid]::NewGuid().ToString('N')
        created_utc = [DateTime]::UtcNow.ToString('o')
        server_url = $server
        data_directory = $data
        staging_directory = $staging
        staging_batch_id = $summary.batch_id
        source_fingerprint = $summary.source_fingerprint
        backup_manifest = $backupManifestPath
        allowed_stores = @(
            'patients',
            'appointments',
            'migration_batches',
            'migration_external_identifiers'
        )
        pilot_patient_limit = 5
        pilot_appointment_limit_per_patient = 2
        production_import_authorized = $false
    }
    Write-DwImportJson -Path $markerPath -Value $marker
    return [pscustomobject]@{
        MarkerPath = $markerPath
        MarkerId = $marker.marker_id
        ServerUrl = $server
        Empty = $true
        ProductionImportAuthorized = $false
    }
}

function ConvertTo-DwDateOnly {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $parsed = [DateTime]::MinValue
    if (-not [DateTime]::TryParse([string]$Value, [ref]$parsed)) { return $null }
    return $parsed.ToString('yyyy-MM-dd')
}

function ConvertTo-DwMinuteEpoch {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $parsed = [DateTime]::MinValue
    if (-not [DateTime]::TryParse([string]$Value, [ref]$parsed)) { return $null }
    return [int64][Math]::Round(
        ([DateTimeOffset]$parsed).ToUnixTimeMilliseconds() / 60000.0
    )
}

function ConvertTo-DwNullableBoolean {
    param($Value)
    if ($null -eq $Value) { return $null }
    $text = ([string]$Value).Trim().ToLowerInvariant()
    if ($text -in @('1', 'true', 'yes')) { return $true }
    if ($text -in @('0', 'false', 'no')) { return $false }
    return $null
}

function Get-DwAllRemoteRows {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)]$Headers
    )

    $rows = [System.Collections.ArrayList]::new()
    $pageNumber = 1
    do {
        $page = Invoke-RestMethod -Uri "$ServerUrl/api/collections/data/records?perPage=200&page=$pageNumber" -Headers $Headers -TimeoutSec 15
        foreach ($item in @($page.items)) { [void]$rows.Add($item) }
        $pageNumber++
    } while ($pageNumber -le [int]$page.totalPages)
    return @($rows)
}

function Add-DwPilotRecord {
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)]$Headers,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)]$Data,
        [Parameter(Mandatory = $true)][string]$BatchId,
        [Parameter(Mandatory = $true)][string]$StageKey
    )

    $existing = $null
    try {
        $existing = Invoke-RestMethod -Uri "$ServerUrl/api/collections/data/records/$Id" -Headers $Headers -TimeoutSec 10
    }
    catch {
        $response = $_.Exception.Response
        if ($null -eq $response -or [int]$response.StatusCode -ne 404) { throw }
    }
    if ($null -ne $existing) {
        $migration = Get-DwImportProperty -InputObject $existing.data -Name 'migration'
        if ($existing.store -ne $Store -or
            $null -eq $migration -or
            (Get-DwImportProperty -InputObject $migration -Name 'batch_id') -ne $BatchId -or
            (Get-DwImportProperty -InputObject $migration -Name 'source_stage_key') -ne $StageKey) {
            throw 'Safety lock: a deterministic pilot record ID already belongs to different data.'
        }
        return 'already_imported'
    }

    $body = ConvertTo-Json -InputObject ([ordered]@{
            id = $Id
            store = $Store
            data = $Data
        }) -Depth 50
    Invoke-RestMethod `
        -Method Post `
        -Uri "$ServerUrl/api/collections/data/records" `
        -Headers $Headers `
        -ContentType 'application/json' `
        -Body $body `
        -TimeoutSec 15 | Out-Null
    return 'created'
}

function Invoke-DwPilotImport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$TestServerDirectory,
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$StagingKeyFile,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    $root = (Resolve-Path -LiteralPath $TestServerDirectory).Path
    $markerPath = Join-Path $root '.dentalwin-phase4-test-guard.json'
    $marker = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $staging = (Resolve-Path -LiteralPath $StagingDirectory).Path
    $summary = Get-Content -LiteralPath (Join-Path $staging 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($marker.format -ne 'apexo-dentalwin-phase4-test-guard-v1' -or
        $marker.server_url -ne $server -or
        $marker.staging_directory -ne $staging -or
        $marker.staging_batch_id -ne $summary.batch_id -or
        $marker.source_fingerprint -ne $summary.source_fingerprint -or
        $marker.production_import_authorized -ne $false) {
        throw 'Safety lock: the Phase 4 guard does not match this server and staging batch.'
    }
    $headers = Get-DwTestServerAuth -ServerUrl $server -Email $Email -PasswordFile $PasswordFile
    $existingRows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    foreach ($row in $existingRows) {
        $migration = Get-DwImportProperty -InputObject $row.data -Name 'migration'
        if ($null -eq $migration -or
            (Get-DwImportProperty -InputObject $migration -Name 'batch_id') -ne $summary.batch_id -or
            (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id) {
            throw 'Safety lock: the test server contains a record outside this pilot batch.'
        }
        if (@($marker.allowed_stores) -notcontains [string]$row.store) {
            throw 'Safety lock: the test server contains a store outside the pilot allow-list.'
        }
    }

    $stagingKey = [System.IO.File]::ReadAllText(
        (Resolve-Path -LiteralPath $StagingKeyFile).Path,
        [System.Text.Encoding]::UTF8
    ).Trim()
    try {
        $patients = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/patients.jsonl.enc.json') -Passphrase $stagingKey)
        $contacts = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/patient_contacts.jsonl.enc.json') -Passphrase $stagingKey)
        $appointments = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/appointments.jsonl.enc.json') -Passphrase $stagingKey)
    }
    finally {
        $stagingKey = $null
    }

    $contactsByPatient = @{}
    foreach ($contact in $contacts) {
        $patientKey = [string]$contact.patient_stage_key
        if ([string]::IsNullOrWhiteSpace($patientKey)) { continue }
        if (-not $contactsByPatient.ContainsKey($patientKey)) {
            $contactsByPatient[$patientKey] = [System.Collections.ArrayList]::new()
        }
        [void]$contactsByPatient[$patientKey].Add($contact)
    }
    $appointmentsByPatient = @{}
    foreach ($appointment in $appointments) {
        if ($appointment.patient_link_method -ne 'patient_guid') { continue }
        $patientKey = [string]$appointment.patient_stage_key
        if ([string]::IsNullOrWhiteSpace($patientKey)) { continue }
        if (-not $appointmentsByPatient.ContainsKey($patientKey)) {
            $appointmentsByPatient[$patientKey] = [System.Collections.ArrayList]::new()
        }
        [void]$appointmentsByPatient[$patientKey].Add($appointment)
    }

    $eligible = @($patients | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.surname) -and
            -not [string]::IsNullOrWhiteSpace([string]$_.first_name) -and
            $contactsByPatient.ContainsKey([string]$_.stage_key) -and
            $appointmentsByPatient.ContainsKey([string]$_.stage_key)
        } | Sort-Object {
            Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'pilot-selection' -StageKey ([string]$_.stage_key)
        } | Select-Object -First ([int]$marker.pilot_patient_limit))
    if ($eligible.Count -ne [int]$marker.pilot_patient_limit) {
        throw 'The staging batch does not contain enough fully linked patients for the pilot.'
    }

    $created = [ordered]@{ patients = 0; appointments = 0; provenance = 0; batches = 0 }
    $already = [ordered]@{ patients = 0; appointments = 0; provenance = 0; batches = 0 }
    $selectedPatientIds = @{}
    foreach ($patient in $eligible) {
        $stageKey = [string]$patient.stage_key
        $targetId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'patients' -StageKey $stageKey
        $selectedPatientIds[$stageKey] = $targetId
        $birthDate = ConvertTo-DwDateOnly $patient.birth_date_raw
        $registrationDate = ConvertTo-DwDateOnly $patient.registration_date_raw
        $patientContacts = @($contactsByPatient[$stageKey] | Sort-Object stage_key)
        $contactJson = [System.Collections.ArrayList]::new()
        $primarySet = $false
        foreach ($contact in $patientContacts) {
            $sms = ConvertTo-DwNullableBoolean $contact.sms_allowed_raw
            $contactItem = [ordered]@{
                id = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'patient_contacts' -StageKey ([string]$contact.stage_key)
                type = [string]$contact.type
                raw_value = [string]$contact.raw_value
                normalized_value = [string]$contact.normalized_value
                is_primary = -not $primarySet
            }
            if ($null -ne $sms) { $contactItem.sms_allowed = $sms }
            if (-not [string]::IsNullOrWhiteSpace([string]$contact.notes)) { $contactItem.notes = [string]$contact.notes }
            [void]$contactJson.Add($contactItem)
            $primarySet = $true
        }
        $telephoneValues = @($patientContacts | Where-Object { $_.type -in @('home_phone', 'work_phone', 'mobile') } | ForEach-Object { [string]$_.raw_value })
        $emailValue = @($patientContacts | Where-Object type -eq 'email' | ForEach-Object { [string]$_.raw_value } | Select-Object -First 1)
        $displayName = (@([string]$patient.surname, [string]$patient.first_name) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' '
        $patientData = [ordered]@{
            id = $targetId
            title = $displayName
            archived = $false
            registration_number = "TEST-DW-$($patient.source_numeric_id)"
            surname = [string]$patient.surname
            first_name = [string]$patient.first_name
            patronymic = [string]$patient.patronymic
            birth_date_precision = if ($null -ne $birthDate) { 'exact' } else { 'unknown' }
            sex_or_gender = 'unknown'
            occupation = [string]$patient.occupation
            active_status = 'active'
            address = [string]$patient.address_line
            address_line = [string]$patient.address_line
            area = [string]$patient.area
            city = [string]$patient.city
            postal_code = [string]$patient.postal_code
            amka = [string]$patient.amka
            afm = [string]$patient.afm
            doy = [string]$patient.doy
            insurance = [string]$patient.insurance
            referral_source = [string]$patient.referral_source
            legacy_folder_number = [string]$patient.legacy_folder_number
            contacts = @($contactJson)
            phone = ($telephoneValues -join ' ')
            email = if ($emailValue.Count -gt 0) { $emailValue[0] } else { '' }
            legacy_custom_fields = [ordered]@{
                dentalwin_registration_number = [string]$patient.legacy_registration_number
                dentalwin_sequence_number = [string]$patient.legacy_sequence_number
                dentalwin_active_status_raw = [string]$patient.active_status_raw
            }
            migration = [ordered]@{
                batch_id = $summary.batch_id
                guard_id = $marker.marker_id
                source_stage_key = $stageKey
                source_system = 'DentalWin'
                pilot = $true
            }
        }
        if ($null -ne $birthDate) {
            $patientData.birth_date = $birthDate
            $patientData.birth = [int]$birthDate.Substring(0, 4)
        }
        if ($null -ne $registrationDate) { $patientData.registration_date = $registrationDate }
        $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $targetId -Store 'patients' -Data $patientData -BatchId $summary.batch_id -StageKey $stageKey
        if ($result -eq 'created') { $created.patients++ } else { $already.patients++ }

        $provenanceStageKey = "external:patient:$stageKey"
        $provenanceId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'migration_external_identifiers' -StageKey $provenanceStageKey
        $provenanceData = [ordered]@{
            title = 'DentalWin patient provenance'
            source_system = 'DentalWin'
            source_database_fingerprint = $summary.source_fingerprint
            source_table = 'Customers'
            source_record_key = [string]$patient.source_numeric_id
            source_patient_guid = [string]$patient.source_patient_guid
            target_store = 'patients'
            target_record_id = $targetId
            migration = [ordered]@{
                batch_id = $summary.batch_id
                guard_id = $marker.marker_id
                source_stage_key = $provenanceStageKey
                pilot = $true
            }
        }
        $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $provenanceId -Store 'migration_external_identifiers' -Data $provenanceData -BatchId $summary.batch_id -StageKey $provenanceStageKey
        if ($result -eq 'created') { $created.provenance++ } else { $already.provenance++ }
    }

    foreach ($patient in $eligible) {
        $patientStageKey = [string]$patient.stage_key
        $targetPatientId = $selectedPatientIds[$patientStageKey]
        $patientAppointments = @($appointmentsByPatient[$patientStageKey] | Sort-Object stage_key | Select-Object -First ([int]$marker.pilot_appointment_limit_per_patient))
        foreach ($appointment in $patientAppointments) {
            $stageKey = [string]$appointment.stage_key
            $startMinutes = ConvertTo-DwMinuteEpoch $appointment.start_raw
            if ($null -eq $startMinutes) { continue }
            $startDate = [DateTime]::Parse([string]$appointment.start_raw)
            $endDate = $startDate.AddMinutes(15)
            if (-not [string]::IsNullOrWhiteSpace([string]$appointment.end_raw)) {
                $parsedEnd = [DateTime]::MinValue
                if ([DateTime]::TryParse([string]$appointment.end_raw, [ref]$parsedEnd)) { $endDate = $parsedEnd }
            }
            $duration = [Math]::Max(1, [int][Math]::Round(($endDate - $startDate).TotalMinutes))
            $targetId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'appointments' -StageKey $stageKey
            $appointmentData = [ordered]@{
                id = $targetId
                patientID = $targetPatientId
                date = $startMinutes
                duration = $duration
                isDone = ($endDate -lt [DateTime]::Now)
                preOpNotes = [string]$appointment.description
                price = 0
                paid = 0
                migration = [ordered]@{
                    batch_id = $summary.batch_id
                    guard_id = $marker.marker_id
                    source_stage_key = $stageKey
                    source_link_method = 'patient_guid'
                    pilot = $true
                }
            }
            $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $targetId -Store 'appointments' -Data $appointmentData -BatchId $summary.batch_id -StageKey $stageKey
            if ($result -eq 'created') { $created.appointments++ } else { $already.appointments++ }

            $provenanceStageKey = "external:appointment:$stageKey"
            $provenanceId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'migration_external_identifiers' -StageKey $provenanceStageKey
            $provenanceData = [ordered]@{
                title = 'DentalWin appointment provenance'
                source_system = 'DentalWin'
                source_database_fingerprint = $summary.source_fingerprint
                source_table = 'Appointments2'
                source_record_key = $stageKey.Substring('appointment:'.Length)
                target_store = 'appointments'
                target_record_id = $targetId
                migration = [ordered]@{
                    batch_id = $summary.batch_id
                    guard_id = $marker.marker_id
                    source_stage_key = $provenanceStageKey
                    pilot = $true
                }
            }
            $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $provenanceId -Store 'migration_external_identifiers' -Data $provenanceData -BatchId $summary.batch_id -StageKey $provenanceStageKey
            if ($result -eq 'created') { $created.provenance++ } else { $already.provenance++ }
        }
    }

    $batchStageKey = "migration-batch:$($summary.batch_id)"
    $batchId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'migration_batches' -StageKey $batchStageKey
    $batchData = [ordered]@{
        title = 'DentalWin Phase 4 pilot'
        mode = 'isolated_empty_test_server_pilot'
        source_fingerprint = $summary.source_fingerprint
        source_batch_id = $summary.batch_id
        patient_limit = [int]$marker.pilot_patient_limit
        appointment_limit_per_patient = [int]$marker.pilot_appointment_limit_per_patient
        production_import_authorized = $false
        migration = [ordered]@{
            batch_id = $summary.batch_id
            guard_id = $marker.marker_id
            source_stage_key = $batchStageKey
            pilot = $true
        }
    }
    $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $batchId -Store 'migration_batches' -Data $batchData -BatchId $summary.batch_id -StageKey $batchStageKey
    if ($result -eq 'created') { $created.batches++ } else { $already.batches++ }

    $finalRows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    $storeCounts = [ordered]@{}
    foreach ($group in @($finalRows | Group-Object store | Sort-Object Name)) {
        $storeCounts[$group.Name] = $group.Count
    }
    $report = [ordered]@{
        mode = 'isolated_empty_test_server_pilot'
        created_utc = [DateTime]::UtcNow.ToString('o')
        server_host = '127.0.0.1'
        source_batch_id = $summary.batch_id
        guard_id = $marker.marker_id
        created_counts = $created
        already_imported_counts = $already
        final_store_counts = $storeCounts
        total_records = $finalRows.Count
        contains_real_patient_data = $true
        production_import_authorized = $false
        writes_to_dentalwin = $false
    }
    $reportDirectory = Join-Path $root 'reports'
    Write-DwImportJson -Path (Join-Path $reportDirectory 'pilot-import-summary.json') -Value $report
    return [pscustomobject]@{
        Mode = 'IsolatedPilotImport'
        CreatedPatients = $created.patients
        CreatedAppointments = $created.appointments
        CreatedProvenance = $created.provenance
        CreatedBatchRecords = $created.batches
        AlreadyImported = ($already.patients + $already.appointments + $already.provenance + $already.batches)
        TotalRecords = $finalRows.Count
        ProductionImportAuthorized = $false
        Complete = $true
    }
}

function Test-DwPilotImport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$TestServerDirectory,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    $root = (Resolve-Path -LiteralPath $TestServerDirectory).Path
    $markerPath = Join-Path $root '.dentalwin-phase4-test-guard.json'
    $marker = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($marker.server_url -ne $server -or $marker.production_import_authorized -ne $false) {
        throw 'Safety lock: the Phase 4 guard does not match this isolated server.'
    }

    $headers = Get-DwTestServerAuth -ServerUrl $server -Email $Email -PasswordFile $PasswordFile
    $allRows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    $provenanceRows = @($allRows | Where-Object store -eq 'migration_external_identifiers')
    $baseProvenance = @($provenanceRows | Where-Object {
            [string](Get-DwImportProperty -InputObject $_.data -Name 'target_store') -in @('patients', 'appointments')
        })
    $phase5Provenance = @($provenanceRows | Where-Object {
            [string](Get-DwImportProperty -InputObject $_.data -Name 'target_store') -eq 'treatment_history'
        })
    $rows = @(
        @($allRows | Where-Object { [string]$_.store -in @('patients', 'appointments', 'migration_batches') }) +
        $baseProvenance
    )
    $phase5Rows = @(
        @($allRows | Where-Object store -eq 'treatment_history') +
        $phase5Provenance
    )
    $knownIds = @{}
    foreach ($row in @($rows + $phase5Rows)) { $knownIds[[string]$row.id] = $true }
    $housekeepingRows = @($allRows | Where-Object { -not $knownIds.ContainsKey([string]$_.id) })
    $unexpectedHousekeeping = @($housekeepingRows | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.store) -and
            [string]$_.store -ne 'settings_global'
        })
    if ($unexpectedHousekeeping.Count -gt 0) {
        throw 'Pilot verification found an unexpected non-migration store.'
    }
    if ($rows.Count -ne 31) { throw 'Pilot verification expected exactly 31 migration records.' }
    if (@($allRows.id | Sort-Object -Unique).Count -ne $allRows.Count) {
        throw 'Pilot verification found duplicate PocketBase record IDs.'
    }
    foreach ($record in @($rows + $phase5Rows)) {
        $migration = Get-DwImportProperty -InputObject $record.data -Name 'migration'
        if ($null -eq $migration -or
            (Get-DwImportProperty -InputObject $migration -Name 'batch_id') -ne $marker.staging_batch_id -or
            (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id) {
            throw 'Pilot verification found a migration-store record outside the guarded batch.'
        }
    }

    $patients = @($rows | Where-Object store -eq 'patients')
    $appointments = @($rows | Where-Object store -eq 'appointments')
    $provenance = @($baseProvenance)
    $batches = @($rows | Where-Object store -eq 'migration_batches')
    if ($patients.Count -ne 5 -or $appointments.Count -ne 10 -or
        $provenance.Count -ne 15 -or $batches.Count -ne 1) {
        throw 'Pilot verification found unexpected store counts.'
    }

    $patientIds = @{}
    $greekNameCount = 0
    $patientBirthDateCount = 0
    foreach ($record in $patients) {
        $data = $record.data
        $surname = [string](Get-DwImportProperty -InputObject $data -Name 'surname')
        $firstName = [string](Get-DwImportProperty -InputObject $data -Name 'first_name')
        if ([string]::IsNullOrWhiteSpace($surname) -or [string]::IsNullOrWhiteSpace($firstName)) {
            throw 'Pilot verification found a patient without the two required name fields.'
        }
        $contacts = @(Get-DwImportProperty -InputObject $data -Name 'contacts' -Default @())
        if ($contacts.Count -lt 1) {
            throw 'Pilot verification found a patient without a contact method.'
        }
        if (-not ([string](Get-DwImportProperty -InputObject $data -Name 'registration_number')).StartsWith('TEST-DW-')) {
            throw 'Pilot verification found a patient without a pilot-only registration number.'
        }
        $migration = Get-DwImportProperty -InputObject $data -Name 'migration'
        if ($null -eq $migration -or
            (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id -or
            (Get-DwImportProperty -InputObject $migration -Name 'pilot') -ne $true) {
            throw 'Pilot verification found a patient without matching provenance metadata.'
        }
        $patientIds[[string]$record.id] = $true
        if ("$surname$firstName" -match '[\u0370-\u03FF\u1F00-\u1FFF]') { $greekNameCount++ }
        if (-not [string]::IsNullOrWhiteSpace([string](Get-DwImportProperty -InputObject $data -Name 'birth_date'))) {
            $patientBirthDateCount++
        }
    }

    $appointmentDatesValid = 0
    foreach ($record in $appointments) {
        $data = $record.data
        $patientId = [string](Get-DwImportProperty -InputObject $data -Name 'patientID')
        if (-not $patientIds.ContainsKey($patientId)) {
            throw 'Pilot verification found an appointment with a broken patient link.'
        }
        if ([int](Get-DwImportProperty -InputObject $data -Name 'duration' -Default 0) -le 0) {
            throw 'Pilot verification found an appointment with a non-positive duration.'
        }
        $dateMinutes = [long](Get-DwImportProperty -InputObject $data -Name 'date' -Default 0)
        if ($dateMinutes -gt 0) {
            $parsed = [DateTimeOffset]::FromUnixTimeMilliseconds($dateMinutes * 60000).UtcDateTime
        }
        if ($dateMinutes -gt 0 -and $parsed.Year -ge 2000 -and $parsed.Year -le 2100) {
            $appointmentDatesValid++
        }
    }
    if ($appointmentDatesValid -ne $appointments.Count) {
        throw 'Pilot verification found an invalid appointment date.'
    }

    $batchData = $batches[0].data
    if ((Get-DwImportProperty -InputObject $batchData -Name 'production_import_authorized') -ne $false) {
        throw 'Pilot verification found a batch with production authorization.'
    }

    $report = [ordered]@{
        mode = 'isolated_empty_test_server_pilot_verification'
        verified_utc = [DateTime]::UtcNow.ToString('o')
        server_host = '127.0.0.1'
        total_records = $allRows.Count
        migration_records = $rows.Count
        application_housekeeping_records = $housekeepingRows.Count
        patients = $patients.Count
        appointments = $appointments.Count
        provenance_records = $provenance.Count
        migration_batches = $batches.Count
        patients_with_required_names_and_contact = $patients.Count
        patients_with_parseable_birth_date = $patientBirthDateCount
        patients_with_greek_name_characters = $greekNameCount
        appointments_with_valid_patient_link_and_date = $appointmentDatesValid
        duplicate_record_ids = 0
        production_import_authorized = $false
        contains_patient_values = $false
        verified = $true
    }
    Write-DwImportJson -Path (Join-Path $root 'reports/pilot-verification-summary.json') -Value $report
    return [pscustomobject]$report
}

function ConvertTo-DwTreatmentHistoryData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Event,
        [Parameter(Mandatory = $true)][string]$TargetPatientId,
        [Parameter(Mandatory = $true)][string]$BatchId,
        [Parameter(Mandatory = $true)][string]$GuardId,
        [string]$TherapyGroup = ''
    )

    $stageKey = [string](Get-DwImportProperty -InputObject $Event -Name 'stage_key')
    if ([string]::IsNullOrWhiteSpace($stageKey) -or
        [string]::IsNullOrWhiteSpace($TargetPatientId)) {
        throw 'Treatment-history conversion requires a source stage key and target patient.'
    }
    $name = [string](Get-DwImportProperty -InputObject $Event -Name 'original_work_name')
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Unlabelled DentalWin treatment' }
    $kind = [string](Get-DwImportProperty -InputObject $Event -Name 'event_kind' -Default 'clinical_event')
    if ($kind -notin @('clinical_event', 'treatment_plan_item')) {
        throw 'Treatment-history conversion found an unsupported event kind.'
    }
    $data = [ordered]@{
        patientID = $TargetPatientId
        title = $name
        treatmentName = $name
        eventKind = $kind
        dateRaw = [string](Get-DwImportProperty -InputObject $Event -Name 'date_raw')
        toothRaw = [string](Get-DwImportProperty -InputObject $Event -Name 'tooth_raw')
        toothFdi = [string](Get-DwImportProperty -InputObject $Event -Name 'tooth_fdi')
        notes = [string](Get-DwImportProperty -InputObject $Event -Name 'notes')
        statusRaw = [string](Get-DwImportProperty -InputObject $Event -Name 'status_raw')
        chargeRaw = [string](Get-DwImportProperty -InputObject $Event -Name 'charge_raw')
        creditRaw = [string](Get-DwImportProperty -InputObject $Event -Name 'credit_raw')
        totalRaw = [string](Get-DwImportProperty -InputObject $Event -Name 'total_raw')
        sourceCatalogCode = [string](Get-DwImportProperty -InputObject $Event -Name 'source_catalog_code')
        catalogLinkMethod = [string](Get-DwImportProperty -InputObject $Event -Name 'catalog_link_method' -Default 'legacy_custom')
        therapyGroup = $TherapyGroup
        migration = [ordered]@{
            batch_id = $BatchId
            guard_id = $GuardId
            source_stage_key = $stageKey
            source_system = 'DentalWin'
            source_link_method = 'patient_stage_key'
            pilot = $true
            treatment_history_pilot = $true
        }
    }
    $dateMinutes = ConvertTo-DwMinuteEpoch (Get-DwImportProperty -InputObject $Event -Name 'date_raw')
    if ($null -ne $dateMinutes) { $data.date = $dateMinutes }
    return $data
}

function Get-DwTreatmentPilotCatalogContext {
    param(
        [Parameter(Mandatory = $true)]$Groups,
        [Parameter(Mandatory = $true)]$Catalog
    )
    $groupsById = @{}
    foreach ($group in @($Groups)) {
        $groupsById[[string]$group.source_id] = [string]$group.name
    }
    $catalogByCode = @{}
    foreach ($item in @($Catalog)) {
        $code = [string]$item.source_code
        if (-not [string]::IsNullOrWhiteSpace($code)) { $catalogByCode[$code] = $item }
    }
    return [pscustomobject]@{ GroupsById = $groupsById; CatalogByCode = $catalogByCode }
}

function Get-DwTreatmentPilotGroupName {
    param(
        [Parameter(Mandatory = $true)]$Event,
        [Parameter(Mandatory = $true)]$Context
    )
    $code = [string](Get-DwImportProperty -InputObject $Event -Name 'source_catalog_code')
    if ([string]::IsNullOrWhiteSpace($code) -or -not $Context.CatalogByCode.ContainsKey($code)) { return '' }
    $item = $Context.CatalogByCode[$code]
    $groupId = [string]$item.therapy_group_source_id
    if (-not $Context.GroupsById.ContainsKey($groupId)) { return '' }
    return [string]$Context.GroupsById[$groupId]
}

function Invoke-DwTreatmentHistoryPilot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$TestServerDirectory,
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$StagingKeyFile,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    $root = (Resolve-Path -LiteralPath $TestServerDirectory).Path
    $marker = Get-Content -LiteralPath (Join-Path $root '.dentalwin-phase4-test-guard.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $staging = (Resolve-Path -LiteralPath $StagingDirectory).Path
    $summary = Get-Content -LiteralPath (Join-Path $staging 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($marker.server_url -ne $server -or
        $marker.staging_directory -ne $staging -or
        $marker.staging_batch_id -ne $summary.batch_id -or
        $marker.production_import_authorized -ne $false -or
        $summary.writes_to_apexo -ne $false) {
        throw 'Safety lock: the treatment-history pilot does not match the isolated Phase 4 server and staging batch.'
    }

    $headers = Get-DwTestServerAuth -ServerUrl $server -Email $Email -PasswordFile $PasswordFile
    $existingRows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    $allowedStores = @(
        '', 'settings_global', 'patients', 'appointments', 'treatment_history',
        'therapy_groups', 'procedure_catalog',
        'migration_batches', 'migration_external_identifiers'
    )
    foreach ($row in $existingRows) {
        if ([string]$row.store -notin $allowedStores) {
            throw 'Safety lock: the test server contains a store outside the treatment-pilot allow-list.'
        }
        if ([string]$row.store -notin @('', 'settings_global')) {
            $migration = Get-DwImportProperty -InputObject $row.data -Name 'migration'
            if ($null -eq $migration -or
                (Get-DwImportProperty -InputObject $migration -Name 'batch_id') -ne $summary.batch_id -or
                (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id) {
                throw 'Safety lock: the test server contains migration data outside the guarded pilot batch.'
            }
        }
    }

    $patientRows = @($existingRows | Where-Object store -eq 'patients')
    if ($patientRows.Count -ne [int]$marker.pilot_patient_limit) {
        throw 'Treatment-history pilot requires the verified five-patient pilot.'
    }
    $patientTargets = @{}
    foreach ($row in $patientRows) {
        $migration = Get-DwImportProperty -InputObject $row.data -Name 'migration'
        $sourceStageKey = [string](Get-DwImportProperty -InputObject $migration -Name 'source_stage_key')
        if (-not $sourceStageKey.StartsWith('patient:')) {
            throw 'A pilot patient is missing its DentalWin stage identity.'
        }
        $patientTargets[$sourceStageKey] = [string]$row.id
    }

    $stagingKey = [System.IO.File]::ReadAllText(
        (Resolve-Path -LiteralPath $StagingKeyFile).Path,
        [System.Text.Encoding]::UTF8
    ).Trim()
    try {
        $events = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/clinical_events_and_plan_items.jsonl.enc.json') -Passphrase $stagingKey)
        $groups = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/therapy_groups.jsonl.enc.json') -Passphrase $stagingKey)
        $catalog = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/procedure_catalog.jsonl.enc.json') -Passphrase $stagingKey)
    }
    finally {
        $stagingKey = $null
    }

    $selected = @($events | Where-Object { $patientTargets.ContainsKey([string]$_.patient_stage_key) })
    if ($selected.Count -eq 0) { throw 'The selected pilot patients have no staged treatment history.' }
    if ($selected.Count -gt 2500) { throw 'Safety lock: treatment-history pilot exceeds the 2500-record total limit.' }
    foreach ($group in @($selected | Group-Object patient_stage_key)) {
        if ($group.Count -gt 500) { throw 'Safety lock: a pilot patient exceeds the 500-treatment limit.' }
    }

    $catalogContext = Get-DwTreatmentPilotCatalogContext -Groups $groups -Catalog $catalog
    $created = 0
    $already = 0
    $createdProvenance = 0
    $alreadyProvenance = 0
    foreach ($event in $selected) {
        $stageKey = [string]$event.stage_key
        $targetPatientId = [string]$patientTargets[[string]$event.patient_stage_key]
        $therapyGroup = Get-DwTreatmentPilotGroupName -Event $event -Context $catalogContext
        $data = ConvertTo-DwTreatmentHistoryData -Event $event -TargetPatientId $targetPatientId -BatchId $summary.batch_id -GuardId $marker.marker_id -TherapyGroup $therapyGroup
        $targetId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'treatment_history' -StageKey $stageKey
        $data.id = $targetId
        $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $targetId -Store 'treatment_history' -Data $data -BatchId $summary.batch_id -StageKey $stageKey
        if ($result -eq 'created') { $created++ } else { $already++ }

        $provenanceStageKey = "external:treatment-history:$stageKey"
        $provenanceId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'migration_external_identifiers' -StageKey $provenanceStageKey
        $provenanceData = [ordered]@{
            title = 'DentalWin treatment-history provenance'
            source_system = 'DentalWin'
            source_database_fingerprint = $summary.source_fingerprint
            source_table = 'WorksPelati'
            source_record_key = $stageKey.Substring('clinical-work:'.Length)
            target_store = 'treatment_history'
            target_record_id = $targetId
            migration = [ordered]@{
                batch_id = $summary.batch_id
                guard_id = $marker.marker_id
                source_stage_key = $provenanceStageKey
                pilot = $true
                treatment_history_pilot = $true
            }
        }
        $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $provenanceId -Store 'migration_external_identifiers' -Data $provenanceData -BatchId $summary.batch_id -StageKey $provenanceStageKey
        if ($result -eq 'created') { $createdProvenance++ } else { $alreadyProvenance++ }
    }

    $report = [ordered]@{
        mode = 'isolated_treatment_history_pilot'
        created_utc = [DateTime]::UtcNow.ToString('o')
        server_host = '127.0.0.1'
        pilot_patients = $patientRows.Count
        expected_treatment_records = $selected.Count
        created_treatment_records = $created
        already_imported_treatment_records = $already
        created_provenance_records = $createdProvenance
        already_imported_provenance_records = $alreadyProvenance
        production_import_authorized = $false
        writes_to_dentalwin = $false
        contains_patient_values = $false
    }
    Write-DwImportJson -Path (Join-Path $root 'reports/treatment-history-pilot-import-summary.json') -Value $report
    return [pscustomobject]$report
}

function Test-DwTreatmentHistoryPilot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$TestServerDirectory,
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$StagingKeyFile,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    $root = (Resolve-Path -LiteralPath $TestServerDirectory).Path
    $marker = Get-Content -LiteralPath (Join-Path $root '.dentalwin-phase4-test-guard.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($marker.server_url -ne $server -or $marker.production_import_authorized -ne $false) {
        throw 'Safety lock: treatment-history verification is not pointed at the isolated pilot server.'
    }
    $headers = Get-DwTestServerAuth -ServerUrl $server -Email $Email -PasswordFile $PasswordFile
    $rows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    if (@($rows.id | Sort-Object -Unique).Count -ne $rows.Count) {
        throw 'Treatment-history verification found duplicate PocketBase record IDs.'
    }
    $patients = @($rows | Where-Object store -eq 'patients')
    $treatments = @($rows | Where-Object store -eq 'treatment_history')
    $patientIds = @{}
    $patientStageKeys = @{}
    foreach ($patient in $patients) {
        $patientIds[[string]$patient.id] = $true
        $migration = Get-DwImportProperty -InputObject $patient.data -Name 'migration'
        $patientStageKeys[[string](Get-DwImportProperty -InputObject $migration -Name 'source_stage_key')] = $true
    }

    $staging = (Resolve-Path -LiteralPath $StagingDirectory).Path
    $stagingKey = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $StagingKeyFile).Path, [System.Text.Encoding]::UTF8).Trim()
    try {
        $events = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/clinical_events_and_plan_items.jsonl.enc.json') -Passphrase $stagingKey)
    }
    finally { $stagingKey = $null }
    $expected = @($events | Where-Object { $patientStageKeys.ContainsKey([string]$_.patient_stage_key) })
    if ($expected.Count -eq 0 -or $treatments.Count -ne $expected.Count) {
        throw 'Treatment-history verification found a staged/imported count mismatch.'
    }

    $completed = 0
    $planned = 0
    $withDate = 0
    $withTooth = 0
    $legacyCustom = 0
    foreach ($record in $treatments) {
        $data = $record.data
        if (-not $patientIds.ContainsKey([string](Get-DwImportProperty -InputObject $data -Name 'patientID'))) {
            throw 'Treatment-history verification found a broken patient link.'
        }
        if ([string]::IsNullOrWhiteSpace([string](Get-DwImportProperty -InputObject $data -Name 'treatmentName'))) {
            throw 'Treatment-history verification found an empty treatment name.'
        }
        $kind = [string](Get-DwImportProperty -InputObject $data -Name 'eventKind')
        if ($kind -eq 'clinical_event') { $completed++ }
        elseif ($kind -eq 'treatment_plan_item') { $planned++ }
        else { throw 'Treatment-history verification found an invalid event kind.' }
        $dateMinutes = [long](Get-DwImportProperty -InputObject $data -Name 'date' -Default 0)
        if ($dateMinutes -gt 0) { $withDate++ }
        $tooth = [string](Get-DwImportProperty -InputObject $data -Name 'toothFdi')
        if (-not [string]::IsNullOrWhiteSpace($tooth)) {
            if ($tooth -notmatch '^(1[1-8]|2[1-8]|3[1-8]|4[1-8]|5[1-5]|6[1-5]|7[1-5]|8[1-5])$') {
                throw 'Treatment-history verification found an invalid normalized FDI tooth.'
            }
            $withTooth++
        }
        if ([string](Get-DwImportProperty -InputObject $data -Name 'catalogLinkMethod') -eq 'legacy_custom') { $legacyCustom++ }
        $migration = Get-DwImportProperty -InputObject $data -Name 'migration'
        if ($null -eq $migration -or
            (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id -or
            (Get-DwImportProperty -InputObject $migration -Name 'treatment_history_pilot') -ne $true) {
            throw 'Treatment-history verification found a record outside the guarded pilot.'
        }
    }

    $treatmentProvenance = @($rows | Where-Object {
            $_.store -eq 'migration_external_identifiers' -and
            [string](Get-DwImportProperty -InputObject $_.data -Name 'target_store') -eq 'treatment_history'
        })
    if ($treatmentProvenance.Count -ne $treatments.Count) {
        throw 'Treatment-history verification found missing provenance records.'
    }
    $report = [ordered]@{
        mode = 'isolated_treatment_history_pilot_verification'
        verified_utc = [DateTime]::UtcNow.ToString('o')
        server_host = '127.0.0.1'
        pilot_patients = $patients.Count
        treatment_records = $treatments.Count
        completed_treatments = $completed
        treatment_plan_items = $planned
        treatments_with_parseable_date = $withDate
        treatments_with_normalized_tooth = $withTooth
        legacy_custom_treatments = $legacyCustom
        provenance_records = $treatmentProvenance.Count
        duplicate_record_ids = 0
        production_import_authorized = $false
        contains_patient_values = $false
        verified = $true
    }
    Write-DwImportJson -Path (Join-Path $root 'reports/treatment-history-pilot-verification-summary.json') -Value $report
    return [pscustomobject]$report
}

function ConvertTo-DwTherapyGroupData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Group,
        [Parameter(Mandatory = $true)][string]$BatchId,
        [Parameter(Mandatory = $true)][string]$GuardId,
        [Parameter(Mandatory = $true)][long]$ColorValue
    )

    $stageKey = [string](Get-DwImportProperty -InputObject $Group -Name 'stage_key')
    $name = [string](Get-DwImportProperty -InputObject $Group -Name 'name')
    if ([string]::IsNullOrWhiteSpace($stageKey) -or [string]::IsNullOrWhiteSpace($name)) {
        throw 'A staged therapy group is missing its stable key or display name.'
    }
    $order = 0
    [void][int]::TryParse([string](Get-DwImportProperty -InputObject $Group -Name 'order' -Default '0'), [ref]$order)
    return [ordered]@{
        title = $name.Trim()
        name = $name.Trim()
        displayOrder = $order
        colorValue = $ColorValue
        hidden = ((ConvertTo-DwNullableBoolean (Get-DwImportProperty -InputObject $Group -Name 'hidden')) -eq $true)
        sourceID = [string](Get-DwImportProperty -InputObject $Group -Name 'source_id')
        migration = [ordered]@{
            batch_id = $BatchId
            guard_id = $GuardId
            source_stage_key = $stageKey
            source_system = 'DentalWin'
            pilot = $true
            therapy_catalogue_pilot = $true
        }
    }
}

function ConvertTo-DwProcedureCatalogData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Procedure,
        [Parameter(Mandatory = $true)][string]$TargetGroupId,
        [Parameter(Mandatory = $true)][string]$BatchId,
        [Parameter(Mandatory = $true)][string]$GuardId
    )

    $stageKey = [string](Get-DwImportProperty -InputObject $Procedure -Name 'stage_key')
    $name = [string](Get-DwImportProperty -InputObject $Procedure -Name 'name')
    if ([string]::IsNullOrWhiteSpace($stageKey) -or [string]::IsNullOrWhiteSpace($name) -or
        [string]::IsNullOrWhiteSpace($TargetGroupId)) {
        throw 'A staged procedure is missing its stable key, display name, or target therapy group.'
    }

    $basePrice = 0.0
    [void][double]::TryParse(
        [string](Get-DwImportProperty -InputObject $Procedure -Name 'base_price' -Default '0'),
        [System.Globalization.NumberStyles]::Any,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$basePrice
    )
    $duration = 0
    $durationValue = Get-DwImportProperty -InputObject $Procedure -Name 'duration_minutes_raw'
    $hasDuration = [int]::TryParse([string]$durationValue, [ref]$duration) -and $duration -gt 0
    $toothRequired = ConvertTo-DwNullableBoolean (Get-DwImportProperty -InputObject $Procedure -Name 'tooth_required_raw')
    $perToothPrice = ConvertTo-DwNullableBoolean (Get-DwImportProperty -InputObject $Procedure -Name 'per_tooth_price_raw')

    $data = [ordered]@{
        title = $name.Trim()
        name = $name.Trim()
        therapyGroupID = $TargetGroupId
        therapyGroupSourceID = [string](Get-DwImportProperty -InputObject $Procedure -Name 'therapy_group_source_id')
        sourceCode = [string](Get-DwImportProperty -InputObject $Procedure -Name 'source_code')
        basePrice = $basePrice
        hidden = $false
        migration = [ordered]@{
            batch_id = $BatchId
            guard_id = $GuardId
            source_stage_key = $stageKey
            source_system = 'DentalWin'
            pilot = $true
            therapy_catalogue_pilot = $true
        }
    }
    if ($null -ne $toothRequired) { $data.toothRequired = $toothRequired }
    if ($null -ne $perToothPrice) { $data.perToothPrice = $perToothPrice }
    if ($hasDuration) { $data.durationMinutes = $duration }
    return $data
}

function Invoke-DwTherapyCataloguePilot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$TestServerDirectory,
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$StagingKeyFile,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    $root = (Resolve-Path -LiteralPath $TestServerDirectory).Path
    $marker = Get-Content -LiteralPath (Join-Path $root '.dentalwin-phase4-test-guard.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $staging = (Resolve-Path -LiteralPath $StagingDirectory).Path
    $summary = Get-Content -LiteralPath (Join-Path $staging 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($marker.server_url -ne $server -or
        $marker.staging_directory -ne $staging -or
        $marker.staging_batch_id -ne $summary.batch_id -or
        $marker.production_import_authorized -ne $false -or
        $summary.writes_to_apexo -ne $false) {
        throw 'Safety lock: the therapy-catalogue pilot does not match the isolated Phase 4 server and staging batch.'
    }

    $headers = Get-DwTestServerAuth -ServerUrl $server -Email $Email -PasswordFile $PasswordFile
    $existingRows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    $allowedStores = @(
        '', 'settings_global', 'patients', 'appointments', 'treatment_history',
        'therapy_groups', 'procedure_catalog',
        'migration_batches', 'migration_external_identifiers'
    )
    foreach ($row in $existingRows) {
        if ([string]$row.store -notin $allowedStores) {
            throw 'Safety lock: the test server contains a store outside the catalogue-pilot allow-list.'
        }
        if ([string]$row.store -notin @('', 'settings_global')) {
            $migration = Get-DwImportProperty -InputObject $row.data -Name 'migration'
            if ($null -eq $migration -or
                (Get-DwImportProperty -InputObject $migration -Name 'batch_id') -ne $summary.batch_id -or
                (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id) {
                throw 'Safety lock: the test server contains data outside the guarded pilot batch.'
            }
        }
    }

    $stagingKey = [System.IO.File]::ReadAllText(
        (Resolve-Path -LiteralPath $StagingKeyFile).Path,
        [System.Text.Encoding]::UTF8
    ).Trim()
    try {
        $groups = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/therapy_groups.jsonl.enc.json') -Passphrase $stagingKey)
        $catalog = @(Read-DwProtectedJsonLines -Path (Join-Path $staging 'protected/normalized/procedure_catalog.jsonl.enc.json') -Passphrase $stagingKey)
    }
    finally { $stagingKey = $null }

    $expectedGroups = [int]$summary.staged_counts.therapy_groups
    $expectedProcedures = [int]$summary.staged_counts.procedure_catalog
    if ($groups.Count -ne $expectedGroups -or $catalog.Count -ne $expectedProcedures -or
        $groups.Count -gt 50 -or $catalog.Count -gt 1000) {
        throw 'Safety lock: staged and reported therapy-catalogue counts do not match safe pilot limits.'
    }
    if (@($groups.stage_key | Sort-Object -Unique).Count -ne $groups.Count -or
        @($catalog.stage_key | Sort-Object -Unique).Count -ne $catalog.Count) {
        throw 'Safety lock: the therapy catalogue contains duplicate staging keys.'
    }

    $palette = @(
        0xFF0F8B8D, 0xFF246BCE, 0xFF7A5AF8, 0xFFE05D5D,
        0xFF2E9D63, 0xFFE08A1E, 0xFFB34FA2, 0xFF477A8B,
        0xFF6D7F2B, 0xFF8E6548, 0xFF5B6BC0, 0xFF008F7A,
        0xFFC05C84, 0xFF55778C
    )
    $groupTargets = @{}
    $createdGroups = 0
    $alreadyGroups = 0
    for ($index = 0; $index -lt $groups.Count; $index++) {
        $group = $groups[$index]
        $stageKey = [string]$group.stage_key
        $targetId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'therapy_groups' -StageKey $stageKey
        $data = ConvertTo-DwTherapyGroupData -Group $group -BatchId $summary.batch_id -GuardId $marker.marker_id -ColorValue $palette[$index % $palette.Count]
        $data.id = $targetId
        $sourceId = [string]$group.source_id
        if ([string]::IsNullOrWhiteSpace($sourceId) -or $groupTargets.ContainsKey($sourceId)) {
            throw 'Safety lock: a therapy group has a missing or duplicate source identity.'
        }
        $groupTargets[$sourceId] = $targetId
        $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $targetId -Store 'therapy_groups' -Data $data -BatchId $summary.batch_id -StageKey $stageKey
        if ($result -eq 'created') { $createdGroups++ } else { $alreadyGroups++ }
    }

    $uncategorized = @($catalog | Where-Object {
            $sourceGroup = [string]$_.therapy_group_source_id
            [string]::IsNullOrWhiteSpace($sourceGroup) -or -not $groupTargets.ContainsKey($sourceGroup)
        })
    $uncategorizedId = ''
    if ($uncategorized.Count -gt 0) {
        $uncategorizedStageKey = 'therapy-group:target-generated-uncategorized-review'
        $uncategorizedId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'therapy_groups' -StageKey $uncategorizedStageKey
        $uncategorizedData = [ordered]@{
            id = $uncategorizedId
            title = 'Uncategorized legacy review'
            name = 'Uncategorized legacy review'
            displayOrder = $groups.Count
            colorValue = 0xFF777777
            hidden = $false
            migration = [ordered]@{
                batch_id = $summary.batch_id
                guard_id = $marker.marker_id
                source_stage_key = $uncategorizedStageKey
                source_system = 'DentalWin'
                pilot = $true
                therapy_catalogue_pilot = $true
                target_generated_review_bucket = $true
            }
        }
        $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $uncategorizedId -Store 'therapy_groups' -Data $uncategorizedData -BatchId $summary.batch_id -StageKey $uncategorizedStageKey
        if ($result -eq 'created') { $createdGroups++ } else { $alreadyGroups++ }
    }

    $createdProcedures = 0
    $alreadyProcedures = 0
    foreach ($procedure in $catalog) {
        $stageKey = [string]$procedure.stage_key
        $sourceGroup = [string]$procedure.therapy_group_source_id
        $targetGroupId = if ($groupTargets.ContainsKey($sourceGroup)) { [string]$groupTargets[$sourceGroup] } else { $uncategorizedId }
        $targetId = Get-DwDeterministicPocketBaseId -BatchId $summary.batch_id -Store 'procedure_catalog' -StageKey $stageKey
        $data = ConvertTo-DwProcedureCatalogData -Procedure $procedure -TargetGroupId $targetGroupId -BatchId $summary.batch_id -GuardId $marker.marker_id
        $data.id = $targetId
        $result = Add-DwPilotRecord -ServerUrl $server -Headers $headers -Id $targetId -Store 'procedure_catalog' -Data $data -BatchId $summary.batch_id -StageKey $stageKey
        if ($result -eq 'created') { $createdProcedures++ } else { $alreadyProcedures++ }
    }

    $report = [ordered]@{
        mode = 'isolated_therapy_catalogue_pilot'
        created_utc = [DateTime]::UtcNow.ToString('o')
        server_host = '127.0.0.1'
        source_therapy_groups = $groups.Count
        target_therapy_groups = $groups.Count + $(if ($uncategorized.Count -gt 0) { 1 } else { 0 })
        procedures = $catalog.Count
        uncategorized_procedures = $uncategorized.Count
        created_group_records = $createdGroups
        already_imported_group_records = $alreadyGroups
        created_procedure_records = $createdProcedures
        already_imported_procedure_records = $alreadyProcedures
        production_import_authorized = $false
        writes_to_dentalwin = $false
        contains_patient_values = $false
    }
    Write-DwImportJson -Path (Join-Path $root 'reports/therapy-catalogue-pilot-import-summary.json') -Value $report
    return [pscustomobject]$report
}

function Test-DwTherapyCataloguePilot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][string]$TestServerDirectory,
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$StagingKeyFile,
        [Parameter(Mandatory = $true)][string]$Email,
        [Parameter(Mandatory = $true)][string]$PasswordFile
    )

    $server = Assert-DwLoopbackTestServerUrl -ServerUrl $ServerUrl
    $root = (Resolve-Path -LiteralPath $TestServerDirectory).Path
    $marker = Get-Content -LiteralPath (Join-Path $root '.dentalwin-phase4-test-guard.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($marker.server_url -ne $server -or $marker.production_import_authorized -ne $false) {
        throw 'Safety lock: catalogue verification is not pointed at the isolated pilot server.'
    }
    $headers = Get-DwTestServerAuth -ServerUrl $server -Email $Email -PasswordFile $PasswordFile
    $rows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    $groups = @($rows | Where-Object store -eq 'therapy_groups')
    $procedures = @($rows | Where-Object store -eq 'procedure_catalog')
    $staging = (Resolve-Path -LiteralPath $StagingDirectory).Path
    $summary = Get-Content -LiteralPath (Join-Path $staging 'reports/summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($procedures.Count -ne [int]$summary.staged_counts.procedure_catalog -or
        $groups.Count -lt [int]$summary.staged_counts.therapy_groups -or
        $groups.Count -gt ([int]$summary.staged_counts.therapy_groups + 1)) {
        throw 'Catalogue verification found a staged/imported count mismatch.'
    }
    $groupIds = @{}
    foreach ($record in $groups) {
        $groupIds[[string]$record.id] = $true
        $migration = Get-DwImportProperty -InputObject $record.data -Name 'migration'
        if ($null -eq $migration -or
            (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id -or
            (Get-DwImportProperty -InputObject $migration -Name 'therapy_catalogue_pilot') -ne $true) {
            throw 'Catalogue verification found a therapy group outside the guarded pilot.'
        }
    }
    $unknownToothRequirement = 0
    foreach ($record in $procedures) {
        $data = $record.data
        if ([string]::IsNullOrWhiteSpace([string](Get-DwImportProperty -InputObject $data -Name 'name')) -or
            -not $groupIds.ContainsKey([string](Get-DwImportProperty -InputObject $data -Name 'therapyGroupID'))) {
            throw 'Catalogue verification found a procedure with an empty name or broken group link.'
        }
        if ($null -eq (Get-DwImportProperty -InputObject $data -Name 'toothRequired')) { $unknownToothRequirement++ }
        $migration = Get-DwImportProperty -InputObject $data -Name 'migration'
        if ($null -eq $migration -or
            (Get-DwImportProperty -InputObject $migration -Name 'guard_id') -ne $marker.marker_id -or
            (Get-DwImportProperty -InputObject $migration -Name 'therapy_catalogue_pilot') -ne $true) {
            throw 'Catalogue verification found a procedure outside the guarded pilot.'
        }
    }
    $report = [ordered]@{
        mode = 'isolated_therapy_catalogue_pilot_verification'
        verified_utc = [DateTime]::UtcNow.ToString('o')
        server_host = '127.0.0.1'
        therapy_groups = $groups.Count
        procedures = $procedures.Count
        procedures_with_unknown_tooth_requirement = $unknownToothRequirement
        duplicate_record_ids = $rows.Count - @($rows.id | Sort-Object -Unique).Count
        production_import_authorized = $false
        contains_patient_values = $false
        verified = $true
    }
    if ($report.duplicate_record_ids -ne 0) {
        throw 'Catalogue verification found duplicate PocketBase record IDs.'
    }
    Write-DwImportJson -Path (Join-Path $root 'reports/therapy-catalogue-pilot-verification-summary.json') -Value $report
    return [pscustomobject]$report
}

Export-ModuleMember -Function @(
    'Assert-DwLoopbackTestServerUrl',
    'Get-DwDeterministicPocketBaseId',
    'New-DwEmptyTestServerBackup',
    'Test-DwEmptyBackupManifest',
    'New-DwTestServerGuard',
    'ConvertTo-DwTreatmentHistoryData',
    'Invoke-DwPilotImport',
    'Test-DwPilotImport',
    'Invoke-DwTreatmentHistoryPilot',
    'Test-DwTreatmentHistoryPilot',
    'ConvertTo-DwTherapyGroupData',
    'ConvertTo-DwProcedureCatalogData',
    'Invoke-DwTherapyCataloguePilot',
    'Test-DwTherapyCataloguePilot'
)
