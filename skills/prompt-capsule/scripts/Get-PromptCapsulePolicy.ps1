[CmdletBinding()]
param(
    [ValidateSet('Claude', 'Codex', 'All')]
    [string]$Provider = 'All',

    [string]$PolicyPath = (Join-Path $env:LOCALAPPDATA 'PromptCapsule\policy.json'),

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $PolicyPath -PathType Leaf) {
    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
}
else {
    $policy = [pscustomobject]@{
        schema_version = 1
        updated_utc = $null
        minimum_savings_percent = 10
        providers = [pscustomobject]@{
            Claude = [pscustomobject]@{ enabled = $false; reason = 'No successful live benchmark has been saved.' }
            Codex = [pscustomobject]@{ enabled = $false; reason = 'No successful live benchmark has been saved.' }
        }
    }
}

$result = if ($Provider -eq 'All') {
    $policy
}
else {
    $entry = $policy.providers.$Provider
    [pscustomobject]@{
        provider = $Provider
        enabled = [bool]$entry.enabled
        reason = [string]$entry.reason
        policy_path = $PolicyPath
        details = $entry
    }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    $result
}
