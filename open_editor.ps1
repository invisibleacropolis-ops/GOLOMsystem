Param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

# Proxy to scripts/open_editor.ps1 so users can run from repo root.
& (Join-Path $PSScriptRoot 'scripts/open_editor.ps1') @Args

