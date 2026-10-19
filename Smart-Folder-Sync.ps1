# TABARC-Code
# One-way file synchronisation. Mirror extras are quarantined unless -DeleteExtra is chosen.
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$true)][string]$Source,
  [Parameter(Mandatory=$true)][string]$Destination,
  [switch]$Mirror,
  [switch]$DeleteExtra,
  [switch]$AllowEmptySource,
  [string]$QuarantineDir,
  [ValidateSet('SHA256','SHA384','SHA512')][string]$HashAlgorithm = 'SHA256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($DeleteExtra -and -not $Mirror) { throw '-DeleteExtra requires -Mirror.' }
$srcRoot = (Resolve-Path -LiteralPath $Source -ErrorAction Stop).ProviderPath
if (-not (Test-Path -LiteralPath $srcRoot -PathType Container)) { throw 'Source must be a directory.' }
$dstRoot = [IO.Path]::GetFullPath($Destination)
$srcRoot = [IO.Path]::GetFullPath($srcRoot)
$srcPrefix = $srcRoot.TrimEnd('\') + '\'
$dstPrefix = $dstRoot.TrimEnd('\') + '\'

if ([string]::Equals($srcRoot.TrimEnd('\'),$dstRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase) -or
    $srcRoot.StartsWith($dstPrefix,[StringComparison]::OrdinalIgnoreCase) -or
    $dstRoot.StartsWith($srcPrefix,[StringComparison]::OrdinalIgnoreCase)) {
  throw 'Source and destination must be separate, non-overlapping directory trees.'
}

if ($QuarantineDir) {
  $quarantineRoot = [IO.Path]::GetFullPath($QuarantineDir)
} else {
  $parent = Split-Path -Parent $dstRoot
  $quarantineRoot = Join-Path $parent ('.' + (Split-Path -Leaf $dstRoot) + '-sync-quarantine')
}
$quarantinePrefix = $quarantineRoot.TrimEnd('\') + '\'
if ($Mirror -and -not $DeleteExtra -and (
    [string]::Equals($quarantineRoot.TrimEnd('\'),$srcRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($quarantineRoot.TrimEnd('\'),$dstRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase) -or
    $quarantineRoot.StartsWith($srcPrefix,[StringComparison]::OrdinalIgnoreCase) -or
    $quarantineRoot.StartsWith($dstPrefix,[StringComparison]::OrdinalIgnoreCase) -or
    $srcRoot.StartsWith($quarantinePrefix,[StringComparison]::OrdinalIgnoreCase) -or
    $dstRoot.StartsWith($quarantinePrefix,[StringComparison]::OrdinalIgnoreCase)
  )) { throw 'Quarantine must be outside source and destination directory trees.' }

function Relative-Name([string]$root,[string]$full) {
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {
    throw "File outside sync root: $full"
  }
  return $full.Substring($prefix.Length)
}
function Regular-Files([string]$root) {
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }
  @(Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction Stop |
    Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
}

$sourceFiles = @(Regular-Files $srcRoot)
$sourceIndex = @{}
if ($Mirror -and $sourceFiles.Count -eq 0 -and -not $AllowEmptySource) {
  throw 'Source contains no regular files; use -AllowEmptySource to mirror an intentionally empty source.'
}

foreach ($file in $sourceFiles) {
  $rel = Relative-Name $srcRoot $file.FullName
  $sourceIndex[$rel] = $true
}

foreach ($file in $sourceFiles) {
  $rel = Relative-Name $srcRoot $file.FullName
  $target = Join-Path $dstRoot $rel
  $copy = $true
  if (Test-Path -LiteralPath $target -PathType Leaf) {
    $existing = Get-Item -LiteralPath $target -Force
    if ($existing.Length -eq $file.Length -and
        (Get-FileHash -LiteralPath $file.FullName -Algorithm $HashAlgorithm).Hash -eq
        (Get-FileHash -LiteralPath $target -Algorithm $HashAlgorithm).Hash) {
      $copy = $false
    }
  }
  if (-not $copy) { continue }
  if ($PSCmdlet.ShouldProcess($target,"Copy $rel")) {
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force -ErrorAction Stop
    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm $HashAlgorithm).Hash
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm $HashAlgorithm).Hash
    if ($sourceHash -ne $targetHash) { throw "Copy verification failed: $rel" }
    Write-Host "Copied: $rel"
  }
}

if ($Mirror) {
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fffffff'
  foreach ($file in @(Regular-Files $dstRoot)) {
    $rel = Relative-Name $dstRoot $file.FullName
    if ($sourceIndex.ContainsKey($rel)) { continue }
    if ($DeleteExtra) {
      if ($PSCmdlet.ShouldProcess($file.FullName,"Permanently remove extra file $rel")) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
        Write-Host "Deleted: $rel"
      }
    } else {
      $safeTarget = Join-Path (Join-Path $quarantineRoot $stamp) $rel
      if ($PSCmdlet.ShouldProcess($file.FullName,"Quarantine extra file to $safeTarget")) {
        $parent = Split-Path -Parent $safeTarget
        if (-not (Test-Path -LiteralPath $parent)) {
          New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Move-Item -LiteralPath $file.FullName -Destination $safeTarget -ErrorAction Stop
        Write-Host "Quarantined: $rel"
      }
    }
  }
}
Write-Host 'Sync complete.'
