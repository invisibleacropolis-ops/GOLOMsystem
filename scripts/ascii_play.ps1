Param(
  [switch]$Pipe
)

# Resolve runner (PATH or local script)
$runner = 'godot4'
if (-not (Get-Command $runner -ErrorAction SilentlyContinue)) {
  $runner = Join-Path $PSScriptRoot 'godot4.ps1'
}

$argsList = @('--headless','--path','.', '--script', 'scripts/tools/ascii_console.gd')
if ($Pipe) { $argsList += @('--','--pipe') }

& $runner @argsList
