$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'scripts/program-common.ps1')

Set-Location $ScriptDir
Test-ProgramBundle
Initialize-ProgramRuntime
Ensure-DefaultEnv

Write-Host "[program-deploy] bundle validated"
Write-Host "[program-deploy] backend binary: $Script:BackendBin"
Write-Host "[program-deploy] env file: $Script:EnvFile"
Write-Host "[program-deploy] runtime directory: $Script:RunDir"
