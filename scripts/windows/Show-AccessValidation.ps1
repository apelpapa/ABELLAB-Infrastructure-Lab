[CmdletBinding()]
param(
    [string]$AuthorizedShare = "\\LAB-FS01\IT",
    [string]$UnauthorizedShare = "\\LAB-FS01\HR",
    [string]$ExpectedDrive = "I:",
    [string[]]$ExpectedGroups = @(
        "GG-IT-Users",
        "GG-All-Employees",
        "DL-IT-Share-RW"
    )
)

$ErrorActionPreference = "Stop"
Clear-Host

function Show-Result {
    param(
        [string]$Label,
        [bool]$Passed,
        [string]$Detail
    )

    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }

    Write-Host ("[{0}] " -f $status) -ForegroundColor $color -NoNewline
    Write-Host $Label -NoNewline
    Write-Host (" - {0}" -f $Detail) -ForegroundColor DarkGray
}

$computer = Get-CimInstance Win32_ComputerSystem
$identity = whoami
$groups = whoami /groups | Out-String
$allPassed = $true

Write-Host "ABELLAB END-USER ACCESS VALIDATION" -ForegroundColor Cyan
Write-Host ("Validated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
Write-Host ("User:      {0}" -f $identity)
Write-Host ("Client:    {0}" -f $computer.Name)
Write-Host ("Domain:    {0}" -f $computer.Domain)
Write-Host ""

Write-Host "IDENTITY AND AUTHORIZATION" -ForegroundColor Cyan

foreach ($group in $ExpectedGroups) {
    $present = $groups -match [regex]::Escape($group)
    Show-Result "Security group" $present $group
    if (-not $present) { $allPassed = $false }
}

Write-Host ""
Write-Host "GROUP POLICY DRIVE MAPPING" -ForegroundColor Cyan

$mapping = Get-SmbMapping -LocalPath $ExpectedDrive -ErrorAction SilentlyContinue
$mappingPassed = $null -ne $mapping -and $mapping.RemotePath -eq $AuthorizedShare
Show-Result "Department drive" $mappingPassed "$ExpectedDrive -> $AuthorizedShare"
if (-not $mappingPassed) { $allPassed = $false }

Write-Host ""
Write-Host "FILE-SERVER ACCESS CONTROL" -ForegroundColor Cyan

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$authorizedFile = Join-Path $AuthorizedShare "access-validation-$stamp.txt"
$unauthorizedFile = Join-Path $UnauthorizedShare "access-validation-$stamp.txt"

$authorizedWrite = $false
try {
    "Validated by $identity" | Set-Content -LiteralPath $authorizedFile -ErrorAction Stop
    $authorizedWrite = Test-Path -LiteralPath $authorizedFile
    Remove-Item -LiteralPath $authorizedFile -Force -ErrorAction SilentlyContinue
}
catch {
    $authorizedWrite = $false
}

Show-Result "Authorized write" $authorizedWrite "IT share allowed"
if (-not $authorizedWrite) { $allPassed = $false }

$unauthorizedDenied = $false
try {
    "This cross-department write must be denied" |
        Set-Content -LiteralPath $unauthorizedFile -ErrorAction Stop
    Remove-Item -LiteralPath $unauthorizedFile -Force -ErrorAction SilentlyContinue
}
catch {
    $unauthorizedDenied = $true
}

Show-Result "Unauthorized write" $unauthorizedDenied "HR share denied"
if (-not $unauthorizedDenied) { $allPassed = $false }

Write-Host ""
Write-Host "OVERALL RESULT: " -NoNewline

if ($allPassed) {
    Write-Host "PASS" -ForegroundColor Green
    Write-Host "Least-privilege access is operating as designed."
}
else {
    Write-Host "FAIL" -ForegroundColor Red
    Write-Host "One or more validation checks require attention."
}
