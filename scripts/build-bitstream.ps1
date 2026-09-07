param(
    [ValidateSet('35t', '100t')]
    [string]$Board = '35t'
)
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

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Vivado:        $VivadoExe" -ForegroundColor Cyan
Write-Host "  Target Board:  Arty A7-$Board" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$ConfigFile = "boards/arty_a7_$Board.tcl"
& $VivadoExe -mode batch -source scripts/vivado_build_bitstream.tcl -tclargs $ConfigFile
if ($LASTEXITCODE -ne 0) {
    throw "Vivado build failed with exit code $LASTEXITCODE"
}

Write-Host "`n>>> SUCCESS: Bitstream generated at: build\vivado\ai_soc.bit" -ForegroundColor Green
