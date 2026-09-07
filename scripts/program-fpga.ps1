$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# Locate Vivado on Windows
$VivadoCmd = Get-Command vivado -ErrorAction SilentlyContinue
if ($VivadoCmd) {
    $VivadoExe = 'vivado'
} else {
    $Candidates = Get-ChildItem "C:\Xilinx\Vivado\*\bin\vivado.bat" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
    if ($Candidates -and ($Candidates.Count -gt 0)) {
        $VivadoExe = $Candidates[0].FullName
    } else {
        throw "Vivado not found in PATH or under C:\Xilinx\Vivado\*\bin\vivado.bat. Please run from a 'Vivado Command Prompt' or add Vivado's bin directory to your PATH."
    }
}

Write-Host ">>> Programming connected Arty A7 FPGA using: $VivadoExe" -ForegroundColor Cyan
& $VivadoExe -mode batch -source scripts/vivado_program.tcl
if ($LASTEXITCODE -ne 0) {
    throw "Vivado programming failed with exit code $LASTEXITCODE"
}

Write-Host "`n>>> SUCCESS: Arty A7 successfully programmed!" -ForegroundColor Green
