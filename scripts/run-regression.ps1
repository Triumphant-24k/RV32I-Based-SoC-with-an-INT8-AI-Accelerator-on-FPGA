param([string]$Distribution = 'Ubuntu-22.04')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & wsl.exe -d $Distribution -- python3 scripts/regress.py
    if ($LASTEXITCODE -ne 0) { throw "Regression failed with exit code $LASTEXITCODE" }
} finally { Pop-Location }
