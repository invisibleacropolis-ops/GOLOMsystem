Param(
  [string]$Host = '127.0.0.1',
  [int]$Port = 3456
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path 'logs' ("ascii_client_" + $ts + ".log")
$latest = 'logs/ascii_client.log'

$client = [System.Net.Sockets.TcpClient]::new()
$client.NoDelay = $true
$client.Connect($Host, $Port)
$stream = $client.GetStream()
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true

"Connected to $Host:$Port" | Tee-Object -FilePath $log

$readJob = Start-Job -ScriptBlock {
  Param($r, $logPath)
  while ($true) {
    $line = $r.ReadLine()
    if ($null -ne $line) { $line | Tee-Object -FilePath $logPath -Append }
  }
} -ArgumentList $reader, $log

try {
  while ($true) {
    $inputLine = [Console]::In.ReadLine()
    if ($null -eq $inputLine) { break }
    # Echo to log
    (">> " + $inputLine) | Tee-Object -FilePath $log -Append | Out-Null
    $writer.WriteLine($inputLine)
  }
}
finally {
  Stop-Job $readJob -ErrorAction SilentlyContinue | Out-Null
  Remove-Job $readJob -ErrorAction SilentlyContinue | Out-Null
  $reader.Dispose(); $writer.Dispose(); $stream.Dispose(); $client.Dispose()
  Copy-Item -Force $log $latest
}
