$ErrorActionPreference = 'Stop'

$Script:ProgramCommonDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:BundleRoot = Split-Path -Parent $Script:ProgramCommonDir
$Script:AppId = 'zenmind-voice-server'
$Script:ManifestFile = Join-Path $Script:BundleRoot 'manifest.json'
$Script:EnvExampleFile = Join-Path $Script:BundleRoot '.env.example'
$Script:EnvFile = Join-Path $Script:BundleRoot '.env'
$Script:BackendBin = Join-Path (Join-Path $Script:BundleRoot 'backend') 'voice-server.exe'
$Script:RunDir = Join-Path $Script:BundleRoot 'run'
$Script:PidFile = Join-Path $Script:RunDir 'zenmind-voice-server.pid'
$Script:LogFile = Join-Path $Script:RunDir 'zenmind-voice-server.log'
$Script:ErrorLogFile = Join-Path $Script:RunDir 'zenmind-voice-server.stderr.log'

function Fail-Program([string]$Message) {
  throw "[program] $Message"
}

function Test-ProgramBundle {
  foreach ($path in @($Script:ManifestFile, $Script:EnvExampleFile, $Script:BackendBin)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      Fail-Program "required file not found: $path"
    }
  }
}

function Ensure-DefaultEnv {
  if (-not (Test-Path -LiteralPath $Script:EnvFile -PathType Leaf)) {
    Copy-Item -LiteralPath $Script:EnvExampleFile -Destination $Script:EnvFile
  }
}

function Import-ProgramEnv {
  if (-not (Test-Path -LiteralPath $Script:EnvFile -PathType Leaf)) {
    Fail-Program 'missing .env (copy from .env.example first)'
  }
  foreach ($rawLine in Get-Content -LiteralPath $Script:EnvFile) {
    $line = $rawLine.Trim()
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
      continue
    }
    $index = $line.IndexOf('=')
    if ($index -lt 1) {
      continue
    }
    $name = $line.Substring(0, $index).Trim()
    $value = $line.Substring($index + 1)
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
  }
  if ([string]::IsNullOrWhiteSpace($env:SERVER_PORT)) {
    $env:SERVER_PORT = '11953'
  }
}

function Initialize-ProgramRuntime {
  New-Item -ItemType Directory -Force -Path $Script:RunDir | Out-Null
}

function Read-ProgramPid {
  if (-not (Test-Path -LiteralPath $Script:PidFile -PathType Leaf)) {
    return $null
  }
  $pidValue = (Get-Content -LiteralPath $Script:PidFile -Raw).Trim()
  if ($pidValue -match '^\d+$') {
    return [int]$pidValue
  }
  return $null
}

function Clear-StaleProgramPid {
  if (-not (Test-Path -LiteralPath $Script:PidFile -PathType Leaf)) {
    return
  }

  $pidValue = Read-ProgramPid
  if ($null -ne $pidValue) {
    try {
      $null = Get-Process -Id $pidValue -ErrorAction Stop
      Fail-Program "$Script:AppId is already running with pid $pidValue"
    } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
      Remove-Item -LiteralPath $Script:PidFile -Force -ErrorAction SilentlyContinue
      return
    }
  }

  Remove-Item -LiteralPath $Script:PidFile -Force -ErrorAction SilentlyContinue
}

function Start-ProgramBackend {
  param(
    [switch]$Daemon
  )

  if ($Daemon) {
    Clear-StaleProgramPid
    if (Test-Path -LiteralPath $Script:LogFile) {
      Clear-Content -LiteralPath $Script:LogFile
    } else {
      New-Item -ItemType File -Path $Script:LogFile -Force | Out-Null
    }
    if (Test-Path -LiteralPath $Script:ErrorLogFile) {
      Clear-Content -LiteralPath $Script:ErrorLogFile
    } else {
      New-Item -ItemType File -Path $Script:ErrorLogFile -Force | Out-Null
    }

    $proc = Start-Process -FilePath $Script:BackendBin -WorkingDirectory $Script:BundleRoot -WindowStyle Hidden -RedirectStandardOutput $Script:LogFile -RedirectStandardError $Script:ErrorLogFile -PassThru
    $proc.Id | Set-Content -LiteralPath $Script:PidFile
    Start-Sleep -Seconds 1
    if ($proc.HasExited) {
      Remove-Item -LiteralPath $Script:PidFile -Force -ErrorAction SilentlyContinue
      Fail-Program "backend failed to start; see $Script:LogFile and $Script:ErrorLogFile"
    }

    Write-Host "[program-start] started $Script:AppId in daemon mode (pid=$($proc.Id))"
    Write-Host "[program-start] web: http://127.0.0.1:$($env:SERVER_PORT)/"
    Write-Host "[program-start] log file: $Script:LogFile"
    Write-Host "[program-start] stderr file: $Script:ErrorLogFile"
    return
  }

  & $Script:BackendBin
}

function Stop-ProgramBackend {
  if (-not (Test-Path -LiteralPath $Script:PidFile -PathType Leaf)) {
    Write-Host "[program-stop] pid file not found: $Script:PidFile"
    return
  }

  $pidValue = Read-ProgramPid
  if ($null -eq $pidValue) {
    Fail-Program "pid file must contain a numeric pid: $Script:PidFile"
  }

  try {
    $proc = Get-Process -Id $pidValue -ErrorAction Stop
  } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
    Remove-Item -LiteralPath $Script:PidFile -Force -ErrorAction SilentlyContinue
    Write-Host "[program-stop] process $pidValue is not running; removed stale pid file"
    return
  }

  Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    try {
      $proc.Refresh()
      if ($proc.HasExited) {
        Remove-Item -LiteralPath $Script:PidFile -Force -ErrorAction SilentlyContinue
        Write-Host "[program-stop] stopped $Script:AppId (pid=$pidValue)"
        return
      }
    } catch {
      Remove-Item -LiteralPath $Script:PidFile -Force -ErrorAction SilentlyContinue
      Write-Host "[program-stop] stopped $Script:AppId (pid=$pidValue)"
      return
    }
  }

  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $Script:PidFile -Force -ErrorAction SilentlyContinue
  Write-Host "[program-stop] force stopped $Script:AppId (pid=$pidValue)"
}
