Param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ArgsPassthrough
)

# Open the Windows editor using the configured Godot 4.4.1 exe, capturing logs.
if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path 'logs' ("editor_launch_win_" + $ts + ".log")
$latest = 'logs/editor_launch_win.log'

# Pre-create log to avoid Copy-Item errors on empty output.
New-Item -ItemType File -Path $log -Force | Out-Null

$cmd = Join-Path $PSScriptRoot 'godot4.ps1'
# Start a background mirroring job to copy user://event log into repo logs/
try {
  $userLog = Join-Path $env:APPDATA 'Godot\app_userdata\RPGBackendModules\event_feed.log'
  $destLog = 'logs/event_feed.log'
  if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }
  $scriptBlock = {
    param($src, $dst)
    while ($true) {
      try {
        if (Test-Path $src) { Copy-Item -Force $src $dst }
      } catch {}
      Start-Sleep -Seconds 2
    }
  }
  $mirrorJob = Start-Job -ScriptBlock $scriptBlock -ArgumentList $userLog, $destLog
} catch { $mirrorJob = $null }

# Pipe both stdout/stderr to Tee so the user sees live output and we persist it.
& $cmd -Mode win --path . --editor @ArgsPassthrough 2>&1 | Tee-Object -FilePath $log
$exitCode = $LASTEXITCODE
if (Test-Path $log) { Copy-Item -Force $log $latest }

# Summarize PASS/FAIL with basic crash detection
$crash = $false
if (Test-Path $log) {
  try { $crash = Select-String -Path $log -Pattern 'handle_crash' -Quiet } catch { $crash = $false }
}
$pass = ($exitCode -eq 0 -and -not $crash)

$summary = [ordered]@{
  mode = 'win'
  started_at = (Get-Date ([System.IO.File]::GetCreationTimeUtc($log)) -Format o)
  finished_at = (Get-Date -Format o)
  exit_code = $exitCode
  crash_detected = $crash
  log = $log
  latest = $latest
  pass = $pass
}
$summaryPath = 'logs/editor_launch_win_status.json'
$summaryTS = 'logs/editor_launch_win_status_' + $ts + '.json'
$summary | ConvertTo-Json -Depth 4 | Set-Content -Path $summaryPath -Encoding UTF8
Copy-Item -Force $summaryPath $summaryTS | Out-Null

# Cleanup mirror job
if ($mirrorJob) { try { Stop-Job $mirrorJob -Force -ErrorAction SilentlyContinue; Remove-Job $mirrorJob -Force -ErrorAction SilentlyContinue } catch {} }

if ($pass) { Write-Host "EDITOR RUN: PASS (exit=$exitCode) log=$log" -ForegroundColor Green }
else { Write-Host "EDITOR RUN: FAIL (exit=$exitCode, crash=$crash) log=$log" -ForegroundColor Red }
