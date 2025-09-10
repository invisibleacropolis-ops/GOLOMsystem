Param(
  [switch]$Pipe
)

if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path 'logs' ("ascii_play_win_" + $ts + ".log")
$latest = 'logs/ascii_play_win.log'

# Resolve runner (PATH or local script)
$runner = 'godot4'
if (-not (Get-Command $runner -ErrorAction SilentlyContinue)) {
  $runner = Join-Path $PSScriptRoot 'godot4.ps1'
}

$argsList = @('--headless','--path','.', '--script', 'scripts/tools/ascii_console.gd')
if ($Pipe) { $argsList += @('--','--pipe') }

& $runner @argsList 2>&1 | Tee-Object -FilePath $log | Out-Null
Copy-Item -Force $log $latest
