Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DwStageFormatVersion = '1.0.0'
$script:DwMappingVersion = '2026-08-26.phase4'
$script:DwEncryptionIterations = 210000
$script:DwCriticalTables = @(
    'Customers',
    'CustomerEpikoinonies',
    'DentalSchoolIstoriko',
    'Works_Kategories',
    'WooksTools',
    'WorksToolsShowType',
    'WorksPelati',
    'WorksPelatiD',
    'WorksPelatiU',
    'odontogrammata',
    'CustomerToothState',
    'NeogilaDontiaPelati',
    'CustomerImages',
    'Aktinografies2',
    'CustomerMemos',
    'RECALLS',
    'kinisi',
    'WorkPliromes',
    'Appointments2',
    'Appointments2_Log',
    'AppointmentCategories',
    'AppointmentsEtiketa',
    'AppointmentsORA'
)

function Get-DwProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $Default
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }
    return $property.Value
}

function Get-DwRows {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)][string]$Table
    )

    $tables = Get-DwProperty -InputObject $Fixture -Name 'tables'
    if ($null -eq $tables) {
        return @()
    }
    $rows = Get-DwProperty -InputObject $tables -Name $Table
    if ($null -eq $rows) {
        return @()
    }
    return @($rows)
}

function ConvertTo-DwNormalizedText {
    param($Value)

    if ($null -eq $Value) {
        return ''
    }
    return (([string]$Value).Trim() -replace '\s+', ' ').ToUpperInvariant()
}

function ConvertTo-DwSafeFileName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $safe = $Value -replace '[^A-Za-z0-9_.-]', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'unnamed'
    }
    return $safe
}

function Write-DwUtf8Text {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Write-DwJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $json = ConvertTo-Json -InputObject $Value -Depth 50
    Write-DwUtf8Text -Path $Path -Text $json
}

function Get-DwFileHashHex {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-DwRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $base = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $base.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $base += [System.IO.Path]::DirectorySeparatorChar
    }
    $baseUri = [System.Uri]::new($base)
    $pathUri = [System.Uri]::new([System.IO.Path]::GetFullPath($Path))
    return [System.Uri]::UnescapeDataString(
        $baseUri.MakeRelativeUri($pathUri).ToString()
    ).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Initialize-DwOutputDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$OutputDirectory,
        [string]$SourceDirectory
    )

    $outputFull = [System.IO.Path]::GetFullPath($OutputDirectory)
    if (-not [string]::IsNullOrWhiteSpace($SourceDirectory)) {
        $sourceFull = [System.IO.Path]::GetFullPath($SourceDirectory)
        $sourcePrefix = $sourceFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if ($outputFull.Equals($sourceFull, [System.StringComparison]::OrdinalIgnoreCase) -or
            $outputFull.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'The output directory must not be inside the DentalWin source directory.'
        }
    }

    if (Test-Path -LiteralPath $outputFull) {
        $existing = @(Get-ChildItem -LiteralPath $outputFull -Force)
        if ($existing.Count -gt 0) {
            throw "Output directory already exists and is not empty: $outputFull"
        }
    }
    else {
        [System.IO.Directory]::CreateDirectory($outputFull) | Out-Null
    }

    Write-DwUtf8Text -Path (Join-Path $outputFull '.dentalwin-private-staging') -Text @"
This directory is private migration material.
Do not commit, email, sync, or share it.
Protected row files require the staging passphrase.
"@
    return $outputFull
}

function Get-DwAccessProvider {
    $preferred = @('Microsoft.ACE.OLEDB.16.0', 'Microsoft.ACE.OLEDB.12.0')
    $available = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $reader = [System.Data.OleDb.OleDbEnumerator]::GetRootEnumerator()
    try {
        while ($reader.Read()) {
            [void]$available.Add([string]$reader.GetValue(0))
        }
    }
    finally {
        $reader.Close()
    }

    foreach ($provider in $preferred) {
        if ($available.Contains($provider)) {
            return $provider
        }
    }
    throw 'Microsoft Access Database Engine was not found. Install the ACE OLE DB provider before reading DentalWin databases.'
}

function Open-DwReadOnlyConnection {
    param(
        [Parameter(Mandatory = $true)][string]$DatabasePath,
        [Parameter(Mandatory = $true)][string]$Provider
    )

    $connectionString = "Provider=$Provider;Data Source=$DatabasePath;Mode=Read;Persist Security Info=False;"
    $connection = [System.Data.OleDb.OleDbConnection]::new($connectionString)
    $connection.Open()
    return $connection
}

function Get-DwTableCount {
    param(
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection,
        [Parameter(Mandatory = $true)][string]$Table
    )

    $quoted = $Table.Replace(']', ']]')
    $command = $Connection.CreateCommand()
    $command.CommandText = "SELECT COUNT(*) FROM [$quoted]"
    $command.CommandTimeout = 120
    return [int64]$command.ExecuteScalar()
}

function Get-DwDatabaseRole {
    param(
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection,
        [Parameter(Mandatory = $true)][System.Collections.Generic.HashSet[string]]$TableNames
    )

    if ($TableNames.Contains('Appointments2')) {
        return 'calendar'
    }
    if ($TableNames.Contains('Customers') -and $TableNames.Contains('WorksPelati')) {
        $patients = Get-DwTableCount -Connection $Connection -Table 'Customers'
        $works = Get-DwTableCount -Connection $Connection -Table 'WorksPelati'
        if ($patients -gt 0 -or $works -gt 0) {
            return 'clinical'
        }
        return 'dental-reference'
    }
    if ($TableNames.Contains('farmaka') -or $TableNames.Contains('FARMAKA')) {
        return 'medication-reference'
    }
    return 'unresolved-reference'
}

function Get-DwInventoryRecord {
    param(
        [Parameter(Mandatory = $true)][string]$DatabasePath,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$Provider
    )

    $beforeHash = Get-DwFileHashHex -Path $DatabasePath
    $file = Get-Item -LiteralPath $DatabasePath
    $connection = $null
    try {
        $connection = Open-DwReadOnlyConnection -DatabasePath $DatabasePath -Provider $Provider
        $tablesSchema = $connection.GetSchema('Tables')
        $tableNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        foreach ($row in $tablesSchema.Rows) {
            if ([string]$row['TABLE_TYPE'] -eq 'TABLE') {
                [void]$tableNames.Add([string]$row['TABLE_NAME'])
            }
        }

        $role = Get-DwDatabaseRole -Connection $connection -TableNames $tableNames
        $critical = [System.Collections.ArrayList]::new()
        $columnsSchema = $connection.GetSchema('Columns')
        foreach ($table in $script:DwCriticalTables) {
            if (-not $tableNames.Contains($table)) {
                continue
            }
            $columns = @(
                $columnsSchema.Rows |
                    Where-Object { [string]$_['TABLE_NAME'] -eq $table } |
                    Sort-Object { [int]$_['ORDINAL_POSITION'] } |
                    ForEach-Object { [string]$_['COLUMN_NAME'] }
            )
            [void]$critical.Add([ordered]@{
                    table   = $table
                    rows    = Get-DwTableCount -Connection $connection -Table $table
                    columns = $columns
                })
        }
        $connection.Close()
        $connection = $null

        $afterHash = Get-DwFileHashHex -Path $DatabasePath
        if ($beforeHash -ne $afterHash) {
            throw "Source database changed while being inventoried: $DatabasePath"
        }

        return [ordered]@{
            relative_path       = Get-DwRelativePath -BasePath $SourceRoot -Path $DatabasePath
            sha256              = $beforeHash
            size_bytes          = [int64]$file.Length
            last_write_utc      = $file.LastWriteTimeUtc.ToString('o')
            role                = $role
            user_table_count    = $tableNames.Count
            critical_tables     = @($critical)
            source_hash_unchanged = $true
            error               = $null
        }
    }
    catch {
        if ($null -ne $connection) {
            try { $connection.Close() } catch { }
        }
        $afterHash = Get-DwFileHashHex -Path $DatabasePath
        return [ordered]@{
            relative_path       = Get-DwRelativePath -BasePath $SourceRoot -Path $DatabasePath
            sha256              = $beforeHash
            size_bytes          = [int64]$file.Length
            last_write_utc      = $file.LastWriteTimeUtc.ToString('o')
            role                = 'error'
            user_table_count    = 0
            critical_tables     = @()
            source_hash_unchanged = ($beforeHash -eq $afterHash)
            error               = $_.Exception.Message
        }
    }
}

function Write-DwChecksums {
    param([Parameter(Mandatory = $true)][string]$Root)

    $checksumPath = Join-Path $Root 'checksums.sha256'
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName) {
        if ($file.FullName -eq $checksumPath) {
            continue
        }
        $relative = Get-DwRelativePath -BasePath $Root -Path $file.FullName
        $lines.Add("$(Get-DwFileHashHex -Path $file.FullName)  $relative")
    }
    Write-DwUtf8Text -Path $checksumPath -Text (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Invoke-DwInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$OutputDirectory
    )

    $source = (Resolve-Path -LiteralPath $SourceDirectory).Path
    if (-not (Get-Item -LiteralPath $source).PSIsContainer) {
        throw 'SourceDirectory must be a folder.'
    }
    $output = Initialize-DwOutputDirectory -OutputDirectory $OutputDirectory -SourceDirectory $source
    $provider = Get-DwAccessProvider
    $databases = @(Get-ChildItem -LiteralPath $source -Recurse -File -Filter '*.mdb' | Sort-Object FullName)
    if ($databases.Count -eq 0) {
        throw 'No .mdb databases were found in the source directory.'
    }

    $records = [System.Collections.ArrayList]::new()
    foreach ($database in $databases) {
        [void]$records.Add((Get-DwInventoryRecord -DatabasePath $database.FullName -SourceRoot $source -Provider $provider))
    }

    $hasErrors = @($records | Where-Object { $null -ne $_.error }).Count -gt 0
    $allUnchanged = @($records | Where-Object { -not $_.source_hash_unchanged }).Count -eq 0
    $manifest = [ordered]@{
        format_version        = $script:DwStageFormatVersion
        mapping_version       = $script:DwMappingVersion
        mode                  = 'inventory'
        created_utc           = [DateTime]::UtcNow.ToString('o')
        source_root_name      = Split-Path -Leaf $source
        access_provider       = $provider
        database_count        = $databases.Count
        complete              = (-not $hasErrors -and $allUnchanged)
        source_hashes_unchanged = $allUnchanged
        databases             = @($records)
    }
    Write-DwJsonFile -Path (Join-Path $output 'manifest.json') -Value $manifest

    $markdown = [System.Collections.Generic.List[string]]::new()
    $markdown.Add('# DentalWin Inventory Report')
    $markdown.Add('')
    $markdown.Add("- Mode: read-only inventory")
    $markdown.Add("- Databases found: $($databases.Count)")
    $markdown.Add("- Access provider: $provider")
    $markdown.Add("- Source hashes unchanged: $allUnchanged")
    $markdown.Add("- Complete: $(-not $hasErrors -and $allUnchanged)")
    $markdown.Add('')
    $markdown.Add('| Database role | Critical tables | Status |')
    $markdown.Add('|---|---:|---|')
    foreach ($record in $records) {
        $status = if ($null -eq $record.error) { 'OK' } else { 'ERROR' }
        $markdown.Add("| $($record.role) | $(@($record.critical_tables).Count) | $status |")
    }
    Write-DwUtf8Text -Path (Join-Path $output 'summary.md') -Text (($markdown -join [Environment]::NewLine) + [Environment]::NewLine)
    Write-DwChecksums -Root $output

    return [pscustomobject]@{
        Mode = 'Inventory'
        OutputDirectory = $output
        DatabaseCount = $databases.Count
        Complete = (-not $hasErrors -and $allUnchanged)
        SourceHashesUnchanged = $allUnchanged
    }
}

function New-DwDerivedKeyBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Passphrase,
        [Parameter(Mandatory = $true)][byte[]]$Salt,
        [Parameter(Mandatory = $true)][int]$Iterations
    )

    if ($Passphrase.Length -lt 16) {
        throw 'The staging passphrase must contain at least 16 characters.'
    }
    $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
        $Passphrase,
        $Salt,
        $Iterations,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    try {
        return $derive.GetBytes(64)
    }
    finally {
        $derive.Dispose()
    }
}

function Join-DwByteArrays {
    param([Parameter(Mandatory = $true)][byte[][]]$Arrays)

    $length = 0
    foreach ($array in $Arrays) {
        $length += $array.Length
    }
    $joined = [byte[]]::new($length)
    $offset = 0
    foreach ($array in $Arrays) {
        [System.Array]::Copy($array, 0, $joined, $offset, $array.Length)
        $offset += $array.Length
    }
    return $joined
}

function Test-DwFixedTimeEqual {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Left,
        [Parameter(Mandatory = $true)][byte[]]$Right
    )

    if ($Left.Length -ne $Right.Length) {
        return $false
    }
    $difference = 0
    for ($index = 0; $index -lt $Left.Length; $index++) {
        $difference = $difference -bor ($Left[$index] -bxor $Right[$index])
    }
    return $difference -eq 0
}

function Protect-DwText {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Passphrase
    )

    $salt = [byte[]]::new(16)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($salt)
    $keyMaterial = New-DwDerivedKeyBytes -Passphrase $Passphrase -Salt $salt -Iterations $script:DwEncryptionIterations
    $encryptionKey = [byte[]]$keyMaterial[0..31]
    $authenticationKey = [byte[]]$keyMaterial[32..63]

    $aes = [System.Security.Cryptography.Aes]::Create()
    try {
        $aes.KeySize = 256
        $aes.BlockSize = 128
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $encryptionKey
        $aes.GenerateIV()
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $encryptor = $aes.CreateEncryptor()
        try {
            $cipherText = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
        }
        finally {
            $encryptor.Dispose()
        }

        $authenticated = Join-DwByteArrays -Arrays @($salt, $aes.IV, $cipherText)
        $hmac = [System.Security.Cryptography.HMACSHA256]::new($authenticationKey)
        try {
            $tag = $hmac.ComputeHash($authenticated)
        }
        finally {
            $hmac.Dispose()
        }

        return [ordered]@{
            format     = 'apexo-dentalwin-encrypted-v1'
            kdf        = 'PBKDF2-HMAC-SHA256'
            iterations = $script:DwEncryptionIterations
            cipher     = 'AES-256-CBC'
            integrity  = 'HMAC-SHA256'
            salt       = [Convert]::ToBase64String($salt)
            iv         = [Convert]::ToBase64String($aes.IV)
            ciphertext = [Convert]::ToBase64String($cipherText)
            hmac       = [Convert]::ToBase64String($tag)
        }
    }
    finally {
        $aes.Dispose()
        [System.Array]::Clear($keyMaterial, 0, $keyMaterial.Length)
        [System.Array]::Clear($encryptionKey, 0, $encryptionKey.Length)
        [System.Array]::Clear($authenticationKey, 0, $authenticationKey.Length)
    }
}

function Unprotect-DwText {
    param(
        [Parameter(Mandatory = $true)]$Envelope,
        [Parameter(Mandatory = $true)][string]$Passphrase
    )

    if ((Get-DwProperty -InputObject $Envelope -Name 'format') -ne 'apexo-dentalwin-encrypted-v1') {
        throw 'Unsupported protected staging format.'
    }
    $salt = [Convert]::FromBase64String([string](Get-DwProperty -InputObject $Envelope -Name 'salt'))
    $iv = [Convert]::FromBase64String([string](Get-DwProperty -InputObject $Envelope -Name 'iv'))
    $cipherText = [Convert]::FromBase64String([string](Get-DwProperty -InputObject $Envelope -Name 'ciphertext'))
    $expectedTag = [Convert]::FromBase64String([string](Get-DwProperty -InputObject $Envelope -Name 'hmac'))
    $iterations = [int](Get-DwProperty -InputObject $Envelope -Name 'iterations')
    $keyMaterial = New-DwDerivedKeyBytes -Passphrase $Passphrase -Salt $salt -Iterations $iterations
    $encryptionKey = [byte[]]$keyMaterial[0..31]
    $authenticationKey = [byte[]]$keyMaterial[32..63]

    try {
        $authenticated = Join-DwByteArrays -Arrays @($salt, $iv, $cipherText)
        $hmac = [System.Security.Cryptography.HMACSHA256]::new($authenticationKey)
        try {
            $actualTag = $hmac.ComputeHash($authenticated)
        }
        finally {
            $hmac.Dispose()
        }
        if (-not (Test-DwFixedTimeEqual -Left $actualTag -Right $expectedTag)) {
            throw 'Protected staging data failed its integrity check or the passphrase is wrong.'
        }

        $aes = [System.Security.Cryptography.Aes]::Create()
        try {
            $aes.KeySize = 256
            $aes.BlockSize = 128
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
            $aes.Key = $encryptionKey
            $aes.IV = $iv
            $decryptor = $aes.CreateDecryptor()
            try {
                $plainBytes = $decryptor.TransformFinalBlock($cipherText, 0, $cipherText.Length)
                return [System.Text.Encoding]::UTF8.GetString($plainBytes)
            }
            finally {
                $decryptor.Dispose()
            }
        }
        finally {
            $aes.Dispose()
        }
    }
    finally {
        [System.Array]::Clear($keyMaterial, 0, $keyMaterial.Length)
        [System.Array]::Clear($encryptionKey, 0, $encryptionKey.Length)
        [System.Array]::Clear($authenticationKey, 0, $authenticationKey.Length)
    }
}

function Write-DwProtectedJsonLines {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][string]$Passphrase
    )

    $lines = @($Rows | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 50 -Compress })
    $plainText = $lines -join "`n"
    if ($lines.Count -gt 0) {
        $plainText += "`n"
    }
    $envelope = Protect-DwText -Text $plainText -Passphrase $Passphrase
    Write-DwJsonFile -Path $Path -Value $envelope
}

function Read-DwProtectedJsonLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Passphrase
    )

    $envelope = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $plainText = Unprotect-DwText -Envelope $envelope -Passphrase $Passphrase
    if ([string]::IsNullOrWhiteSpace($plainText)) {
        return @()
    }
    return @(
        $plainText -split "`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_ | ConvertFrom-Json }
    )
}

function Add-DwExternalIdentifier {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$List,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$Keys,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Reviews,
        [Parameter(Mandatory = $true)][string]$SourceTable,
        [Parameter(Mandatory = $true)][string]$SourceRecordKey,
        [Parameter(Mandatory = $true)][string]$TargetEntityType,
        [Parameter(Mandatory = $true)][string]$TargetStageKey,
        [Parameter(Mandatory = $true)][string]$DatabaseFingerprint
    )

    $key = "$DatabaseFingerprint/$SourceTable/$SourceRecordKey/$TargetEntityType"
    if (-not $Keys.Add($key)) {
        [void]$Reviews.Add([ordered]@{
                reason_code = 'duplicate_source_key'
                severity = 'error'
                source_table = $SourceTable
                source_record_key = $SourceRecordKey
                target_entity_type = $TargetEntityType
            })
        return
    }
    [void]$List.Add([ordered]@{
            external_key = $key
            source_system = 'DentalWin'
            source_database_fingerprint = $DatabaseFingerprint
            source_table = $SourceTable
            source_record_key = $SourceRecordKey
            target_entity_type = $TargetEntityType
            target_stage_key = $TargetStageKey
            mapping_version = $script:DwMappingVersion
        })
}

function Add-DwReview {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Reviews,
        [Parameter(Mandatory = $true)][string]$ReasonCode,
        [Parameter(Mandatory = $true)][string]$SourceTable,
        [Parameter(Mandatory = $true)][string]$SourceRecordKey,
        [ValidateSet('info', 'warning', 'error')][string]$Severity = 'warning'
    )

    [void]$Reviews.Add([ordered]@{
            reason_code = $ReasonCode
            severity = $Severity
            source_table = $SourceTable
            source_record_key = $SourceRecordKey
            status = 'pending'
        })
}

function Get-DwRowKey {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][int]$FallbackIndex
    )

    foreach ($name in @('id', 'ID', 'guidss', 'AppointmentCategoryID')) {
        $value = Get-DwProperty -InputObject $Row -Name $name
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            return [string]$value
        }
    }
    return "row-$FallbackIndex"
}

function Get-DwFixtureFingerprint {
    param([Parameter(Mandatory = $true)][string]$FixturePath)

    return Get-DwFileHashHex -Path $FixturePath
}

function ConvertTo-DwExtractedValue {
    param($Value)

    if ($null -eq $Value -or $Value -is [DBNull]) {
        return $null
    }
    if ($Value -is [byte[]]) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            return [ordered]@{
                binary_deferred = $true
                length_bytes = $Value.Length
                sha256 = ([Convert]::ToHexString($sha.ComputeHash($Value))).ToLowerInvariant()
            }
        }
        finally {
            $sha.Dispose()
        }
    }
    if ($Value -is [DateTime]) {
        return $Value.ToString('o')
    }
    if ($Value -is [Guid]) {
        return $Value.ToString()
    }
    return $Value
}

function Get-DwUserTableNames {
    param([Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection)

    $names = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $schema = $Connection.GetSchema('Tables')
    foreach ($row in $schema.Rows) {
        if ([string]$row['TABLE_TYPE'] -eq 'TABLE') {
            [void]$names.Add([string]$row['TABLE_NAME'])
        }
    }
    return $names
}

function Read-DwTableRows {
    param(
        [Parameter(Mandatory = $true)][System.Data.OleDb.OleDbConnection]$Connection,
        [Parameter(Mandatory = $true)][string]$Table
    )

    $quoted = $Table.Replace(']', ']]')
    $command = $Connection.CreateCommand()
    $reader = $null
    $rows = [System.Collections.ArrayList]::new()
    try {
        $command.CommandText = "SELECT * FROM [$quoted]"
        $command.CommandTimeout = 300
        $reader = $command.ExecuteReader()
        while ($reader.Read()) {
            $item = [ordered]@{}
            for ($index = 0; $index -lt $reader.FieldCount; $index++) {
                $item[$reader.GetName($index)] = ConvertTo-DwExtractedValue -Value $reader.GetValue($index)
            }
            [void]$rows.Add([pscustomobject]$item)
        }
    }
    finally {
        if ($null -ne $reader) {
            $reader.Close()
            $reader.Dispose()
        }
        $command.Dispose()
    }
    return @($rows)
}

function Get-DwCombinedFingerprint {
    param([Parameter(Mandatory = $true)][string[]]$Hashes)

    $text = (@($Hashes | Sort-Object) -join "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([Convert]::ToHexString($sha.ComputeHash($bytes))).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function New-DwPrivateKeyFile {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $fullPath) {
        throw "Private key file already exists: $fullPath"
    }
    $parent = Split-Path -Parent $fullPath
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $bytes = [byte[]]::new(64)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    try {
        [System.IO.File]::WriteAllText(
            $fullPath,
            [Convert]::ToBase64String($bytes),
            [System.Text.UTF8Encoding]::new($false)
        )
        try {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
            $security = [System.Security.AccessControl.FileSecurity]::new()
            $security.SetAccessRuleProtection($true, $false)
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $identity,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $security.AddAccessRule($rule)
            [System.IO.FileSystemAclExtensions]::SetAccessControl(
                [System.IO.FileInfo]::new($fullPath),
                $security
            )
        }
        catch {
            Remove-Item -LiteralPath $fullPath -Force -ErrorAction SilentlyContinue
            throw 'The private key was not created because Windows permissions could not be restricted.'
        }
    }
    finally {
        [System.Array]::Clear($bytes, 0, $bytes.Length)
    }
    return [pscustomobject]@{
        Path = $fullPath
        Created = $true
        PermissionsRestricted = $true
    }
}

function Get-DwPrivatePassphrase {
    param([Parameter(Mandatory = $true)][string]$KeyFile)

    $fullPath = (Resolve-Path -LiteralPath $KeyFile).Path
    $passphrase = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8).Trim()
    if ($passphrase.Length -lt 16) {
        throw 'The private key file is invalid.'
    }
    return $passphrase
}

function Invoke-DwSyntheticDryRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'FixtureFile')][string]$FixturePath,
        [Parameter(Mandatory = $true, ParameterSetName = 'FixtureObject')]$FixtureObject,
        [Parameter(Mandatory = $true, ParameterSetName = 'FixtureObject')][string]$SourceFingerprint,
        [Parameter(Mandatory = $true)][string]$OutputDirectory,
        [Parameter(Mandatory = $true)][string]$Passphrase,
        [Parameter(ParameterSetName = 'FixtureObject')][string]$SourceDirectory,
        [Parameter(ParameterSetName = 'FixtureObject')][ValidateSet('private_dry_run')][string]$RunMode = 'private_dry_run',
        [Parameter(ParameterSetName = 'FixtureObject')][bool]$SourceHashesUnchanged = $true
    )

    $isPrivateRun = $PSCmdlet.ParameterSetName -eq 'FixtureObject'
    if ($isPrivateRun) {
        $fixture = $FixtureObject
        $beforeHash = $SourceFingerprint
        if (-not $SourceHashesUnchanged) {
            throw 'A DentalWin source database changed during extraction. Private staging was refused.'
        }
    }
    else {
        $fixtureFull = (Resolve-Path -LiteralPath $FixturePath).Path
        $beforeHash = Get-DwFixtureFingerprint -FixturePath $fixtureFull
        $fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
        $metadata = Get-DwProperty -InputObject $fixture -Name 'metadata'
        if ($null -eq $metadata -or (Get-DwProperty -InputObject $metadata -Name 'synthetic') -ne $true) {
            throw 'SyntheticDryRun accepts only a fixture explicitly marked metadata.synthetic = true.'
        }
    }
    $output = Initialize-DwOutputDirectory -OutputDirectory $OutputDirectory -SourceDirectory $SourceDirectory
    foreach ($directory in @('protected/raw', 'protected/normalized', 'reports')) {
        [System.IO.Directory]::CreateDirectory((Join-Path $output $directory)) | Out-Null
    }

    $patients = [System.Collections.ArrayList]::new()
    $contacts = [System.Collections.ArrayList]::new()
    $histories = [System.Collections.ArrayList]::new()
    $groups = [System.Collections.ArrayList]::new()
    $catalog = [System.Collections.ArrayList]::new()
    $clinicalEvents = [System.Collections.ArrayList]::new()
    $appointments = [System.Collections.ArrayList]::new()
    $documents = [System.Collections.ArrayList]::new()
    $notes = [System.Collections.ArrayList]::new()
    $recalls = [System.Collections.ArrayList]::new()
    $finance = [System.Collections.ArrayList]::new()
    $externalIdentifiers = [System.Collections.ArrayList]::new()
    $reviews = [System.Collections.ArrayList]::new()
    $externalKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $patientsById = @{}
    $patientsByGuid = @{}
    $patientNameCounts = @{}
    $databaseFingerprint = $beforeHash

    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'Customers') {
        $index++
        $id = [string](Get-DwProperty -InputObject $row -Name 'id')
        $guid = [string](Get-DwProperty -InputObject $row -Name 'EPON')
        $stageKey = "patient:$id"
        $patient = [ordered]@{
            stage_key = $stageKey
            source_numeric_id = $id
            source_patient_guid = $guid
            surname = [string](Get-DwProperty -InputObject $row -Name 'NAME' -Default '')
            first_name = [string](Get-DwProperty -InputObject $row -Name 'LAST' -Default '')
            patronymic = [string](Get-DwProperty -InputObject $row -Name 'politis' -Default '')
            birth_date_raw = Get-DwProperty -InputObject $row -Name 'HMGENN'
            occupation = [string](Get-DwProperty -InputObject $row -Name 'EPPAGGELMA' -Default '')
            address_line = [string](Get-DwProperty -InputObject $row -Name 'PEDIO2' -Default '')
            city = [string](Get-DwProperty -InputObject $row -Name 'PEDIO3' -Default '')
            area = [string](Get-DwProperty -InputObject $row -Name 'PEDIO4' -Default '')
            postal_code = [string](Get-DwProperty -InputObject $row -Name 'PEDIO5' -Default '')
            registration_date_raw = Get-DwProperty -InputObject $row -Name 'imerominia'
            active_status_raw = Get-DwProperty -InputObject $row -Name 'PEDIO10'
            legacy_registration_number = [string](Get-DwProperty -InputObject $row -Name 'ar_mitroou' -Default '')
            legacy_folder_number = [string](Get-DwProperty -InputObject $row -Name 'aa_number' -Default '')
            legacy_sequence_number = [string](Get-DwProperty -InputObject $row -Name 'LST' -Default '')
            afm = [string](Get-DwProperty -InputObject $row -Name 'afm' -Default '')
            amka = [string](Get-DwProperty -InputObject $row -Name 'amka' -Default '')
            doy = [string](Get-DwProperty -InputObject $row -Name 'doy' -Default '')
            insurance = [string](Get-DwProperty -InputObject $row -Name 'ASFALIA' -Default '')
            referral_source = [string](Get-DwProperty -InputObject $row -Name 'SISTISAS' -Default '')
        }
        [void]$patients.Add($patient)
        if (-not [string]::IsNullOrWhiteSpace($id)) { $patientsById[$id] = $stageKey }
        if (-not [string]::IsNullOrWhiteSpace($guid)) { $patientsByGuid[$guid] = $stageKey }
        foreach ($candidate in @(
                (ConvertTo-DwNormalizedText "$($patient.surname) $($patient.first_name)"),
                (ConvertTo-DwNormalizedText "$($patient.first_name) $($patient.surname)")
            )) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                if (-not $patientNameCounts.ContainsKey($candidate)) { $patientNameCounts[$candidate] = 0 }
                $patientNameCounts[$candidate]++
            }
        }
        if ([string]::IsNullOrWhiteSpace($patient.surname) -or [string]::IsNullOrWhiteSpace($patient.first_name)) {
            Add-DwReview -Reviews $reviews -ReasonCode 'patient_name_missing_or_unsplittable' -SourceTable 'Customers' -SourceRecordKey $id
        }
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'Customers' -SourceRecordKey $id -TargetEntityType 'patient' -TargetStageKey $stageKey -DatabaseFingerprint $databaseFingerprint
    }

    $contactTypeMap = @{'0' = 'home_phone'; '1' = 'work_phone'; '2' = 'mobile'; '4' = 'email'}
    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'CustomerEpikoinonies') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
        $typeCode = [string](Get-DwProperty -InputObject $row -Name 'typos' -Default '')
        $patientStageKey = if ($patientsByGuid.ContainsKey($patientGuid)) { $patientsByGuid[$patientGuid] } else { $null }
        if ($null -eq $patientStageKey) {
            Add-DwReview -Reviews $reviews -ReasonCode 'orphan_contact' -SourceTable 'CustomerEpikoinonies' -SourceRecordKey $rowKey -Severity 'error'
        }
        $targetType = if ($contactTypeMap.ContainsKey($typeCode)) { $contactTypeMap[$typeCode] } else { 'other' }
        if ($targetType -eq 'other') {
            Add-DwReview -Reviews $reviews -ReasonCode 'unknown_contact_type' -SourceTable 'CustomerEpikoinonies' -SourceRecordKey $rowKey
        }
        [void]$contacts.Add([ordered]@{
                stage_key = "contact:$rowKey"
                patient_stage_key = $patientStageKey
                type = $targetType
                source_type = $typeCode
                raw_value = [string](Get-DwProperty -InputObject $row -Name 'epikoinonia' -Default '')
                normalized_value = ConvertTo-DwNormalizedText (Get-DwProperty -InputObject $row -Name 'epikoinonia' -Default '')
                sms_allowed_raw = Get-DwProperty -InputObject $row -Name 'sms_contact'
                notes = [string](Get-DwProperty -InputObject $row -Name 'memos' -Default '')
            })
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'CustomerEpikoinonies' -SourceRecordKey $rowKey -TargetEntityType 'patient_contact' -TargetStageKey "contact:$rowKey" -DatabaseFingerprint $databaseFingerprint
    }

    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'DentalSchoolIstoriko') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $numericId = [string](Get-DwProperty -InputObject $row -Name 'kodikospelati' -Default '')
        $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
        $patientStageKey = if ($patientsByGuid.ContainsKey($patientGuid)) {
            $patientsByGuid[$patientGuid]
        }
        elseif ($patientsById.ContainsKey($numericId)) {
            $patientsById[$numericId]
        }
        else {
            $null
        }
        if ($null -eq $patientStageKey) {
            Add-DwReview -Reviews $reviews -ReasonCode 'orphan_medical_history' -SourceTable 'DentalSchoolIstoriko' -SourceRecordKey $rowKey -Severity 'error'
        }
        [void]$histories.Add([ordered]@{
                stage_key = "medical-history:$rowKey"
                patient_stage_key = $patientStageKey
                source = 'DentalWin'
                review_status = 'legacy_unconfirmed'
                reason_for_visit = [string](Get-DwProperty -InputObject $row -Name 'aitiaproelesi' -Default '')
                present_condition = [string](Get-DwProperty -InputObject $row -Name 'parousakatastai' -Default '')
                medicines_text = [string](Get-DwProperty -InputObject $row -Name 'MEMOS36' -Default '')
                penicillin_raw = Get-DwProperty -InputObject $row -Name 'penikilinh'
                latex_raw = Get-DwProperty -InputObject $row -Name 'latex'
                hypertension_raw = Get-DwProperty -InputObject $row -Name 'ypertasi'
            })
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'DentalSchoolIstoriko' -SourceRecordKey $rowKey -TargetEntityType 'medical_history_revision' -TargetStageKey "medical-history:$rowKey" -DatabaseFingerprint $databaseFingerprint
    }

    $groupIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'Works_Kategories') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $id = [string](Get-DwProperty -InputObject $row -Name 'id' -Default $rowKey)
        [void]$groupIds.Add($id)
        [void]$groups.Add([ordered]@{
                stage_key = "therapy-group:$id"
                source_id = $id
                name = [string](Get-DwProperty -InputObject $row -Name 'kategory' -Default '')
                order = Get-DwProperty -InputObject $row -Name 'order_num'
                hidden = ((Get-DwProperty -InputObject $row -Name 'hidden_in_arxiki' -Default 0) -eq 1)
            })
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'Works_Kategories' -SourceRecordKey $rowKey -TargetEntityType 'therapy_group' -TargetStageKey "therapy-group:$id" -DatabaseFingerprint $databaseFingerprint
    }

    $catalogCodes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $catalogNameCounts = @{}
    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'WooksTools') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $code = [string](Get-DwProperty -InputObject $row -Name 'id_code' -Default '')
        $name = [string](Get-DwProperty -InputObject $row -Name 'frst' -Default '')
        $groupId = [string](Get-DwProperty -InputObject $row -Name 'katigoria' -Default '')
        if (-not [string]::IsNullOrWhiteSpace($code)) { [void]$catalogCodes.Add($code) }
        $normalizedName = ConvertTo-DwNormalizedText $name
        if (-not [string]::IsNullOrWhiteSpace($normalizedName)) {
            if (-not $catalogNameCounts.ContainsKey($normalizedName)) { $catalogNameCounts[$normalizedName] = 0 }
            $catalogNameCounts[$normalizedName]++
        }
        if (-not $groupIds.Contains($groupId)) {
            Add-DwReview -Reviews $reviews -ReasonCode 'uncategorized_catalog_work' -SourceTable 'WooksTools' -SourceRecordKey $rowKey
        }
        [void]$catalog.Add([ordered]@{
                stage_key = "procedure:$rowKey"
                source_code = $code
                name = $name
                therapy_group_source_id = $groupId
                base_price = Get-DwProperty -InputObject $row -Name 'euro'
                tooth_required_raw = Get-DwProperty -InputObject $row -Name 'donti_required'
                duration_minutes_raw = Get-DwProperty -InputObject $row -Name 'xronos'
                per_tooth_price_raw = Get-DwProperty -InputObject $row -Name 'timi_ana_donti'
            })
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'WooksTools' -SourceRecordKey $rowKey -TargetEntityType 'procedure_catalog' -TargetStageKey "procedure:$rowKey" -DatabaseFingerprint $databaseFingerprint
    }

    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'WorksPelati') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $numericId = [string](Get-DwProperty -InputObject $row -Name 'kodikosPelati' -Default '')
        $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
        $patientStageKey = if ($patientsByGuid.ContainsKey($patientGuid)) {
            $patientsByGuid[$patientGuid]
        }
        elseif ($patientsById.ContainsKey($numericId)) {
            $patientsById[$numericId]
        }
        else {
            $null
        }
        if ($null -eq $patientStageKey) {
            Add-DwReview -Reviews $reviews -ReasonCode 'orphan_clinical_work' -SourceTable 'WorksPelati' -SourceRecordKey $rowKey -Severity 'error'
        }

        $workCode = [string](Get-DwProperty -InputObject $row -Name 'id_code_work' -Default '')
        $workName = [string](Get-DwProperty -InputObject $row -Name 'ergasia' -Default '')
        $normalizedName = ConvertTo-DwNormalizedText $workName
        $catalogMethod = 'legacy_custom'
        if (-not [string]::IsNullOrWhiteSpace($workCode) -and $catalogCodes.Contains($workCode)) {
            $catalogMethod = 'stable_code'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($normalizedName) -and
            $catalogNameCounts.ContainsKey($normalizedName) -and
            $catalogNameCounts[$normalizedName] -eq 1) {
            $catalogMethod = 'unique_exact_name'
        }
        else {
            Add-DwReview -Reviews $reviews -ReasonCode 'unmatched_catalog_work' -SourceTable 'WorksPelati' -SourceRecordKey $rowKey -Severity 'info'
        }

        $rawTooth = [string](Get-DwProperty -InputObject $row -Name 'donti' -Default '')
        $parsedTooth = $null
        if ($rawTooth -match '^(1[1-8]|2[1-8]|3[1-8]|4[1-8]|5[1-5]|6[1-5]|7[1-5]|8[1-5])$') {
            $parsedTooth = $rawTooth
        }
        elseif (-not [string]::IsNullOrWhiteSpace($rawTooth) -and $rawTooth -ne '00') {
            Add-DwReview -Reviews $reviews -ReasonCode 'ambiguous_or_invalid_tooth' -SourceTable 'WorksPelati' -SourceRecordKey $rowKey
        }

        $isPlan = (Get-DwProperty -InputObject $row -Name 'SxedioUerapias' -Default 0) -eq 1
        [void]$clinicalEvents.Add([ordered]@{
                stage_key = "clinical-work:$rowKey"
                patient_stage_key = $patientStageKey
                original_work_name = $workName
                source_catalog_code = $workCode
                catalog_link_method = $catalogMethod
                event_kind = if ($isPlan) { 'treatment_plan_item' } else { 'clinical_event' }
                date_raw = Get-DwProperty -InputObject $row -Name 'hmerominia'
                tooth_raw = $rawTooth
                tooth_fdi = $parsedTooth
                notes = [string](Get-DwProperty -InputObject $row -Name 'memos' -Default '')
                status_raw = Get-DwProperty -InputObject $row -Name 'status'
                charge_raw = Get-DwProperty -InputObject $row -Name 'xreosi'
                credit_raw = Get-DwProperty -InputObject $row -Name 'pistosi'
                total_raw = Get-DwProperty -InputObject $row -Name 'sinolo'
            })
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'WorksPelati' -SourceRecordKey $rowKey -TargetEntityType $(if ($isPlan) { 'treatment_plan_item' } else { 'clinical_event' }) -TargetStageKey "clinical-work:$rowKey" -DatabaseFingerprint $databaseFingerprint
    }

    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'Appointments2') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
        $subject = [string](Get-DwProperty -InputObject $row -Name 'Subject' -Default '')
        $normalizedSubject = ConvertTo-DwNormalizedText $subject
        $patientStageKey = $null
        $patientLinkMethod = 'unresolved'
        if (-not [string]::IsNullOrWhiteSpace($patientGuid) -and $patientsByGuid.ContainsKey($patientGuid)) {
            $patientStageKey = $patientsByGuid[$patientGuid]
            $patientLinkMethod = 'patient_guid'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($normalizedSubject) -and
            $patientNameCounts.ContainsKey($normalizedSubject) -and
            $patientNameCounts[$normalizedSubject] -eq 1) {
            $patientLinkMethod = 'name_candidate_review'
            Add-DwReview -Reviews $reviews -ReasonCode 'appointment_name_match_candidate' -SourceTable 'Appointments2' -SourceRecordKey $rowKey
        }
        else {
            Add-DwReview -Reviews $reviews -ReasonCode 'appointment_patient_missing' -SourceTable 'Appointments2' -SourceRecordKey $rowKey -Severity 'error'
        }
        [void]$appointments.Add([ordered]@{
                stage_key = "appointment:$rowKey"
                patient_stage_key = $patientStageKey
                patient_link_method = $patientLinkMethod
                original_title = $subject
                description = [string](Get-DwProperty -InputObject $row -Name 'Description' -Default '')
                start_raw = Get-DwProperty -InputObject $row -Name 'StartTime'
                end_raw = Get-DwProperty -InputObject $row -Name 'EndTime'
                status_raw = Get-DwProperty -InputObject $row -Name 'Status'
                label_raw = Get-DwProperty -InputObject $row -Name 'Label'
                google_external_id = [string](Get-DwProperty -InputObject $row -Name 'guidss_google' -Default '')
            })
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'Appointments2' -SourceRecordKey $rowKey -TargetEntityType 'appointment' -TargetStageKey "appointment:$rowKey" -DatabaseFingerprint $databaseFingerprint
    }

    foreach ($table in @('CustomerImages', 'Aktinografies2')) {
        $index = 0
        foreach ($row in Get-DwRows -Fixture $fixture -Table $table) {
            $index++
            $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
            $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
            $patientStageKey = if ($patientsByGuid.ContainsKey($patientGuid)) { $patientsByGuid[$patientGuid] } else { $null }
            if ($null -eq $patientStageKey) {
                Add-DwReview -Reviews $reviews -ReasonCode 'document_patient_missing' -SourceTable $table -SourceRecordKey $rowKey -Severity 'error'
            }
            [void]$documents.Add([ordered]@{
                    stage_key = "document:${table}:$rowKey"
                    patient_stage_key = $patientStageKey
                    source_kind = $table
                    title = [string](Get-DwProperty -InputObject $row -Name 'title' -Default '')
                    description = [string](Get-DwProperty -InputObject $row -Name 'descr' -Default '')
                    file_path_raw = [string](Get-DwProperty -InputObject $row -Name 'file_path' -Default '')
                    thumb_path_raw = [string](Get-DwProperty -InputObject $row -Name 'thumb_path' -Default '')
                    xray_kind_raw = Get-DwProperty -InputObject $row -Name 'xray_kind'
                    has_embedded_image = ($null -ne (Get-DwProperty -InputObject $row -Name 'eikona'))
                })
            Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable $table -SourceRecordKey $rowKey -TargetEntityType 'patient_document' -TargetStageKey "document:${table}:$rowKey" -DatabaseFingerprint $databaseFingerprint
        }
    }

    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'CustomerMemos') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
        $patientStageKey = if ($patientsByGuid.ContainsKey($patientGuid)) { $patientsByGuid[$patientGuid] } else { $null }
        [void]$notes.Add([ordered]@{
                stage_key = "patient-note:$rowKey"
                patient_stage_key = $patientStageKey
                date_raw = Get-DwProperty -InputObject $row -Name 'imerominia'
                note = [string](Get-DwProperty -InputObject $row -Name 'memos' -Default '')
                type_raw = Get-DwProperty -InputObject $row -Name 'eidos'
                rtf_raw = Get-DwProperty -InputObject $row -Name 'is_rtf_format'
            })
        if ($null -eq $patientStageKey) { Add-DwReview -Reviews $reviews -ReasonCode 'patient_note_missing_patient' -SourceTable 'CustomerMemos' -SourceRecordKey $rowKey -Severity 'error' }
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'CustomerMemos' -SourceRecordKey $rowKey -TargetEntityType 'patient_note' -TargetStageKey "patient-note:$rowKey" -DatabaseFingerprint $databaseFingerprint
    }

    $index = 0
    foreach ($row in Get-DwRows -Fixture $fixture -Table 'RECALLS') {
        $index++
        $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
        $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
        $patientStageKey = if ($patientsByGuid.ContainsKey($patientGuid)) { $patientsByGuid[$patientGuid] } else { $null }
        [void]$recalls.Add([ordered]@{
                stage_key = "recall:$rowKey"
                patient_stage_key = $patientStageKey
                completion_date_raw = Get-DwProperty -InputObject $row -Name 'dCompletion_Date'
                notes = [string](Get-DwProperty -InputObject $row -Name 'cNotes' -Default '')
                status_raw = Get-DwProperty -InputObject $row -Name 'katastasi'
                sms_raw = Get-DwProperty -InputObject $row -Name 'sms'
            })
        if ($null -eq $patientStageKey) { Add-DwReview -Reviews $reviews -ReasonCode 'recall_missing_patient' -SourceTable 'RECALLS' -SourceRecordKey $rowKey -Severity 'error' }
        Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable 'RECALLS' -SourceRecordKey $rowKey -TargetEntityType 'recall' -TargetStageKey "recall:$rowKey" -DatabaseFingerprint $databaseFingerprint
    }

    foreach ($table in @('kinisi', 'WorkPliromes')) {
        $index = 0
        foreach ($row in Get-DwRows -Fixture $fixture -Table $table) {
            $index++
            $rowKey = Get-DwRowKey -Row $row -FallbackIndex $index
            $patientStageKey = $null
            if ($table -eq 'kinisi') {
                $numericId = [string](Get-DwProperty -InputObject $row -Name 'ID2' -Default '')
                if ($patientsById.ContainsKey($numericId)) { $patientStageKey = $patientsById[$numericId] }
            }
            else {
                $patientGuid = [string](Get-DwProperty -InputObject $row -Name 'guidsspelati' -Default '')
                if ($patientsByGuid.ContainsKey($patientGuid)) { $patientStageKey = $patientsByGuid[$patientGuid] }
            }
            if ($null -eq $patientStageKey) {
                Add-DwReview -Reviews $reviews -ReasonCode 'financial_patient_missing' -SourceTable $table -SourceRecordKey $rowKey -Severity 'error'
            }
            Add-DwReview -Reviews $reviews -ReasonCode 'financial_semantics_unverified' -SourceTable $table -SourceRecordKey $rowKey -Severity 'info'
            [void]$finance.Add([ordered]@{
                    stage_key = "finance:${table}:$rowKey"
                    patient_stage_key = $patientStageKey
                    source_kind = $table
                    amount_raw = if ($table -eq 'WorkPliromes') { Get-DwProperty -InputObject $row -Name 'pay_amount' } else { Get-DwProperty -InputObject $row -Name 'xreosi' }
                    date_raw = if ($table -eq 'WorkPliromes') { Get-DwProperty -InputObject $row -Name 'pay_date' } else { Get-DwProperty -InputObject $row -Name 'Date_In' }
                    pay_way_raw = Get-DwProperty -InputObject $row -Name 'pay_way'
                })
            Add-DwExternalIdentifier -List $externalIdentifiers -Keys $externalKeys -Reviews $reviews -SourceTable $table -SourceRecordKey $rowKey -TargetEntityType 'ledger_candidate' -TargetStageKey "finance:${table}:$rowKey" -DatabaseFingerprint $databaseFingerprint
        }
    }

    $tableProperties = @((Get-DwProperty -InputObject $fixture -Name 'tables').PSObject.Properties)
    $sourceCounts = [ordered]@{}
    foreach ($property in $tableProperties | Sort-Object Name) {
        $rows = @($property.Value)
        $sourceCounts[$property.Name] = $rows.Count
        $safeTable = ConvertTo-DwSafeFileName $property.Name
        Write-DwProtectedJsonLines -Path (Join-Path $output "protected/raw/$safeTable.jsonl.enc.json") -Rows $rows -Passphrase $Passphrase
    }

    $normalized = [ordered]@{
        patients = @($patients)
        patient_contacts = @($contacts)
        medical_history_revisions = @($histories)
        therapy_groups = @($groups)
        procedure_catalog = @($catalog)
        clinical_events_and_plan_items = @($clinicalEvents)
        appointments = @($appointments)
        patient_documents = @($documents)
        patient_notes = @($notes)
        recalls = @($recalls)
        ledger_candidates = @($finance)
        external_identifiers = @($externalIdentifiers)
        review_items = @($reviews)
    }
    foreach ($entry in $normalized.GetEnumerator()) {
        Write-DwProtectedJsonLines -Path (Join-Path $output "protected/normalized/$($entry.Key).jsonl.enc.json") -Rows @($entry.Value) -Passphrase $Passphrase
    }

    $reviewCounts = [ordered]@{}
    foreach ($group in @($reviews | Group-Object { [string]$_['reason_code'] } | Sort-Object Name)) {
        $reviewCounts[$group.Name] = $group.Count
    }
    $stagedCounts = [ordered]@{}
    foreach ($entry in $normalized.GetEnumerator()) {
        $stagedCounts[$entry.Key] = @($entry.Value).Count
    }

    $batchPrefix = if ($isPrivateRun) { 'private' } else { 'synthetic' }
    $batchId = "$batchPrefix-$($beforeHash.Substring(0, 16))-$($script:DwMappingVersion)"
    if (-not $isPrivateRun) {
        $afterHash = Get-DwFixtureFingerprint -FixturePath $fixtureFull
        if ($beforeHash -ne $afterHash) {
            throw 'Synthetic fixture changed during the dry run.'
        }
    }

    $report = [ordered]@{
        format_version = $script:DwStageFormatVersion
        mapping_version = $script:DwMappingVersion
        mode = if ($isPrivateRun) { $RunMode } else { 'synthetic_dry_run' }
        batch_id = $batchId
        source_fingerprint = $beforeHash
        source_hash_unchanged = $true
        source_counts = $sourceCounts
        staged_counts = $stagedCounts
        review_reason_counts = $reviewCounts
        duplicate_external_keys = @($reviews | Where-Object { $_['reason_code'] -eq 'duplicate_source_key' }).Count
        contains_real_patient_data = $isPrivateRun
        writes_to_apexo = $false
    }
    Write-DwJsonFile -Path (Join-Path $output 'reports/summary.json') -Value $report

    $markdown = [System.Collections.Generic.List[string]]::new()
    $markdown.Add($(if ($isPrivateRun) { '# Private DentalWin Dry-Run Report' } else { '# Synthetic DentalWin Dry-Run Report' }))
    $markdown.Add('')
    $markdown.Add("- Batch: $batchId")
    $markdown.Add("- Mapping version: $($script:DwMappingVersion)")
    $markdown.Add("- Contains real patient data: $($isPrivateRun.ToString().ToLowerInvariant())")
    $markdown.Add('- Writes to Apexo: false')
    $markdown.Add('- Source hash unchanged: true')
    $markdown.Add('')
    $markdown.Add('## Staged records')
    $markdown.Add('')
    $markdown.Add('| Entity | Rows |')
    $markdown.Add('|---|---:|')
    foreach ($entry in $stagedCounts.GetEnumerator()) {
        $markdown.Add("| $($entry.Key) | $($entry.Value) |")
    }
    $markdown.Add('')
    $markdown.Add('## Review reasons')
    $markdown.Add('')
    $markdown.Add('| Reason | Rows |')
    $markdown.Add('|---|---:|')
    foreach ($entry in $reviewCounts.GetEnumerator()) {
        $markdown.Add("| $($entry.Key) | $($entry.Value) |")
    }
    Write-DwUtf8Text -Path (Join-Path $output 'reports/summary.md') -Text (($markdown -join [Environment]::NewLine) + [Environment]::NewLine)

    $manifest = [ordered]@{
        format_version = $script:DwStageFormatVersion
        mapping_version = $script:DwMappingVersion
        mode = if ($isPrivateRun) { $RunMode } else { 'synthetic_dry_run' }
        batch_id = $batchId
        created_utc = [DateTime]::UtcNow.ToString('o')
        protection = [ordered]@{
            protected_files = 'PBKDF2-HMAC-SHA256 + AES-256-CBC + HMAC-SHA256'
            passphrase_source = if ($isPrivateRun) { 'separate restricted key file; never stored in staging' } else { 'caller supplied; never stored in staging' }
            ordinary_reports_contain = 'counts and reason codes only'
        }
        source_hash_unchanged = $true
        complete = ($report.duplicate_external_keys -eq 0)
    }
    Write-DwJsonFile -Path (Join-Path $output 'manifest.json') -Value $manifest
    Write-DwChecksums -Root $output

    return [pscustomobject]@{
        Mode = if ($isPrivateRun) { 'PrivateDryRun' } else { 'SyntheticDryRun' }
        OutputDirectory = $output
        BatchId = $batchId
        SourceHashUnchanged = $true
        DuplicateExternalKeys = $report.duplicate_external_keys
        ReviewItemCount = $reviews.Count
        Complete = ($report.duplicate_external_keys -eq 0)
    }
}

function Invoke-DwPrivateDryRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$OutputDirectory,
        [Parameter(Mandatory = $true)][string]$KeyFile
    )

    $source = (Resolve-Path -LiteralPath $SourceDirectory).Path
    if (-not (Get-Item -LiteralPath $source).PSIsContainer) {
        throw 'SourceDirectory must be a folder.'
    }
    $keyFull = (Resolve-Path -LiteralPath $KeyFile).Path
    $sourcePrefix = $source.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($keyFull.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The private key file must not be stored inside the DentalWin source directory.'
    }
    $outputFull = [System.IO.Path]::GetFullPath($OutputDirectory)
    $outputPrefix = $outputFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($keyFull.Equals($outputFull, [System.StringComparison]::OrdinalIgnoreCase) -or
        $keyFull.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The private key file must be separate from the staging run directory.'
    }

    $provider = Get-DwAccessProvider
    $databases = @(Get-ChildItem -LiteralPath $source -Recurse -File -Filter '*.mdb' | Sort-Object FullName)
    if ($databases.Count -eq 0) {
        throw 'No .mdb databases were found in the source directory.'
    }

    $databaseRecords = [System.Collections.ArrayList]::new()
    $hashesBefore = @{}
    foreach ($database in $databases) {
        $record = Get-DwInventoryRecord -DatabasePath $database.FullName -SourceRoot $source -Provider $provider
        if ($null -ne $record.error -or -not $record.source_hash_unchanged) {
            throw 'A DentalWin database could not be verified for read-only extraction.'
        }
        $hashesBefore[$database.FullName] = $record.sha256
        [void]$databaseRecords.Add([pscustomobject]@{
                FullName = $database.FullName
                RelativePath = $record.relative_path
                Role = $record.role
                Sha256 = $record.sha256
                SizeBytes = $record.size_bytes
                UserTableCount = $record.user_table_count
            })
    }

    $tables = [ordered]@{}
    $extractedTables = [System.Collections.ArrayList]::new()
    $clinicalTables = @(
        'Customers', 'CustomerEpikoinonies', 'DentalSchoolIstoriko',
        'Works_Kategories', 'WooksTools', 'WorksToolsShowType',
        'WorksPelati', 'WorksPelatiD', 'WorksPelatiU', 'odontogrammata',
        'CustomerToothState', 'NeogilaDontiaPelati', 'CustomerImages',
        'Aktinografies2', 'CustomerMemos', 'RECALLS', 'kinisi', 'WorkPliromes'
    )
    $calendarTables = @(
        'Appointments2', 'Appointments2_Log', 'AppointmentCategories',
        'AppointmentsEtiketa', 'AppointmentsORA'
    )

    foreach ($database in $databaseRecords) {
        $selected = if ($database.Role -eq 'clinical') {
            $clinicalTables
        }
        elseif ($database.Role -eq 'calendar') {
            $calendarTables
        }
        else {
            @()
        }
        if ($null -eq $selected -or @($selected).Count -eq 0) {
            continue
        }

        $connection = $null
        try {
            $connection = Open-DwReadOnlyConnection -DatabasePath $database.FullName -Provider $provider
            $available = Get-DwUserTableNames -Connection $connection
            foreach ($table in $selected) {
                if (-not $available.Contains($table)) {
                    continue
                }
                if ($tables.Contains($table)) {
                    throw "The approved extraction table appears in more than one source role: $table"
                }
                $rows = @(Read-DwTableRows -Connection $connection -Table $table)
                $tables[$table] = $rows
                [void]$extractedTables.Add([ordered]@{
                        role = $database.Role
                        table = $table
                        rows = $rows.Count
                    })
            }
        }
        finally {
            if ($null -ne $connection) {
                $connection.Close()
                $connection.Dispose()
            }
        }
    }

    $sourceHashesUnchanged = $true
    foreach ($database in $databases) {
        if ((Get-DwFileHashHex -Path $database.FullName) -ne $hashesBefore[$database.FullName]) {
            $sourceHashesUnchanged = $false
        }
    }
    if (-not $sourceHashesUnchanged) {
        throw 'A DentalWin source database changed during extraction. No private staging was produced.'
    }

    $fixture = [pscustomobject]@{
        metadata = [pscustomobject]@{
            synthetic = $false
            source_system = 'DentalWin'
        }
        tables = [pscustomobject]$tables
    }
    $fingerprint = Get-DwCombinedFingerprint -Hashes @($databaseRecords | ForEach-Object Sha256)
    $passphrase = Get-DwPrivatePassphrase -KeyFile $keyFull
    try {
        $result = Invoke-DwSyntheticDryRun `
            -FixtureObject $fixture `
            -SourceFingerprint $fingerprint `
            -SourceDirectory $source `
            -OutputDirectory $outputFull `
            -Passphrase $passphrase `
            -RunMode private_dry_run `
            -SourceHashesUnchanged $sourceHashesUnchanged
    }
    finally {
        $passphrase = $null
    }

    foreach ($database in $databases) {
        if ((Get-DwFileHashHex -Path $database.FullName) -ne $hashesBefore[$database.FullName]) {
            throw 'A DentalWin source database changed before private verification completed.'
        }
    }

    $roleCounts = [ordered]@{}
    foreach ($group in @($databaseRecords | Group-Object Role | Sort-Object Name)) {
        $roleCounts[$group.Name] = $group.Count
    }
    $extractionReport = [ordered]@{
        mode = 'private_dry_run'
        contains_real_patient_data = $true
        database_count = $databaseRecords.Count
        database_role_counts = $roleCounts
        source_hashes_unchanged = $true
        extracted_tables = @($extractedTables)
        reference_database_policy = 'inventory-only until reference semantics are approved'
        binary_policy = 'hash and byte length staged; source bytes deferred to the controlled import phase'
        writes_to_apexo = $false
    }
    Write-DwJsonFile -Path (Join-Path $outputFull 'reports/extraction.json') -Value $extractionReport

    $manifestPath = Join-Path $outputFull 'manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest | Add-Member -NotePropertyName database_count -NotePropertyValue $databaseRecords.Count -Force
    $manifest | Add-Member -NotePropertyName source_hashes_unchanged -NotePropertyValue $true -Force
    $manifest | Add-Member -NotePropertyName key_stored_outside_staging -NotePropertyValue $true -Force
    Write-DwJsonFile -Path $manifestPath -Value $manifest
    Write-DwChecksums -Root $outputFull

    return [pscustomobject]@{
        Mode = 'PrivateDryRun'
        OutputDirectory = $result.OutputDirectory
        BatchId = $result.BatchId
        DatabaseCount = $databaseRecords.Count
        ExtractedTableCount = $extractedTables.Count
        SourceHashesUnchanged = $true
        DuplicateExternalKeys = $result.DuplicateExternalKeys
        ReviewItemCount = $result.ReviewItemCount
        WritesToApexo = $false
        Complete = $result.Complete
    }
}

Export-ModuleMember -Function @(
    'Get-DwFileHashHex',
    'Invoke-DwInventory',
    'Invoke-DwSyntheticDryRun',
    'Invoke-DwPrivateDryRun',
    'New-DwPrivateKeyFile',
    'Read-DwProtectedJsonLines'
)
