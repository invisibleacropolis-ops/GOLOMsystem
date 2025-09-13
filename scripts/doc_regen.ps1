Param(
  [string]$DocsDir = 'docs/api',
  [string]$ScriptsRoot = 'res://scripts/modules',
  [switch]$BuildRst,
  [switch]$BuildHtml
)

# Regenerate GDScript API XMLs using Godot doctool, with optional RST/HTML conversion.
# Requires `godot4` wrapper on PATH.

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

Write-Host "[doctool] Generating XML docs into $DocsDir"
if ($godotExe -ieq 'godot4') {
  & $godotExe --headless --path . --doctool $DocsDir --gdscript-docs $ScriptsRoot 2>&1 | Tee-Object -FilePath 'logs/doctool.log'
  $code = $LASTEXITCODE
} else {
  $p = Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.', '--doctool', $DocsDir, '--gdscript-docs', $ScriptsRoot -NoNewWindow -PassThru -RedirectStandardOutput 'logs\doctool.log' -RedirectStandardError 'logs\doctool.err.log'
  $p.WaitForExit(); $code = $p.ExitCode
}
$exit = $LASTEXITCODE
if ($exit -ne 0) { Write-Error "Doctool failed with exit code $exit. See logs/doctool.log"; exit $exit }

if ($BuildRst) {
  Write-Host "[doctool] Converting XML -> RST (tools/make_rst.py)"
  if (-not (Test-Path 'docs/api_rst')) { New-Item -ItemType Directory -Path 'docs/api_rst' | Out-Null }
  $env:PYTHONPATH = (Resolve-Path '.').Path
  python3 tools/make_rst.py -o docs/api_rst $DocsDir 2>&1 | Tee-Object -FilePath 'logs/doctool_rst.log'
}

if ($BuildHtml) {
  Write-Host "[doctool] Converting RST -> HTML (tools/rst_to_html.py)"
  if (-not (Test-Path 'docs/html')) { New-Item -ItemType Directory -Path 'docs/html' | Out-Null }
  python3 tools/rst_to_html.py docs/api_rst docs/html 2>&1 | Tee-Object -FilePath 'logs/doctool_html.log'
}

Write-Host "[doctool] Complete. Primary log: logs/doctool.log"
exit 0
