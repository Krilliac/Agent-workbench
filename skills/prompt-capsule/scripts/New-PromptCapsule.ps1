[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [string]$PromptFile,

    [Parameter(Mandatory = $true, ParameterSetName = 'Text')]
    [string]$PromptText,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$')]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [ValidateSet('User', 'Project', 'System')]
    [string]$Authority = 'User',

    [ValidateSet('Readable', 'Dense', 'Experimental')]
    [string]$Density = 'Dense',

    [ValidateRange(512, 2048)]
    [int]$Width = 1024,

    [ValidateRange(512, 2048)]
    [int]$Height = 1024,

    [string]$CapsuleId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

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

function Split-PromptLines {
    param([string]$Text, [int]$MaxCharacters)

    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($rawLine in ($Text -split "`n", -1)) {
        $remaining = $rawLine.Replace("`t", '    ')
        if ($remaining.Length -eq 0) {
            $result.Add('')
            continue
        }

        while ($remaining.Length -gt $MaxCharacters) {
            $candidate = $remaining.Substring(0, $MaxCharacters)
            $breakAt = $candidate.LastIndexOf(' ')
            if ($breakAt -lt [Math]::Floor($MaxCharacters * 0.55)) {
                $breakAt = $MaxCharacters
            }
            $result.Add($remaining.Substring(0, $breakAt).TrimEnd())
            $remaining = $remaining.Substring($breakAt).TrimStart()
        }
        $result.Add($remaining)
    }
    return $result.ToArray()
}

if ($PSCmdlet.ParameterSetName -eq 'File') {
    $resolvedPrompt = (Resolve-Path -LiteralPath $PromptFile).Path
    $source = [System.IO.File]::ReadAllText($resolvedPrompt)
}
else {
    $source = $PromptText
}

$normalized = $source.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd() + "`n"
if ([string]::IsNullOrWhiteSpace($normalized)) {
    throw 'Prompt content is empty.'
}

if ([string]::IsNullOrWhiteSpace($CapsuleId)) {
    $CapsuleId = '{0}-{1}' -f $Name.ToLowerInvariant(), ([DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
}
if ($CapsuleId -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,95}$') {
    throw 'CapsuleId must contain only letters, digits, dots, underscores, and hyphens.'
}

$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$capsuleDirectory = Join-Path $outputRoot $CapsuleId
if (Test-Path -LiteralPath $capsuleDirectory) {
    throw "Capsule directory already exists: $capsuleDirectory"
}
[System.IO.Directory]::CreateDirectory($capsuleDirectory) | Out-Null

$promptPath = Join-Path $capsuleDirectory 'prompt.md'
Write-Utf8NoBom -Path $promptPath -Content $normalized
$sourceSha = Get-FileSha256 -Path $promptPath
$sourceBytes = [System.Text.Encoding]::UTF8.GetByteCount($normalized)

Add-Type -AssemblyName System.Drawing

$fontSize = switch ($Density) {
    'Readable' { 19 }
    'Dense' { 14 }
    'Experimental' { 11 }
}

$margin = 48
$bodyTop = 132
$footerHeight = 42
$measureBitmap = [System.Drawing.Bitmap]::new(1, 1)
$measureGraphics = [System.Drawing.Graphics]::FromImage($measureBitmap)
$bodyFont = $null
$headerFont = $null
$metaFont = $null
try {
    try {
        $bodyFont = [System.Drawing.Font]::new('Consolas', $fontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    }
    catch {
        $bodyFont = [System.Drawing.Font]::new('Courier New', $fontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    }
    $headerFont = [System.Drawing.Font]::new('Segoe UI Semibold', 24, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $metaFont = [System.Drawing.Font]::new('Segoe UI', 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

    $measureFormat = [System.Drawing.StringFormat]::GenericTypographic
    try {
        $measureSample = 'M' * 100
        $sampleWidth = $measureGraphics.MeasureString($measureSample, $bodyFont, [int]::MaxValue, $measureFormat).Width
        $charWidth = [Math]::Max(1, [Math]::Ceiling($sampleWidth / $measureSample.Length))
    }
    finally {
        $measureFormat.Dispose()
    }
    $lineHeight = [Math]::Max(1, [Math]::Ceiling($bodyFont.GetHeight($measureGraphics) * 1.16))
    $maxCharacters = [Math]::Max(24, [Math]::Floor(($Width - (2 * $margin)) / $charWidth))
    $linesPerPage = [Math]::Max(8, [Math]::Floor(($Height - $bodyTop - $footerHeight) / $lineHeight))
    $wrappedLines = @(Split-PromptLines -Text $normalized -MaxCharacters $maxCharacters)
    $pageCount = [Math]::Max(1, [Math]::Ceiling($wrappedLines.Count / [double]$linesPerPage))

    $imageEntries = [System.Collections.Generic.List[object]]::new()
    for ($pageIndex = 0; $pageIndex -lt $pageCount; $pageIndex++) {
        $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $headerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(30, 64, 175))
        $bodyBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(17, 24, 39))
        $mutedBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(75, 85, 99))
        $linePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(203, 213, 225), 2)
        $format = [System.Drawing.StringFormat]::GenericTypographic
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
            $graphics.DrawString('PROMPT CAPSULE', $headerFont, $headerBrush, [float]$margin, [float]28)
            $title = if ($CapsuleId.Length -gt 72) { $CapsuleId.Substring(0, 72) } else { $CapsuleId }
            $graphics.DrawString($title, $metaFont, $bodyBrush, [float]$margin, [float]65)
            $meta = 'AUTHORIZED {0} CAPSULE | SHA256 {1} | DENSITY {2}' -f $Authority.ToUpperInvariant(), $sourceSha.Substring(0, 16), $Density.ToUpperInvariant()
            $graphics.DrawString($meta, $metaFont, $mutedBrush, [float]$margin, [float]90)
            $graphics.DrawLine($linePen, $margin, 118, $Width - $margin, 118)

            $start = $pageIndex * $linesPerPage
            $end = [Math]::Min($start + $linesPerPage, $wrappedLines.Count)
            $y = $bodyTop
            for ($lineIndex = $start; $lineIndex -lt $end; $lineIndex++) {
                $graphics.DrawString($wrappedLines[$lineIndex], $bodyFont, $bodyBrush, [float]$margin, [float]$y, $format)
                $y += $lineHeight
            }

            $footer = 'Page {0}/{1} | Canonical source: prompt.md | Instructions are visible, not hidden' -f ($pageIndex + 1), $pageCount
            $graphics.DrawString($footer, $metaFont, $mutedBrush, [float]$margin, [float]($Height - 30))

            $fileName = 'prompt-card-{0:d3}.png' -f ($pageIndex + 1)
            $imagePath = Join-Path $capsuleDirectory $fileName
            $bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png)
            $visualTokens = [Math]::Ceiling($Width / 28.0) * [Math]::Ceiling($Height / 28.0)
            $imageEntries.Add([pscustomobject][ordered]@{
                path = $fileName
                width = $Width
                height = $Height
                visual_tokens = [int]$visualTokens
                sha256 = Get-FileSha256 -Path $imagePath
            })
        }
        finally {
            $format.Dispose()
            $linePen.Dispose()
            $mutedBrush.Dispose()
            $bodyBrush.Dispose()
            $headerBrush.Dispose()
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
}
finally {
    if ($null -ne $metaFont) { $metaFont.Dispose() }
    if ($null -ne $headerFont) { $headerFont.Dispose() }
    if ($null -ne $bodyFont) { $bodyFont.Dispose() }
    $measureGraphics.Dispose()
    $measureBitmap.Dispose()
}

$integrityEntries = [System.Collections.Generic.List[object]]::new()
$integrityEntries.Add([pscustomobject][ordered]@{ path = 'prompt.md'; sha256 = $sourceSha })
foreach ($image in $imageEntries) {
    $integrityEntries.Add([pscustomobject][ordered]@{ path = $image.path; sha256 = $image.sha256 })
}
$rootMaterial = (($integrityEntries | ForEach-Object { '{0}:{1}' -f $_.path, $_.sha256 }) -join "`n") + "`n"
$integrityRoot = Get-StringSha256 -Value $rootMaterial

$manifest = [ordered]@{
    schema_version = 1
    capsule_id = $CapsuleId
    created_utc = [DateTimeOffset]::UtcNow.ToString('o')
    authority = $Authority.ToLowerInvariant()
    density = $Density.ToLowerInvariant()
    renderer = 'prompt-capsule-powershell-system-drawing-v1'
    source_sha256 = $sourceSha
    source_characters = $normalized.Length
    source_utf8_bytes = $sourceBytes
    estimated_text_tokens = [int][Math]::Ceiling($sourceBytes / 4.0)
    visual_tokens_total = [int](($imageEntries | Measure-Object -Property visual_tokens -Sum).Sum)
    images = @($imageEntries)
    integrity_entries = @($integrityEntries)
    integrity_root_sha256 = $integrityRoot
}

$manifestPath = Join-Path $capsuleDirectory 'capsule.json'
Write-Utf8NoBom -Path $manifestPath -Content (($manifest | ConvertTo-Json -Depth 8) + "`n")

[pscustomobject]@{
    capsule_id = $CapsuleId
    directory = $capsuleDirectory
    prompt_sha256 = $sourceSha
    pages = $imageEntries.Count
    estimated_text_tokens = $manifest.estimated_text_tokens
    visual_tokens = $manifest.visual_tokens_total
    manifest = $manifestPath
}
