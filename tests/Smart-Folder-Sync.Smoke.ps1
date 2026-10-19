$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('sync-test-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $root 'source'
$dest = Join-Path $root 'dest'
New-Item -ItemType Directory -Path $source,$dest -Force | Out-Null
try {
  'hello' | Set-Content -LiteralPath (Join-Path $source 'hello.txt')
  'orphan' | Set-Content -LiteralPath (Join-Path $dest 'orphan.txt')
  $scriptPath = Join-Path $PSScriptRoot '..\Smart-Folder-Sync.ps1'
  & $scriptPath -Source $source -Destination $dest -Mirror -WhatIf | Out-Null
  if (Test-Path -LiteralPath (Join-Path $dest 'hello.txt')) { throw 'WhatIf copied file.' }
  if (-not (Test-Path -LiteralPath (Join-Path $dest 'orphan.txt'))) { throw 'WhatIf removed file.' }
  & $scriptPath -Source $source -Destination $dest -Mirror | Out-Null
  if (-not (Test-Path -LiteralPath (Join-Path $dest 'hello.txt'))) { throw 'Copy failed.' }
  if (Test-Path -LiteralPath (Join-Path $dest 'orphan.txt')) { throw 'Quarantine failed.' }
  $quarantine = Join-Path $root '.dest-sync-quarantine'
  if (@(Get-ChildItem -LiteralPath $quarantine -Filter 'orphan.txt' -Recurse -File).Count -ne 1) { throw 'Quarantine file missing.' }
  $failed = $false
  try { & $scriptPath -Source $source -Destination (Join-Path $source 'nested') -ErrorAction Stop | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw 'Nested destination not rejected.' }
  $empty = Join-Path $root 'empty'
  New-Item -ItemType Directory -Path $empty | Out-Null
  $failed = $false
  try { & $scriptPath -Source $empty -Destination $dest -Mirror -ErrorAction Stop | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw 'Empty source mirror not rejected.' }
  Write-Host 'Smart Folder Sync test passed.'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
