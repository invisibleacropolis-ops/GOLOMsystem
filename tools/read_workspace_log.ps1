Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

$appdata = $env:APPDATA
$dir = Join-Path $appdata 'Godot\app_userdata\RPGBackendModules'
$file = Join-Path $dir 'workspace_errors.log'
if (Test-Path $file) {
  Write-Output "workspace_errors.log path: $file"
  Get-Content -Raw $file | Write-Output
} else {
  Write-Output "workspace_errors.log not found. Looked in: $file"
  if (Test-Path $dir) { Get-ChildItem -Force $dir | Format-Table -AutoSize | Out-String | Write-Output }
}

