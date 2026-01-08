# TABARC-Code
param(
  [Parameter(Mandatory=$true)][string]$Source,
  [Parameter(Mandatory=$true)][string]$Destination,
  [switch]$Mirror,
  [string]$HashAlgorithm = "SHA256"
)

$Source = (Resolve-Path -LiteralPath $Source).Path
if (-not (Test-Path -LiteralPath $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }
$Destination = (Resolve-Path -LiteralPath $Destination).Path

function RelPath([string]$root,[string]$full) {
  $r = $root.TrimEnd('\') + '\'
  if ($full.StartsWith($r,[StringComparison]::OrdinalIgnoreCase)) { $full.Substring($r.Length) } else { $full }
}

$srcFiles = Get-ChildItem -LiteralPath $Source -Recurse -File -Force
$dstIndex = Get-ChildItem -LiteralPath $Destination -Recurse -File -Force | ForEach-Object {
  [pscustomobject]@{ Rel = (RelPath $Destination $_.FullName); Full = $_.FullName; Len = $_.Length }
} | Group-Object Rel -AsHashTable -AsString

foreach ($f in $srcFiles) {
  $rel = RelPath $Source $f.FullName
  $dstPath = Join-Path $Destination $rel
  $dstDir = Split-Path -Parent $dstPath
  if (-not (Test-Path -LiteralPath $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }

  $copy = $true
  if ($dstIndex.ContainsKey($rel)) {
    $d = $dstIndex[$rel][0]
    if ($d.Len -eq $f.Length) {
      $h1 = (Get-FileHash -LiteralPath $f.FullName -Algorithm $HashAlgorithm).Hash
      $h2 = (Get-FileHash -LiteralPath $d.Full -Algorithm $HashAlgorithm).Hash
      if ($h1 -eq $h2) { $copy = $false }
    }
  }

  if ($copy) {
    Write-Host "Copying $rel"
    Copy-Item -LiteralPath $f.FullName -Destination $dstPath -Force
  }
}

if ($Mirror) {
  $srcSet = @{}
  foreach ($f in $srcFiles) { $srcSet[(RelPath $Source $f.FullName)] = $true }

  Get-ChildItem -LiteralPath $Destination -Recurse -File -Force | ForEach-Object {
    $rel = RelPath $Destination $_.FullName
    if (-not $srcSet.ContainsKey($rel)) {
      Write-Host "Removing $rel"
      Remove-Item -LiteralPath $_.FullName -Force
    }
  }
}

Write-Host "Done."
