<#
Cross-platform Godot 4 runner for headless/dev use.

Modes:
  - auto (default): prefer WSL Linux binary if available, else Windows exe.
  - wsl: force running the Linux binary under WSL.
  - win: force running the Windows .exe directly.

Configuration priority (highest first):
  1) CLI params: -WinExe, -WslExe, -Mode
  2) scripts/godot4-config.json { "win_exe": "...", "wsl_exe": "...", "mode": "auto|wsl|win" }
  3) Environment variables: GODOT4_WIN_EXE, GODOT4_LINUX_EXE, GODOT4_MODE
  4) Hardcoded fallback: none (error)
#>

[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AllArgs
)

# Parse known options from $AllArgs without letting PowerShell bind them positionally.
$Mode = $null; $WinExe = $null; $WslExe = $null; $ArgsPassthrough = @()
$argCount = 0; if ($AllArgs) { $argCount = $AllArgs.Length }
for ($i = 0; $i -lt $argCount; $i++) {
  $a = $AllArgs[$i]
  switch -Regex ($a) {
    '^(?:-Mode|--mode)$'   { if ($i+1 -lt $AllArgs.Length) { $Mode = $AllArgs[++$i] }; continue }
    '^(?:-WinExe|--win)$'  { if ($i+1 -lt $AllArgs.Length) { $WinExe = $AllArgs[++$i] }; continue }
    '^(?:-WslExe|--wsl)$'  { if ($i+1 -lt $AllArgs.Length) { $WslExe = $AllArgs[++$i] }; continue }
    default { $ArgsPassthrough += $a }
  }
}

function Read-JsonConfig {
  $cfgPath = Join-Path $PSScriptRoot 'godot4-config.json'
  if (Test-Path $cfgPath) {
    try { return Get-Content $cfgPath -Raw | ConvertFrom-Json } catch { }
  }
  return $null
}

# Load config (json + env)
$cfg = Read-JsonConfig
if (-not $Mode) { $Mode = $cfg.mode; if (-not $Mode) { $Mode = $env:GODOT4_MODE; } }
if (-not $WinExe) { $WinExe = $cfg.win_exe; if (-not $WinExe) { $WinExe = $env:GODOT4_WIN_EXE; } }
if (-not $WslExe) { $WslExe = $cfg.wsl_exe; if (-not $WslExe) { $WslExe = $env:GODOT4_LINUX_EXE; } }
if (-not $Mode) { $Mode = 'auto' }

function Test-WSLAvailable { return [bool](Get-Command wsl -ErrorAction SilentlyContinue) }
function Resolve-WslPath([string]$p) {
  if (-not (Test-WSLAvailable)) { return $null }
  if (-not $p) { return $null }
  # Accept already-WSL paths (starts with / or /mnt/)
  if ($p -match '^(?:/|/mnt/)') { return $p }
  $out = & wsl wslpath -a -- $p 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($out)) { return $null }
  return $out.Trim()
}

function Invoke-WSL([string]$exePath, [string[]]$args) {
  if (-not (Test-WSLAvailable)) { throw 'WSL is not available on this system.' }
  if (-not $exePath) { throw 'WSL executable path was not provided.' }
  $wslPath = Resolve-WslPath $exePath
  if (-not $wslPath) { throw "Could not resolve WSL path from: $exePath" }
  & wsl "$wslPath" @args
  exit $LASTEXITCODE
}

function Invoke-Win([string]$exePath, [string[]]$args) {
  if (-not $exePath) { throw 'Windows executable path was not provided.' }
  if (-not (Test-Path $exePath)) { throw "Windows Godot exe not found: $exePath" }
  & "$exePath" @args
  exit $LASTEXITCODE
}

try {
  switch ($Mode.ToLowerInvariant()) {
    'wsl' {
      Invoke-WSL -exePath $WslExe -args $ArgsPassthrough
    }
    'win' {
      Invoke-Win -exePath $WinExe -args $ArgsPassthrough
    }
    default {
      # auto
      if (Test-WSLAvailable -and $WslExe) {
        try { Invoke-WSL -exePath $WslExe -args $ArgsPassthrough } catch { $wslErr = $_ }
        if (-not $wslErr) { return }
        Write-Warning "WSL launch failed: $($wslErr.Exception.Message). Falling back to Windows exe if available."
      }
      if ($WinExe) { Invoke-Win -exePath $WinExe -args $ArgsPassthrough }
      throw 'No working Godot executable configured. Provide -WinExe or -WslExe, or set scripts/godot4-config.json or env vars.'
    }
  }
}
catch {
  Write-Error "[godot4.ps1] $_"
  exit 1
}
