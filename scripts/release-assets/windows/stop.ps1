[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'scripts/program-common.ps1')

Set-Location $ScriptDir
Test-ProgramBundle
Initialize-ProgramRuntime
if (Test-Path -LiteralPath $Script:EnvFile -PathType Leaf) {
  Import-ProgramEnv
}
Stop-ProgramBackend
