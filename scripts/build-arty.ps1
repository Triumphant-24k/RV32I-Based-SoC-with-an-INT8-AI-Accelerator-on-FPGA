param(
    [ValidateSet('integrated','cpu','uart','led')][string]$Demo = 'integrated',
    [string]$Vivado = 'vivado.bat',
    [string]$Part = 'xc7a100tcsg324-1',
    [string]$Distribution = 'Ubuntu-22.04'
)
$ErrorActionPreference = 'Stop'
$tool = Get-Command $Vivado -ErrorAction SilentlyContinue
if (!$tool) { throw 'Vivado not found. Use a Vivado command prompt or pass -Vivado with the full path to vivado.bat. No build was attempted.' }
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    if ($Demo -in @('integrated','cpu')) {
        & wsl.exe -d $Distribution -- python3 scripts/build_firmware.py
        if ($LASTEXITCODE -ne 0) { throw 'Firmware build/validation failed' }
    }
    $out = "build/vivado/arty_a7_100t/$Demo"
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $buildScript = Join-Path (Get-Location) 'boards/arty_a7_100t/build.tcl'
    Push-Location $out
    try {
        & $tool.Source -mode batch -source $buildScript -log vivado.log -journal vivado.jou -tclargs --demo $Demo --part $Part
        if ($LASTEXITCODE -ne 0) { throw "Vivado failed with exit code $LASTEXITCODE; inspect $out" }
    } finally { Pop-Location }
} finally { Pop-Location }
