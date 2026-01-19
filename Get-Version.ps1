param(
  [string] $Root = $PSScriptRoot,
  [ValidateSet("none","patch","minor","major")] [string] $Bump = "none",
  [switch] $Stamp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$verFile = Join-Path $Root "VERSION"
if (-not (Test-Path $verFile)) { "0.1.0" | Set-Content -Path $verFile -Encoding UTF8 }

$raw = (Get-Content $verFile -Raw).Trim()
if ($raw -notmatch '^(\d+)\.(\d+)\.(\d+)$') { throw "VERSION invalide: $raw (attendu X.Y.Z)" }

$maj = [int]$Matches[1]; $min = [int]$Matches[2]; $pat = [int]$Matches[3]

switch ($Bump) {
  "major" { $maj++; $min=0; $pat=0 }
  "minor" { $min++; $pat=0 }
  "patch" { $pat++ }
  default {}
}

$base = "$maj.$min.$pat"
if ($Bump -ne "none") { $base | Set-Content -Path $verFile -Encoding UTF8 }

if ($Stamp) {
  $stampStr = (Get-Date -Format "yyyyMMdd_HHmmss")
  "$base+$stampStr"
} else {
  $base
}
