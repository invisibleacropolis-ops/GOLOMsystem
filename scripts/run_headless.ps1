Param(
    [switch]$Strict
)

# Run headless module tests and a quick ASCII console smoke test.
# Requires `scripts` on PATH so `godot4` resolves to your WSL wrapper.

$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }

function Get-GodotWinExe {
  $cfgPath = Join-Path $PSScriptRoot 'godot4-config.json'
  if (Test-Path $cfgPath) {
    try { return (Get-Content $cfgPath -Raw | ConvertFrom-Json).win_exe } catch { }
  }
  if ($env:GODOT4_WIN_EXE) { return $env:GODOT4_WIN_EXE }
  return $null
}

$godotExe = Get-GodotWinExe
if (-not $godotExe) { $godotExe = 'godot4' }

Write-Host 'Running headless module tests...'
if ($godotExe -ieq 'godot4') {
  & $godotExe --headless --path . --script scripts/test_runner.gd 2>&1 | Tee-Object -FilePath 'logs/headless_tests.log'
  $testExit = $LASTEXITCODE
} else {
  $p = Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.', '--script','scripts/test_runner.gd' -NoNewWindow -PassThru -RedirectStandardOutput 'logs\headless_tests.log' -RedirectStandardError 'logs\headless_tests.err.log'
  $p.WaitForExit(); $testExit = $p.ExitCode
}

Write-Host "Tests finished with exit code $testExit. Log: logs/headless_tests.log"

Write-Host 'Running ASCII console smoke...'
$asciiCmds = @(
    'spawn A 0 0',
    'list',
    'select 0 0',
    'move 1 1',
    'target 1 0',
    'clear',
    'remove A',
    'end_turn',
    'quit'
) -join [Environment]::NewLine

Set-Content -Path 'logs/ascii_commands.txt' -Value ($asciiCmds + [Environment]::NewLine)
if ($godotExe -ieq 'godot4') {
  # Run console in piped mode so it exits on EOF.
  Get-Content 'logs/ascii_commands.txt' | & $godotExe --headless --path . --script scripts/tools/ascii_console.gd -- --pipe 2>&1 | Tee-Object -FilePath 'logs/ascii_smoke.log' | Out-Null
} else {
  # Pass --pipe and feed commands via redirected stdin; wait for exit.
  $p2 = Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.', '--script','scripts/tools/ascii_console.gd','--','--pipe' -NoNewWindow -PassThru -RedirectStandardInput 'logs\ascii_commands.txt' -RedirectStandardOutput 'logs\ascii_smoke.log' -RedirectStandardError 'logs\ascii_smoke.err.log'
  $p2.WaitForExit() | Out-Null
}

Write-Host 'ASCII smoke complete. Log: logs/ascii_smoke.log'

if ($Strict -and $testExit -ne 0) {
    Write-Error "Headless tests failed with exit code $testExit. See logs/headless_tests.log"
    exit $testExit
}

exit $testExit

