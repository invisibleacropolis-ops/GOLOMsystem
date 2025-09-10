<#
Launch the Windows editor via the repo root proxy `open_editor.ps1`,
wait ~10 seconds, then terminate the Godot editor process and print
the status JSON path so the harness can read logs.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Push-Location (Split-Path -LiteralPath $PSCommandPath -Parent)
try {
  # Move to repo root (tools/ parent)
  Set-Location (Resolve-Path ..)

  # Choose a PowerShell host for the child wrapper
  $psHost = 'powershell.exe'
  if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { $psHost = 'pwsh.exe' }

  # Start the root proxy which logs to logs/editor_launch_win_*.log and status json
  $child = Start-Process -FilePath $psHost -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','open_editor.ps1') -PassThru

  Start-Sleep -Seconds 12

  # Kill the Godot editor if it is running
  $null = Get-Process -Name 'Godot_v4.4.1-stable_win64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

  # Wait briefly for the wrapper to finalize logs
  if ($child -and !$child.HasExited) {
    try { $child.WaitForExit(8000) | Out-Null } catch {}
  }

  # Echo what logs we expect
  $status = 'logs/editor_launch_win_status.json'
  if (Test-Path $status) { Get-Content -Raw $status | Write-Output }
  else { Write-Output '{"error":"editor_launch_win_status.json not found"}' }
}
finally {
  Pop-Location
}
