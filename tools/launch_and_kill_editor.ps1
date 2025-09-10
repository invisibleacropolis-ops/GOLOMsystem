Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Push-Location (Split-Path -LiteralPath $PSCommandPath -Parent)
try {
  Set-Location (Resolve-Path ..)

  $job = Start-Job -ScriptBlock { & $using:PWD\open_editor.ps1 } -Name 'OpenEditorJob'
  Start-Sleep -Seconds 12

  # Kill the running editor process
  Get-Process -Name 'Godot_v4.4.1-stable_win64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

  # Give the wrapper a moment to finalize logs
  Wait-Job -Name 'OpenEditorJob' -Timeout 10 | Out-Null
  Receive-Job -Name 'OpenEditorJob' | Out-Host

  # Print status JSON content if present
  $status = 'logs/editor_launch_win_status.json'
  if (Test-Path $status) { Get-Content -Raw $status | Write-Output }
  else { Write-Output '{"error":"editor_launch_win_status.json not found"}' }
}
finally {
  Pop-Location
}

