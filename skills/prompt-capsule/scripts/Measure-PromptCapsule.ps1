[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CapsuleDirectory,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$validation = & (Join-Path $scriptRoot 'Test-PromptCapsule.ps1') -CapsuleDirectory $CapsuleDirectory
$manifestPath = Join-Path $validation.directory 'capsule.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

$textTokens = [int]$manifest.estimated_text_tokens
$visualTokens = [int]$manifest.visual_tokens_total
$difference = $visualTokens - $textTokens
$differencePercent = if ($textTokens -gt 0) {
    [Math]::Round(($difference / [double]$textTokens) * 100, 2)
}
else {
    0
}

$recommendation = if ($visualTokens -le [Math]::Floor($textTokens * 0.8)) {
    'live-benchmark-candidate'
}
elseif (@($manifest.images).Count -gt 1) {
    'prefer-text-multipage-image-overhead'
}
else {
    'prefer-text-unless-visual-layout-helps'
}

$result = [pscustomobject]@{
    capsule_id = [string]$manifest.capsule_id
    source_utf8_bytes = [int]$manifest.source_utf8_bytes
    estimated_text_tokens = $textTokens
    exact_visual_tokens = $visualTokens
    image_minus_text_tokens = $difference
    image_minus_text_percent = $differencePercent
    pages = @($manifest.images).Count
    recommendation = $recommendation
    note = 'Text count is a bytes/4 estimate; only a live provider benchmark can enable image mode.'
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4
}
else {
    $result
}
