Param(
  [switch]$Once,
  [int]$IntervalSeconds = 2
)

$src = Join-Path $env:APPDATA 'Godot\app_userdata\RPGBackendModules\event_feed.log'
$dst = 'logs/event_feed.log'
if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }

if ($Once) {
  if (Test-Path $src) { Copy-Item -Force $src $dst }
  exit 0
}

while ($true) {
  try { if (Test-Path $src) { Copy-Item -Force $src $dst } } catch {}
  Start-Sleep -Seconds $IntervalSeconds
}

