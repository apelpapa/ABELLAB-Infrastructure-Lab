[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$markdownFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter "*.md" -File
$failed = $false

foreach ($file in $markdownFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    $links = [regex]::Matches($content, '\[[^\]]*\]\((?<target>[^)\s]+)')

    foreach ($link in $links) {
        $target = $link.Groups["target"].Value

        if (
            $target.StartsWith("#") -or
            $target -match "^(https?|mailto):"
        ) {
            continue
        }

        $pathOnly = $target.Split("#")[0]
        $decodedPath = [Uri]::UnescapeDataString($pathOnly)
        $resolvedPath = Join-Path $file.DirectoryName $decodedPath

        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            $failed = $true
            $relativeFile = $file.FullName.Substring($repoRoot.Length + 1)
            Write-Host "[FAIL] $relativeFile -> $target" -ForegroundColor Red
        }
    }
}

if ($failed) {
    throw "One or more local Markdown links are broken."
}

Write-Host "All local Markdown links resolve." -ForegroundColor Green
