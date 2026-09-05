[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('DryRun', 'Import')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$DatabasePath,

    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedCsvSha256,

    [string]$ExpectedDatabaseSha256 = '',

    [Parameter(Mandatory = $true)]
    [string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ApprovedHeaders = @(
    'index', 'last_name', 'first_name', 'profession', 'address', 'city', 'area',
    'postal_code', 'afm', 'doy', 'amka', 'birth_date', 'registration_date',
    'mobile', 'email', 'referrer', 'patient_notes', 'history_reason',
    'history_present_state', 'history_medicines', 'history_disease_surgery',
    'history_pregnancy', 'history_notes', 'history_allergy_notes',
    'hist_hypertension', 'hist_cardiovascular', 'hist_penicillin', 'hist_latex',
    'hist_asthma', 'hist_diabetes', 'hist_endocarditis', 'hist_epilepsy',
    'hist_pacemaker', 'hist_antibiotics_before', 'hist_smoking', 'hist_alcohol',
    'hist_chemo', 'hist_neuropathy', 'hist_coagulation'
)

function Write-BridgeResult {
    param([Parameter(Mandatory = $true)]$Value)
    $target = [System.IO.Path]::GetFullPath($ResultPath)
    $parent = Split-Path -Parent $target
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporary = Join-Path $parent ('.bridge-' + [Guid]::NewGuid().ToString('N') + '.json')
    try {
        $json = $Value | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($temporary, $json, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $target -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Get-AccessConnection {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][bool]$ReadOnly
    )
    $mode = if ($ReadOnly) { 'Read' } else { 'ReadWrite' }
    foreach ($provider in @('Microsoft.ACE.OLEDB.16.0', 'Microsoft.ACE.OLEDB.12.0')) {
        $connection = [System.Data.OleDb.OleDbConnection]::new(
            "Provider=$provider;Data Source=$Path;Mode=$mode;Persist Security Info=False;"
        )
        try {
            $connection.Open()
            return [pscustomobject]@{ Connection = $connection; Provider = $provider }
        }
        catch {
            $connection.Dispose()
        }
    }
    throw 'The DentalWin database did not open with ACE OLE DB 16.0 or 12.0 in this PowerShell architecture.'
}

function Get-TableColumns {
    param(
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection,
        [Parameter(Mandatory = $true)][string]$Table
    )
    $schema = $Connection.GetOleDbSchemaTable(
        [System.Data.OleDb.OleDbSchemaGuid]::Columns,
        @($null, $null, $Table, $null)
    )
    $columns = @{}
    foreach ($row in $schema.Rows) {
        $columns[[string]$row.COLUMN_NAME] = $row
    }
    return $columns
}

function Assert-TargetSchema {
    param([Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection)
    $customerColumns = Get-TableColumns -Connection $Connection -Table 'Customers'
    $contactColumns = Get-TableColumns -Connection $Connection -Table 'CustomerEpikoinonies'
    $requiredCustomers = @(
        'id', 'EPON', 'NAME', 'LAST', 'EPPAGGELMA', 'PEDIO2', 'PEDIO3', 'PEDIO4',
        'PEDIO5', 'afm', 'doy', 'amka', 'HMGENN', 'imerominia', 'SISTISAS',
        'diktio', 'sycr', 'chkk', 'efor', 'send', 'problima'
    )
    $requiredContacts = @('id', 'epikoinonia', 'guidss', 'guidsspelati', 'sms_contact', 'typos')
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($column in $requiredCustomers) {
        if (-not $customerColumns.ContainsKey($column)) { $missing.Add("Customers.$column") }
    }
    foreach ($column in $requiredContacts) {
        if (-not $contactColumns.ContainsKey($column)) { $missing.Add("CustomerEpikoinonies.$column") }
    }
    if ($missing.Count -gt 0) {
        throw ('The database does not match the confirmed DentalWin V6/V7 schema. Missing: ' + ($missing -join ', '))
    }
    return [pscustomobject]@{ Customers = $customerColumns; Contacts = $contactColumns }
}

function Get-NormalizedText {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return '' }
    $text = ([string]$Value).Trim().ToUpperInvariant().Normalize([Text.NormalizationForm]::FormD)
    $builder = [Text.StringBuilder]::new()
    foreach ($character in $text.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    return ([regex]::Replace($builder.ToString(), '\s+', ' ')).Trim()
}

function Get-NormalizedPhone {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return '' }
    return [regex]::Replace([string]$Value, '\D', '')
}

function Get-DateOnly {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull] -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return ''
    }
    if ($Value -is [DateTime]) { return ([DateTime]$Value).ToString('yyyy-MM-dd') }
    $parsed = [DateTime]::MinValue
    if ([DateTime]::TryParse([string]$Value, [ref]$parsed)) { return $parsed.ToString('yyyy-MM-dd') }
    return ''
}

function Get-ExistingIdentitySets {
    param([Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection)
    $amka = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $afm = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $nameBirth = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $mobile = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $email = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $command = $Connection.CreateCommand()
    $command.CommandText = 'SELECT [amka], [afm], [NAME], [LAST], [HMGENN] FROM [Customers]'
    $reader = $command.ExecuteReader()
    try {
        while ($reader.Read()) {
            $amkaValue = ([string]$reader.GetValue(0)).Trim()
            $afmValue = ([string]$reader.GetValue(1)).Trim()
            if ($amkaValue) { [void]$amka.Add($amkaValue) }
            if ($afmValue) { [void]$afm.Add($afmValue) }
            $name = Get-NormalizedText (([string]$reader.GetValue(2)) + ' ' + ([string]$reader.GetValue(3)))
            $birth = Get-DateOnly $reader.GetValue(4)
            if ($name -and $birth) { [void]$nameBirth.Add("$name|$birth") }
        }
    }
    finally {
        $reader.Close()
        $reader.Dispose()
        $command.Dispose()
    }

    $command = $Connection.CreateCommand()
    $command.CommandText = 'SELECT [typos], [epikoinonia] FROM [CustomerEpikoinonies] WHERE [typos] IN (2,4)'
    $reader = $command.ExecuteReader()
    try {
        while ($reader.Read()) {
            $kind = [int]$reader.GetValue(0)
            $value = [string]$reader.GetValue(1)
            if ($kind -eq 2) {
                $normalized = Get-NormalizedPhone $value
                if ($normalized) { [void]$mobile.Add($normalized) }
            }
            elseif ($kind -eq 4) {
                $normalized = $value.Trim().ToLowerInvariant()
                if ($normalized) { [void]$email.Add($normalized) }
            }
        }
    }
    finally {
        $reader.Close()
        $reader.Dispose()
        $command.Dispose()
    }
    return [pscustomobject]@{ Amka = $amka; Afm = $afm; NameBirth = $nameBirth; Mobile = $mobile; Email = $email }
}

function Get-DuplicateReasons {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)]$Sets
    )
    $reasons = [Collections.Generic.List[string]]::new()
    $amka = ([string]$Row.amka).Trim()
    $afm = ([string]$Row.afm).Trim()
    $email = ([string]$Row.email).Trim().ToLowerInvariant()
    $mobile = Get-NormalizedPhone $Row.mobile
    $name = Get-NormalizedText (([string]$Row.last_name) + ' ' + ([string]$Row.first_name))
    $birth = Get-DateOnly $Row.birth_date
    if ($amka -and $Sets.Amka.Contains($amka)) { $reasons.Add('existing_amka') }
    if ($afm -and $Sets.Afm.Contains($afm)) { $reasons.Add('existing_afm') }
    if ($email -and $Sets.Email.Contains($email)) { $reasons.Add('existing_email') }
    if ($mobile -and $Sets.Mobile.Contains($mobile)) { $reasons.Add('existing_mobile') }
    if ($name -and $birth -and $Sets.NameBirth.Contains("$name|$birth")) { $reasons.Add('existing_name_birth') }
    return @($reasons)
}

function Assert-CsvContract {
    param([Parameter(Mandatory = $true)]$Rows)
    if ($Rows.Count -eq 0) { throw 'The CSV contains no patient rows.' }
    $actualHeaders = @($Rows[0].PSObject.Properties.Name)
    if (($actualHeaders -join "`n") -cne ($ApprovedHeaders -join "`n")) {
        throw 'The CSV headers/order do not match the approved V6/V7 schema.'
    }
    $line = 1
    foreach ($row in $Rows) {
        $line++
        if ([string]::IsNullOrWhiteSpace([string]$row.last_name) -or
            [string]::IsNullOrWhiteSpace([string]$row.first_name)) {
            throw "CSV row ${line}: first_name/last_name are required."
        }
        foreach ($field in @('patient_notes', 'history_reason', 'history_present_state', 'history_medicines', 'history_disease_surgery', 'history_pregnancy', 'history_notes', 'history_allergy_notes')) {
            if (-not [string]::IsNullOrWhiteSpace([string]$row.$field)) {
                throw "CSV row ${line}: contact-only import does not allow $field."
            }
        }
        foreach ($field in @('hist_hypertension', 'hist_cardiovascular', 'hist_penicillin', 'hist_latex', 'hist_asthma', 'hist_diabetes', 'hist_endocarditis', 'hist_epilepsy', 'hist_pacemaker', 'hist_antibiotics_before', 'hist_smoking', 'hist_alcohol', 'hist_chemo', 'hist_neuropathy', 'hist_coagulation')) {
            $value = ([string]$row.$field).Trim().ToLowerInvariant()
            if ($value -notin @('', '0', '0.0', 'false')) {
                throw "CSV row ${line}: contact-only import does not allow $field."
            }
        }
    }
}

function Add-OleDbParameter {
    param(
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbCommand]$Command,
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbType]$Type,
        [AllowNull()][object]$Value,
        [int]$Size = 0
    )
    $parameter = if ($Size -gt 0) { $Command.Parameters.Add('?', $Type, $Size) } else { $Command.Parameters.Add('?', $Type) }
    $parameter.Value = if ($null -eq $Value) { [DBNull]::Value } else { $Value }
}

function Add-DentalWinPatient {
    param(
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection,
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbTransaction]$Transaction,
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][ref]$NextPatientId,
        [Parameter(Mandatory = $true)][ref]$NextContactId
    )
    $patientGuid = [Guid]::NewGuid().ToString()
    $columns = [Collections.Generic.List[string]]::new()
    $types = [Collections.Generic.List[System.Data.OleDb.OleDbType]]::new()
    $sizes = [Collections.Generic.List[int]]::new()
    $values = [Collections.Generic.List[object]]::new()

    function Add-Value([string]$Column, [System.Data.OleDb.OleDbType]$Type, [int]$Size, [object]$Value) {
        $columns.Add($Column); $types.Add($Type); $sizes.Add($Size); $values.Add($Value)
    }
    Add-Value 'id' ([System.Data.OleDb.OleDbType]::Integer) 0 $NextPatientId.Value
    Add-Value 'EPON' ([System.Data.OleDb.OleDbType]::VarWChar) 50 $patientGuid
    Add-Value 'NAME' ([System.Data.OleDb.OleDbType]::VarWChar) 50 ([string]$Row.last_name)
    Add-Value 'LAST' ([System.Data.OleDb.OleDbType]::VarWChar) 50 ([string]$Row.first_name)
    foreach ($flag in @('diktio', 'sycr', 'chkk', 'efor', 'send', 'problima')) {
        Add-Value $flag ([System.Data.OleDb.OleDbType]::Boolean) 0 $false
    }
    $textMappings = [ordered]@{
        EPPAGGELMA = @('profession', 100); PEDIO2 = @('address', 255); PEDIO3 = @('city', 255)
        PEDIO4 = @('area', 255); PEDIO5 = @('postal_code', 255); afm = @('afm', 50)
        doy = @('doy', 50); amka = @('amka', 255); SISTISAS = @('referrer', 255)
    }
    foreach ($entry in $textMappings.GetEnumerator()) {
        $value = ([string]$Row.($entry.Value[0])).Trim()
        if ($value) { Add-Value $entry.Key ([System.Data.OleDb.OleDbType]::VarWChar) ([int]$entry.Value[1]) $value }
    }
    foreach ($entry in @(@('HMGENN', 'birth_date'), @('imerominia', 'registration_date'))) {
        $value = ([string]$Row.($entry[1])).Trim()
        if ($value) {
            $date = [DateTime]::ParseExact($value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            Add-Value $entry[0] ([System.Data.OleDb.OleDbType]::Date) 0 $date
        }
    }

    $command = $Connection.CreateCommand()
    $command.Transaction = $Transaction
    $command.CommandText = 'INSERT INTO [Customers] (' + (($columns | ForEach-Object { "[$_]" }) -join ',') + ') VALUES (' + ((1..$columns.Count | ForEach-Object { '?' }) -join ',') + ')'
    for ($i = 0; $i -lt $columns.Count; $i++) { Add-OleDbParameter -Command $command -Type $types[$i] -Value $values[$i] -Size $sizes[$i] }
    try { [void]$command.ExecuteNonQuery() } finally { $command.Dispose() }

    foreach ($contact in @(@(2, [string]$Row.mobile), @(4, [string]$Row.email))) {
        $contactValue = $contact[1].Trim()
        if (-not $contactValue) { continue }
        $contactCommand = $Connection.CreateCommand()
        $contactCommand.Transaction = $Transaction
        $contactCommand.CommandText = 'INSERT INTO [CustomerEpikoinonies] ([id],[epikoinonia],[guidss],[guidsspelati],[sms_contact],[typos]) VALUES (?,?,?,?,?,?)'
        Add-OleDbParameter -Command $contactCommand -Type ([System.Data.OleDb.OleDbType]::Integer) -Value $NextContactId.Value
        Add-OleDbParameter -Command $contactCommand -Type ([System.Data.OleDb.OleDbType]::VarWChar) -Value $contactValue -Size 255
        Add-OleDbParameter -Command $contactCommand -Type ([System.Data.OleDb.OleDbType]::VarWChar) -Value ([Guid]::NewGuid().ToString()) -Size 50
        Add-OleDbParameter -Command $contactCommand -Type ([System.Data.OleDb.OleDbType]::VarWChar) -Value $patientGuid -Size 50
        Add-OleDbParameter -Command $contactCommand -Type ([System.Data.OleDb.OleDbType]::Boolean) -Value $false
        Add-OleDbParameter -Command $contactCommand -Type ([System.Data.OleDb.OleDbType]::UnsignedTinyInt) -Value ([byte]$contact[0])
        try { [void]$contactCommand.ExecuteNonQuery() } finally { $contactCommand.Dispose() }
        $NextContactId.Value++
    }
    $NextPatientId.Value++
    return $patientGuid
}

try {
    $database = (Resolve-Path -LiteralPath $DatabasePath).Path
    $csv = (Resolve-Path -LiteralPath $CsvPath).Path
    if ([IO.Path]::GetExtension($database).ToLowerInvariant() -notin @('.mdb', '.accdb')) {
        throw 'The DentalWin database must be .mdb or .accdb.'
    }
    $csvHash = Get-Sha256 $csv
    if ($csvHash -cne $ExpectedCsvSha256.ToLowerInvariant()) { throw 'The CSV changed after validation.' }
    $databaseHash = Get-Sha256 $database
    if ($Mode -eq 'Import' -and ($ExpectedDatabaseSha256 -eq '' -or $databaseHash -cne $ExpectedDatabaseSha256.ToLowerInvariant())) {
        throw 'The DentalWin database changed after dry run. Run a new dry run.'
    }
    $rows = @(Import-Csv -LiteralPath $csv -Encoding UTF8)
    Assert-CsvContract -Rows $rows
    $lockPath = [IO.Path]::ChangeExtension($database, '.ldb')
    $databaseLocked = Test-Path -LiteralPath $lockPath
    if ($Mode -eq 'Import' -and $databaseLocked) { throw 'The DentalWin database appears open (.ldb lock). Close DentalWin and run a new dry run.' }

    $opened = Get-AccessConnection -Path $database -ReadOnly:($Mode -eq 'DryRun')
    $connection = $opened.Connection
    try {
        [void](Assert-TargetSchema -Connection $connection)
        $sets = Get-ExistingIdentitySets -Connection $connection
        $planRows = [Collections.Generic.List[object]]::new()
        $importable = [Collections.Generic.List[object]]::new()
        $rowNumber = 1
        foreach ($row in $rows) {
            $rowNumber++
            $reasons = @(Get-DuplicateReasons -Row $row -Sets $sets)
            if ($reasons.Count -eq 0) {
                $importable.Add($row)
                $planRows.Add([ordered]@{ row_number = $rowNumber; status = 'new'; reason_codes = @() })
            }
            else {
                $planRows.Add([ordered]@{ row_number = $rowNumber; status = 'duplicate_skipped'; reason_codes = $reasons })
            }
        }

        if ($Mode -eq 'DryRun') {
            Write-BridgeResult ([ordered]@{
                ok = $true; mode = 'dry_run'; provider = $opened.Provider
                database_name = [IO.Path]::GetFileName($database); database_sha256 = $databaseHash
                csv_sha256 = $csvHash; row_count = $rows.Count; importable_count = $importable.Count
                duplicate_count = $rows.Count - $importable.Count; database_locked = $databaseLocked
                can_import = ($importable.Count -gt 0 -and -not $databaseLocked)
                rows = @($planRows); contains_patient_values = $false
            })
            return
        }

        if ($importable.Count -eq 0) { throw 'There are no new rows for DentalWin import.' }
        $backupDirectory = Join-Path (Split-Path -Parent $database) 'ApexoImportBackups'
        [IO.Directory]::CreateDirectory($backupDirectory) | Out-Null
        $backupName = [IO.Path]::GetFileNameWithoutExtension($database) + '.before-apexo-import-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + [IO.Path]::GetExtension($database)
        $backupPath = Join-Path $backupDirectory $backupName
        Copy-Item -LiteralPath $database -Destination $backupPath -ErrorAction Stop
        if ((Get-Sha256 $backupPath) -cne $databaseHash) { throw 'The automatic DentalWin backup could not be verified.' }

        $maxPatientCommand = $connection.CreateCommand()
        $maxPatientCommand.CommandText = 'SELECT MAX([id]) FROM [Customers]'
        $patientValue = $maxPatientCommand.ExecuteScalar(); $maxPatientCommand.Dispose()
        $nextPatientId = if ($null -eq $patientValue -or $patientValue -is [DBNull]) { 1 } else { [int]$patientValue + 1 }
        $maxContactCommand = $connection.CreateCommand()
        $maxContactCommand.CommandText = 'SELECT MAX([id]) FROM [CustomerEpikoinonies]'
        $contactValue = $maxContactCommand.ExecuteScalar(); $maxContactCommand.Dispose()
        $nextContactId = if ($null -eq $contactValue -or $contactValue -is [DBNull]) { 1 } else { [int]$contactValue + 1 }

        $transaction = $connection.BeginTransaction()
        $createdGuids = [Collections.Generic.List[string]]::new()
        try {
            foreach ($row in $importable) {
                $createdGuids.Add((Add-DentalWinPatient -Connection $connection -Transaction $transaction -Row $row -NextPatientId ([ref]$nextPatientId) -NextContactId ([ref]$nextContactId)))
            }
            $transaction.Commit()
        }
        catch {
            try { $transaction.Rollback() } catch {}
            throw
        }
        finally { $transaction.Dispose() }

        $verified = 0
        foreach ($guid in $createdGuids) {
            $verify = $connection.CreateCommand()
            $verify.CommandText = 'SELECT COUNT(*) FROM [Customers] WHERE [EPON] = ?'
            Add-OleDbParameter -Command $verify -Type ([System.Data.OleDb.OleDbType]::VarWChar) -Value $guid -Size 50
            try { if ([int]$verify.ExecuteScalar() -eq 1) { $verified++ } } finally { $verify.Dispose() }
        }
        if ($verified -ne $createdGuids.Count) { throw 'Post-import DentalWin verification failed.' }
    }
    finally {
        $connection.Close()
        $connection.Dispose()
    }

    Write-BridgeResult ([ordered]@{
        ok = $true; mode = 'import'; provider = $opened.Provider; database_name = [IO.Path]::GetFileName($database)
        database_sha256_before = $databaseHash; database_sha256_after = (Get-Sha256 $database)
        csv_sha256 = $csvHash; row_count = $rows.Count; created_count = $createdGuids.Count
        duplicate_skipped_count = $rows.Count - $createdGuids.Count; backup_path = $backupPath
        verified_count = $verified; rows = @($planRows); contains_patient_values = $false
    })
}
catch {
    Write-BridgeResult ([ordered]@{
        ok = $false; mode = $Mode.ToLowerInvariant(); error = $_.Exception.Message
        contains_patient_values = $false
    })
    exit 2
}
