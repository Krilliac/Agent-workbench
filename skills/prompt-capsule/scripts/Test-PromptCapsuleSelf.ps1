[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$fixture = Join-Path $skillRoot 'references\benchmark-fixture.md'
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $tempRoot ('prompt-capsule-selftest-{0}' -f [guid]::NewGuid().ToString('N'))

try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
    $created = & (Join-Path $scriptRoot 'New-PromptCapsule.ps1') `
        -PromptFile $fixture `
        -Name 'selftest' `
        -CapsuleId 'selftest-capsule-v1' `
        -OutputDirectory $testRoot `
        -Density Dense

    if ($created.pages -lt 1) { throw 'Renderer did not create any card pages.' }
    $validated = & (Join-Path $scriptRoot 'Test-PromptCapsule.ps1') -CapsuleDirectory $created.directory
    if (-not $validated.valid) { throw 'Validator did not report success.' }
    $measured = & (Join-Path $scriptRoot 'Measure-PromptCapsule.ps1') -CapsuleDirectory $created.directory
    if ($measured.estimated_text_tokens -le 0 -or $measured.exact_visual_tokens -le 0) {
        throw 'Token estimator returned a non-positive count.'
    }
    $dryRun = & (Join-Path $scriptRoot 'Invoke-PromptCapsuleBenchmark.ps1') -CapsuleDirectory $created.directory -Provider Both
    if ($dryRun.executed) { throw 'Benchmark dry run unexpectedly executed providers.' }
    if (@($dryRun.plan).Count -ne 2) { throw 'Benchmark dry run did not plan both providers.' }

    $mockProviderPath = Join-Path $testRoot 'mock-provider.ps1'
    $mockProvider = @'
$allArguments = @($args)
$isCodex = $allArguments -contains 'exec'
if ($isCodex -and $allArguments -contains '--ask-for-approval') {
    Write-Error 'Benchmark used the retired Codex --ask-for-approval flag.'
    exit 3
}
if ($isCodex -and -not ($allArguments -contains 'approval_policy="never"')) {
    Write-Error 'Benchmark did not pin the Codex approval policy to never.'
    exit 4
}
$prompt = if ($allArguments.Count -gt 0) { [string]$allArguments[-1] } else { '' }
$match = [regex]::Match($prompt, 'CAPSULE_ACK\|[^\r\n]+')
if (-not $match.Success) {
    Write-Error 'Benchmark acknowledgement was not present in the provider prompt.'
    exit 2
}
$isImage = ($allArguments -contains '--image') -or $prompt.Contains('Cards:')
if ($isCodex -and $isImage -and
    ($allArguments.Count -lt 2 -or $allArguments[-2] -ne '--')) {
    Write-Error 'Codex image benchmark did not terminate variadic image arguments before the prompt.'
    exit 5
}
$inputTokens = if ($isImage) { 700 } else { 1000 }
$ack = $match.Value.Replace('\', '\\').Replace('"', '\"')
if ($isCodex) {
    [Console]::Error.WriteLine('mock codex diagnostic')
    '{"type":"item.completed","item":{"type":"agent_message","text":"' + $ack + '"},"usage":{"input_tokens":' + $inputTokens + ',"output_tokens":10}}'
}
else {
    '{"result":"' + $ack + '","usage":{"input_tokens":' + $inputTokens + ',"output_tokens":10},"total_cost_usd":0.001}'
}
exit 0
'@
    [System.IO.File]::WriteAllText($mockProviderPath, $mockProvider, [System.Text.UTF8Encoding]::new($false))
    $mockPolicyPath = Join-Path $testRoot 'policy.json'
    $mockLive = & (Join-Path $scriptRoot 'Invoke-PromptCapsuleBenchmark.ps1') `
        -CapsuleDirectory $created.directory `
        -Provider Both `
        -Execute `
        -SavePolicy `
        -PolicyPath $mockPolicyPath `
        -ClaudeCommand $mockProviderPath `
        -CodexCommand $mockProviderPath
    if (-not $mockLive.result.decisions.Claude.enabled -or -not $mockLive.result.decisions.Codex.enabled) {
        throw 'Mocked live benchmark did not enable both providers after a measured fidelity-preserving win.'
    }
    if (-not (Test-Path -LiteralPath $mockPolicyPath -PathType Leaf)) {
        throw 'Mocked live benchmark did not save its policy.'
    }

    $promptPath = Join-Path $created.directory 'prompt.md'
    [System.IO.File]::AppendAllText($promptPath, "`nTAMPERED", [System.Text.UTF8Encoding]::new($false))
    $tamperCaught = $false
    try {
        & (Join-Path $scriptRoot 'Test-PromptCapsule.ps1') -CapsuleDirectory $created.directory | Out-Null
    }
    catch {
        $tamperCaught = $true
    }
    if (-not $tamperCaught) { throw 'Validator failed to detect source tampering.' }

    [pscustomobject]@{
        passed = $true
        renderer_pages = $created.pages
        files_verified = $validated.files_verified
        estimated_text_tokens = $measured.estimated_text_tokens
        exact_visual_tokens = $measured.exact_visual_tokens
        tamper_detection = 'passed'
        benchmark_dry_run = 'passed'
        benchmark_mocked_live = 'passed'
        policy_gate = 'passed'
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
        if (-not $resolvedTestRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove self-test directory outside the temporary root: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
