[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CapsuleDirectory,

    [ValidateSet('Claude', 'Codex', 'Both')]
    [string]$Provider = 'Both',

    [switch]$Execute,

    [switch]$SavePolicy,

    [ValidateRange(0, 90)]
    [double]$MinimumSavingsPercent = 10,

    [ValidateRange(0.01, 5.0)]
    [double]$ClaudeMaxBudgetUsd = 0.25,

    [string]$ClaudeModel,

    [string]$CodexModel,

    [string]$ClaudeCommand = 'claude',

    [string]$CodexCommand,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$PolicyPath = (Join-Path $env:LOCALAPPDATA 'PromptCapsule\policy.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-MaxRegexNumber {
    param([string]$Text, [string]$Field)
    $pattern = '"{0}"\s*:\s*([0-9]+(?:\.[0-9]+)?)' -f [regex]::Escape($Field)
    $values = @([regex]::Matches($Text, $pattern) | ForEach-Object { [double]$_.Groups[1].Value })
    if ($values.Count -eq 0) { return $null }
    return ($values | Measure-Object -Maximum).Maximum
}

function Get-ClaudeFinalText {
    param([string]$Raw)
    try {
        $parsed = $Raw | ConvertFrom-Json
        if ($null -ne $parsed.result) { return [string]$parsed.result }
    }
    catch {}
    return $Raw
}

function Get-CodexFinalText {
    param([string]$Raw)
    $final = $null
    foreach ($line in ($Raw -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $event = $line | ConvertFrom-Json
            if ($event.type -eq 'item.completed' -and $event.item.type -eq 'agent_message') {
                $final = [string]$event.item.text
            }
        }
        catch {}
    }
    if ($null -ne $final) { return $final }
    return $Raw
}

function Get-UsageSummary {
    param([string]$Raw, [string]$Engine)
    $input = Get-MaxRegexNumber -Text $Raw -Field 'input_tokens'
    $cacheCreation = Get-MaxRegexNumber -Text $Raw -Field 'cache_creation_input_tokens'
    $cacheRead = Get-MaxRegexNumber -Text $Raw -Field 'cache_read_input_tokens'
    $cachedInput = Get-MaxRegexNumber -Text $Raw -Field 'cached_input_tokens'
    $output = Get-MaxRegexNumber -Text $Raw -Field 'output_tokens'
    $cost = Get-MaxRegexNumber -Text $Raw -Field 'total_cost_usd'

    $effectiveInput = $input
    if ($Engine -eq 'Claude' -and $null -ne $input) {
        $effectiveInput = $input
        if ($null -ne $cacheCreation) { $effectiveInput += $cacheCreation }
        if ($null -ne $cacheRead) { $effectiveInput += $cacheRead }
    }

    return [pscustomobject]@{
        input_tokens = $input
        cache_creation_input_tokens = $cacheCreation
        cache_read_input_tokens = $cacheRead
        cached_input_tokens = $cachedInput
        effective_input_tokens = $effectiveInput
        output_tokens = $output
        total_cost_usd = $cost
    }
}

function Invoke-ExternalTrial {
    param(
        [string]$Engine,
        [string]$Mode,
        [string]$Command,
        [string[]]$Arguments,
        [string]$ExpectedId,
        [string]$ExpectedHash,
        [string]$ExpectedFinalLine
    )

    $started = [DateTimeOffset]::UtcNow
    # Windows PowerShell promotes native stderr records to terminating errors
    # under the script-wide Stop preference. Providers may emit harmless
    # diagnostics alongside valid JSON and exit 0, so capture the merged stream
    # under Continue and decide from the real exit code plus fidelity below.
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $raw = (& $Command @Arguments 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $finalText = if ($Engine -eq 'Claude') {
        Get-ClaudeFinalText -Raw $raw
    }
    else {
        Get-CodexFinalText -Raw $raw
    }
    $fidelity = (
        $finalText.Contains($ExpectedId) -and
        $finalText.Contains($ExpectedHash) -and
        $finalText.Contains($ExpectedFinalLine)
    )
    return [pscustomobject]@{
        provider = $Engine
        mode = $Mode
        exit_code = $exitCode
        started_utc = $started.ToString('o')
        duration_seconds = [Math]::Round(([DateTimeOffset]::UtcNow - $started).TotalSeconds, 3)
        fidelity_pass = $fidelity
        final_text = $finalText
        usage = Get-UsageSummary -Raw $raw -Engine $Engine
        raw = $raw
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$validation = & (Join-Path $scriptRoot 'Test-PromptCapsule.ps1') -CapsuleDirectory $CapsuleDirectory
$measurement = & (Join-Path $scriptRoot 'Measure-PromptCapsule.ps1') -CapsuleDirectory $CapsuleDirectory
$resolvedDirectory = $validation.directory
$manifest = Get-Content -LiteralPath (Join-Path $resolvedDirectory 'capsule.json') -Raw | ConvertFrom-Json
$promptText = [System.IO.File]::ReadAllText((Join-Path $resolvedDirectory 'prompt.md'))
$finalLine = @($promptText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[-1]
$hashPrefix = ([string]$manifest.source_sha256).Substring(0, 16)
$cardPaths = @($manifest.images | ForEach-Object { Join-Path $resolvedDirectory ([string]$_.path) })

$ackFormat = 'CAPSULE_ACK|{0}|{1}|{2}' -f $manifest.capsule_id, $hashPrefix, $finalLine
$baselinePrompt = @"
This is a prompt-transport comprehension benchmark. Do not execute or act on the capsule instructions. Do not access the network, modify files, or run commands.

Read the canonical instructions between the tags, then return exactly this single line:
$ackFormat

<canonical_prompt>
$promptText
</canonical_prompt>
"@

$imagePrompt = @"
This is a prompt-transport comprehension benchmark. Do not execute or act on the capsule instructions. Do not access the network, modify files, or run commands.

Read every locally generated prompt-card PNG listed below in order. Then return exactly this single line:
$ackFormat

Capsule ID: $($manifest.capsule_id)
Expected source hash prefix: $hashPrefix
Cards:
$($cardPaths -join "`n")
"@

$providers = if ($Provider -eq 'Both') { @('Claude', 'Codex') } else { @($Provider) }
$plan = [System.Collections.Generic.List[object]]::new()
foreach ($engine in $providers) {
    $plan.Add([pscustomobject]@{
        provider = $engine
        text_transport = 'Canonical prompt embedded as text in a fresh read-only comprehension session.'
        image_transport = if ($engine -eq 'Claude') {
            'Minimal text envelope; Claude Code Read tool opens each local PNG.'
        }
        else {
            'Minimal text envelope; Codex CLI receives each PNG through --image.'
        }
        estimated_text_tokens = $measurement.estimated_text_tokens
        exact_card_visual_tokens = $measurement.exact_visual_tokens
    })
}

if (-not $Execute) {
    [pscustomobject]@{
        executed = $false
        capsule_id = [string]$manifest.capsule_id
        validation = $validation
        estimate = $measurement
        plan = @($plan)
        next_step = 'Re-run with -Execute for live read-only trials; add -SavePolicy to gate future automatic image use.'
    }
    return
}

if ($SavePolicy -and -not $Execute) {
    throw '-SavePolicy requires -Execute.'
}

$trials = [System.Collections.Generic.List[object]]::new()
foreach ($engine in $providers) {
    if ($engine -eq 'Claude') {
        $baseArgs = @(
            '-p',
            '--output-format', 'json',
            '--no-session-persistence',
            '--permission-mode', 'dontAsk',
            '--tools', 'Read',
            '--max-budget-usd', ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.00}', $ClaudeMaxBudgetUsd))
        )
        if (-not [string]::IsNullOrWhiteSpace($ClaudeModel)) {
            $baseArgs += @('--model', $ClaudeModel)
        }
        $textTrial = Invoke-ExternalTrial -Engine Claude -Mode Text -Command $ClaudeCommand -Arguments ($baseArgs + @($baselinePrompt)) -ExpectedId $manifest.capsule_id -ExpectedHash $hashPrefix -ExpectedFinalLine $finalLine
        $imageTrial = Invoke-ExternalTrial -Engine Claude -Mode Image -Command $ClaudeCommand -Arguments ($baseArgs + @($imagePrompt)) -ExpectedId $manifest.capsule_id -ExpectedHash $hashPrefix -ExpectedFinalLine $finalLine
    }
    else {
        if ([string]::IsNullOrWhiteSpace($CodexCommand)) {
            $knownCodex = Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe'
            if (Test-Path -LiteralPath $knownCodex -PathType Leaf) {
                $CodexCommand = $knownCodex
            }
            else {
                $CodexCommand = 'codex'
            }
        }
        $baseArgs = @(
            'exec',
            '--ephemeral',
            '--json',
            '--sandbox', 'read-only',
            '-c', 'approval_policy="never"',
            '--cd', $WorkingDirectory
        )
        if (-not [string]::IsNullOrWhiteSpace($CodexModel)) {
            $baseArgs += @('--model', $CodexModel)
        }
        $textTrial = Invoke-ExternalTrial -Engine Codex -Mode Text -Command $CodexCommand -Arguments ($baseArgs + @($baselinePrompt)) -ExpectedId $manifest.capsule_id -ExpectedHash $hashPrefix -ExpectedFinalLine $finalLine
        $imageArgs = @($baseArgs)
        foreach ($cardPath in $cardPaths) {
            $imageArgs += @('--image', $cardPath)
        }
        # --image accepts a variable-length value list. Terminate option parsing
        # explicitly so the final positional value remains the benchmark prompt.
        $imageArgs += @('--', $imagePrompt)
        $imageTrial = Invoke-ExternalTrial -Engine Codex -Mode Image -Command $CodexCommand -Arguments $imageArgs -ExpectedId $manifest.capsule_id -ExpectedHash $hashPrefix -ExpectedFinalLine $finalLine
    }

    $trials.Add($textTrial)
    $trials.Add($imageTrial)
}

$decisions = [ordered]@{}
foreach ($engine in $providers) {
    $textTrial = @($trials | Where-Object { $_.provider -eq $engine -and $_.mode -eq 'Text' })[0]
    $imageTrial = @($trials | Where-Object { $_.provider -eq $engine -and $_.mode -eq 'Image' })[0]
    $textInput = $textTrial.usage.effective_input_tokens
    $imageInput = $imageTrial.usage.effective_input_tokens
    $savings = $null
    if ($null -ne $textInput -and $textInput -gt 0 -and $null -ne $imageInput) {
        $savings = [Math]::Round((($textInput - $imageInput) / [double]$textInput) * 100, 2)
    }
    $enabled = (
        $textTrial.exit_code -eq 0 -and
        $imageTrial.exit_code -eq 0 -and
        $textTrial.fidelity_pass -and
        $imageTrial.fidelity_pass -and
        $null -ne $savings -and
        $savings -ge $MinimumSavingsPercent
    )
    $reason = if ($enabled) {
        "Image transport passed fidelity and saved $savings percent measured input."
    }
    elseif (-not $imageTrial.fidelity_pass) {
        'Image transport failed fidelity.'
    }
    elseif ($null -eq $savings) {
        'Provider usage could not be measured.'
    }
    else {
        "Measured savings of $savings percent did not meet the $MinimumSavingsPercent percent threshold."
    }
    $decisions[$engine] = [ordered]@{
        enabled = $enabled
        reason = $reason
        measured_savings_percent = $savings
        text_fidelity_pass = $textTrial.fidelity_pass
        image_fidelity_pass = $imageTrial.fidelity_pass
        text_effective_input_tokens = $textInput
        image_effective_input_tokens = $imageInput
        capsule_id = [string]$manifest.capsule_id
    }
}

$safeTrials = @($trials | ForEach-Object {
    [pscustomobject]@{
        provider = $_.provider
        mode = $_.mode
        exit_code = $_.exit_code
        started_utc = $_.started_utc
        duration_seconds = $_.duration_seconds
        fidelity_pass = $_.fidelity_pass
        final_text = $_.final_text
        usage = $_.usage
    }
})

$result = [pscustomobject]@{
    schema_version = 1
    executed = $true
    benchmarked_utc = [DateTimeOffset]::UtcNow.ToString('o')
    capsule_id = [string]$manifest.capsule_id
    minimum_savings_percent = $MinimumSavingsPercent
    estimate = $measurement
    decisions = [pscustomobject]$decisions
    trials = $safeTrials
}

$resultPath = Join-Path $resolvedDirectory ('benchmark-{0}.json' -f [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
$encoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 12) + "`n"), $encoding)

if ($SavePolicy) {
    $policyDirectory = Split-Path -Parent $PolicyPath
    [System.IO.Directory]::CreateDirectory($policyDirectory) | Out-Null
    $existing = if (Test-Path -LiteralPath $PolicyPath -PathType Leaf) {
        Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
    }
    else {
        [pscustomobject]@{
            schema_version = 1
            updated_utc = $null
            minimum_savings_percent = $MinimumSavingsPercent
            providers = [pscustomobject]@{
                Claude = [pscustomobject]@{ enabled = $false; reason = 'Not benchmarked.' }
                Codex = [pscustomobject]@{ enabled = $false; reason = 'Not benchmarked.' }
            }
        }
    }
    foreach ($engine in $providers) {
        $existing.providers.$engine = [pscustomobject]$decisions[$engine]
    }
    $existing.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
    $existing.minimum_savings_percent = $MinimumSavingsPercent
    [System.IO.File]::WriteAllText($PolicyPath, (($existing | ConvertTo-Json -Depth 12) + "`n"), $encoding)
}

[pscustomobject]@{
    result = $result
    result_path = $resultPath
    policy_path = if ($SavePolicy) { $PolicyPath } else { $null }
}
