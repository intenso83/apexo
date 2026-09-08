[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$verifier = Join-Path (Split-Path -Parent $PSScriptRoot) 'Verify-Apexo.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $verifier,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "Verify-Apexo.ps1 could not be parsed: $($parseErrors[0].Message)"
}
$functionNames = @(
    'Resolve-ApexoManifestCandidate'
    'ConvertTo-ApexoManifestRelativePath'
)
foreach ($functionName in $functionNames) {
    $functionAst = $ast.Find({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
        }, $true)
    if ($null -eq $functionAst) {
        throw "$functionName was not found in Verify-Apexo.ps1."
    }
    . ([scriptblock]::Create($functionAst.Extent.Text))
}

$assertions = 0
function Assert-Equal([string]$Expected, [string]$Actual, [string]$Message) {
    $script:assertions++
    if ($Expected -cne $Actual) {
        throw "$Message`nExpected: $Expected`nActual:   $Actual"
    }
}

function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $script:assertions++
    try {
        & $Action
    } catch {
        return
    }
    throw $Message
}

$relative = 'App/Web/assets/packages/country_flags/res/si/vu.si'
$driveRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($PSScriptRoot))
$expectedAtDriveRoot = [IO.Path]::GetFullPath((Join-Path $driveRoot $relative))
$actualAtDriveRoot = Resolve-ApexoManifestCandidate `
    -Root $driveRoot -RelativePath $relative
Assert-Equal $expectedAtDriveRoot $actualAtDriveRoot `
    'A valid manifest path must be accepted when the bundle is at a drive root.'

$nestedRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedNested = [IO.Path]::GetFullPath((Join-Path $nestedRoot $relative))
$actualNested = Resolve-ApexoManifestCandidate `
    -Root $nestedRoot -RelativePath $relative
Assert-Equal $expectedNested $actualNested `
    'A valid manifest path must be accepted when the bundle is in a directory.'

$relativeAtDriveRoot = ConvertTo-ApexoManifestRelativePath `
    -Root $driveRoot -FullPath $actualAtDriveRoot
Assert-Equal $relative $relativeAtDriveRoot `
    'Drive-root files must retain the first character of their relative path.'
$relativeNested = ConvertTo-ApexoManifestRelativePath `
    -Root $nestedRoot -FullPath $actualNested
Assert-Equal $relative $relativeNested `
    'Nested bundle files must convert to canonical manifest paths.'

Assert-Throws {
    Resolve-ApexoManifestCandidate -Root $nestedRoot -RelativePath '../outside.txt'
} 'Parent traversal must be rejected.'
Assert-Throws {
    Resolve-ApexoManifestCandidate -Root $nestedRoot -RelativePath '/absolute.txt'
} 'Rooted paths must be rejected.'
Assert-Throws {
    Resolve-ApexoManifestCandidate -Root $nestedRoot -RelativePath 'C:/absolute.txt'
} 'Drive-qualified paths must be rejected.'
Assert-Throws {
    Resolve-ApexoManifestCandidate -Root $nestedRoot -RelativePath 'App//Web/index.html'
} 'Empty path segments must be rejected.'
Assert-Throws {
    Resolve-ApexoManifestCandidate -Root $nestedRoot -RelativePath 'App/Web/index.html:stream'
} 'Alternate data-stream paths must be rejected.'
Assert-Throws {
    ConvertTo-ApexoManifestRelativePath `
        -Root $nestedRoot -FullPath ($nestedRoot + '-sibling\file.txt')
} 'Sibling-prefix paths must be rejected during relative conversion.'

Write-Host "Portable verifier path tests passed: $assertions assertions."
