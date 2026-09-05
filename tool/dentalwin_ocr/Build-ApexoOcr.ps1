[CmdletBinding()]
param(
    [string]$Python = 'python'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $toolRoot '..\..'))
$buildRoot = Join-Path $repositoryRoot 'build\dentalwin_ocr'
$virtualEnvironment = Join-Path $buildRoot '.venv'
$pythonExecutable = Join-Path $virtualEnvironment 'Scripts\python.exe'
$distRoot = Join-Path $buildRoot 'dist'
$workRoot = Join-Path $buildRoot 'work'
$specRoot = Join-Path $buildRoot 'spec'
$entryPoint = Join-Path $toolRoot 'ApexoOcrUtility.py'
$sourceRoot = Join-Path $toolRoot 'src'
$iconPath = Join-Path $repositoryRoot 'windows\runner\resources\app_icon.ico'
$noticesPath = Join-Path $toolRoot 'THIRD_PARTY_NOTICES.txt'
$versionPath = Join-Path $toolRoot 'version_info.txt'
$bridgePath = Join-Path $toolRoot 'resources\DentalWinCsvBridge.ps1'

[System.IO.Directory]::CreateDirectory($buildRoot) | Out-Null

if (-not (Test-Path -LiteralPath $pythonExecutable)) {
    & $Python -m venv $virtualEnvironment
}

& $pythonExecutable -m pip install --disable-pip-version-check --no-input `
    -r (Join-Path $toolRoot 'requirements-build.txt')

& $pythonExecutable -m unittest discover `
    -s (Join-Path $toolRoot 'tests') `
    -p 'test_*.py' `
    -v

& $pythonExecutable -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --console `
    --name 'ApexoPatientImportUtility' `
    --paths $sourceRoot `
    --icon $iconPath `
    --version-file $versionPath `
    --add-data "${noticesPath};." `
    --add-data "${bridgePath};resources" `
    --collect-all pypdfium2 `
    --hidden-import PIL._tkinter_finder `
    --distpath $distRoot `
    --workpath $workRoot `
    --specpath $specRoot `
    $entryPoint

Copy-Item -LiteralPath $noticesPath -Destination $distRoot -Force
Copy-Item -LiteralPath (Join-Path $toolRoot 'README.md') -Destination $distRoot -Force

$executable = Join-Path $distRoot 'ApexoPatientImportUtility.exe'
& $executable --self-test
& $executable --gui-smoke-test
Get-FileHash -LiteralPath $executable -Algorithm SHA256
