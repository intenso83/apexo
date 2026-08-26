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

    $page = Invoke-RestMethod -Uri "$ServerUrl/api/collections/data/records?perPage=200" -Headers $Headers -TimeoutSec 15
    return @($page.items)
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
    $rows = @(Get-DwAllRemoteRows -ServerUrl $server -Headers $headers)
    if ($rows.Count -ne 31) { throw 'Pilot verification expected exactly 31 records.' }
    if (@($rows.id | Sort-Object -Unique).Count -ne $rows.Count) {
        throw 'Pilot verification found duplicate PocketBase record IDs.'
    }

    $patients = @($rows | Where-Object store -eq 'patients')
    $appointments = @($rows | Where-Object store -eq 'appointments')
    $provenance = @($rows | Where-Object store -eq 'migration_external_identifiers')
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
        total_records = $rows.Count
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

Export-ModuleMember -Function @(
    'Assert-DwLoopbackTestServerUrl',
    'Get-DwDeterministicPocketBaseId',
    'New-DwEmptyTestServerBackup',
    'Test-DwEmptyBackupManifest',
    'New-DwTestServerGuard',
    'Invoke-DwPilotImport',
    'Test-DwPilotImport'
)
