[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter "*.ps1" -File |
    Where-Object FullName -ne $PSCommandPath

if (-not $files) {
    throw "No PowerShell files were found."
}

$failed = $false

foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($parseErrors.Count -eq 0) {
        Write-Host "[PASS] $($file.FullName.Substring($repoRoot.Length + 1))" -ForegroundColor Green
        continue
    }

    $failed = $true
    Write-Host "[FAIL] $($file.FullName.Substring($repoRoot.Length + 1))" -ForegroundColor Red
    foreach ($parseError in $parseErrors) {
        Write-Host "  Line $($parseError.Extent.StartLineNumber): $($parseError.Message)"
    }
}

if ($failed) {
    throw "One or more PowerShell files contain parser errors."
}

Write-Host "All PowerShell files parsed successfully." -ForegroundColor Green
