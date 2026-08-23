[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CapsuleDirectory,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSha256 {
    param([string]$Value)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

$resolvedDirectory = (Resolve-Path -LiteralPath $CapsuleDirectory).Path
$manifestPath = Join-Path $resolvedDirectory 'capsule.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing capsule manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema_version -ne 1) {
    throw "Unsupported capsule schema version: $($manifest.schema_version)"
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.capsule_id)) {
    throw 'Manifest capsule_id is missing.'
}

$verified = [System.Collections.Generic.List[object]]::new()
foreach ($entry in @($manifest.integrity_entries)) {
    $relativePath = [string]$entry.path
    if ([System.IO.Path]::IsPathRooted($relativePath) -or $relativePath.Contains('..')) {
        throw "Unsafe relative path in manifest: $relativePath"
    }
    $filePath = Join-Path $resolvedDirectory $relativePath
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw "Missing capsule file: $relativePath"
    }
    $actual = Get-FileSha256 -Path $filePath
    $expected = ([string]$entry.sha256).ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "Hash mismatch for $relativePath. Expected $expected, got $actual."
    }
    $verified.Add([ordered]@{ path = $relativePath; sha256 = $actual })
}

$rootMaterial = (($verified | ForEach-Object { '{0}:{1}' -f $_.path, $_.sha256 }) -join "`n") + "`n"
$actualRoot = Get-StringSha256 -Value $rootMaterial
if ($actualRoot -ne ([string]$manifest.integrity_root_sha256).ToLowerInvariant()) {
    throw 'Capsule integrity root mismatch.'
}

Add-Type -AssemblyName System.Drawing
$visualTokenTotal = 0
foreach ($imageEntry in @($manifest.images)) {
    $imagePath = Join-Path $resolvedDirectory ([string]$imageEntry.path)
    $image = [System.Drawing.Image]::FromFile($imagePath)
    try {
        if ($image.Width -ne [int]$imageEntry.width -or $image.Height -ne [int]$imageEntry.height) {
            throw "Image dimensions do not match manifest: $($imageEntry.path)"
        }
        $tokens = [int]([Math]::Ceiling($image.Width / 28.0) * [Math]::Ceiling($image.Height / 28.0))
        if ($tokens -ne [int]$imageEntry.visual_tokens) {
            throw "Visual-token count does not match manifest: $($imageEntry.path)"
        }
        $visualTokenTotal += $tokens
    }
    finally {
        $image.Dispose()
    }
}
if ($visualTokenTotal -ne [int]$manifest.visual_tokens_total) {
    throw 'Total visual-token count does not match manifest.'
}

$result = [pscustomobject]@{
    valid = $true
    capsule_id = [string]$manifest.capsule_id
    directory = $resolvedDirectory
    files_verified = $verified.Count
    pages = @($manifest.images).Count
    visual_tokens = $visualTokenTotal
    integrity_root_sha256 = $actualRoot
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4
}
else {
    $result
}
