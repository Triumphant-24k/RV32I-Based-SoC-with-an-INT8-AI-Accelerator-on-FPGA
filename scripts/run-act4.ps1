$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$wslPath=(& wsl.exe -d Ubuntu-22.04 -- wslpath -a ($projectRoot-replace '\\','/')).Trim()
& wsl.exe -d Ubuntu-22.04 -- sh -lc "cd '$wslPath' && sh scripts/run-act4.sh"
exit $LASTEXITCODE
