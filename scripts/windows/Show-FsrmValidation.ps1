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

Write-Host "ABELLAB FSRM SECURITY VALIDATION" -ForegroundColor Cyan
Write-Host ("Validated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
Write-Host ("User:      {0}" -f $identity)
Write-Host ("Client:    {0}" -f $computer.Name)
Write-Host ("Domain:    {0}" -f $computer.Domain)
Write-Host ""

Write-Host "IDENTITY AND AUTHORIZATION" -ForegroundColor Cyan

foreach ($group in @("GG-HR-Users", "GG-All-Employees", "DL-HR-Share-RW")) {
    $present = $groups -match [regex]::Escape($group)
    Show-Result "Security group" $present $group
    if (-not $present) { $allPassed = $false }
}

Write-Host ""
Write-Host "GROUP POLICY DRIVE MAPPING" -ForegroundColor Cyan

$mapping = Get-SmbMapping -LocalPath "H:" -ErrorAction SilentlyContinue
$mappingPassed = $null -ne $mapping -and $mapping.RemotePath -eq "\\LAB-FS01\HR"

Show-Result "Department drive" $mappingPassed "H: -> \\LAB-FS01\HR"
if (-not $mappingPassed) { $allPassed = $false }

Write-Host ""
Write-Host "FILE-SERVER SECURITY CONTROLS" -ForegroundColor Cyan

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$textFile = "\\LAB-FS01\HR\portfolio-validation-$stamp.txt"
$exeFile = "\\LAB-FS01\HR\portfolio-validation-$stamp.exe"
$financeFile = "\\LAB-FS01\Finance\portfolio-validation-$stamp.txt"

$textAllowed = $false
try {
    "Validated by $identity" | Set-Content $textFile
    $textAllowed = Test-Path $textFile
    Remove-Item $textFile -Force
}
catch {
    $textAllowed = $false
}

Show-Result "Authorized document" $textAllowed "HR .txt file allowed"
if (-not $textAllowed) { $allPassed = $false }

$exeBlocked = $false
try {
    "This executable must be blocked" | Set-Content $exeFile
    Remove-Item $exeFile -Force -ErrorAction SilentlyContinue
}
catch {
    $exeBlocked = $true
}

Show-Result "FSRM file screen" $exeBlocked "HR .exe file blocked"
if (-not $exeBlocked) { $allPassed = $false }

$financeDenied = $false
try {
    "This cross-department write must be denied" | Set-Content $financeFile
    Remove-Item $financeFile -Force -ErrorAction SilentlyContinue
}
catch {
    $financeDenied = $true
}

Show-Result "Cross-department write" $financeDenied "Finance share denied"
if (-not $financeDenied) { $allPassed = $false }

Write-Host ""
Write-Host "OVERALL RESULT: " -NoNewline

if ($allPassed) {
    Write-Host "PASS" -ForegroundColor Green
    Write-Host "Department access and FSRM controls operate as designed."
}
else {
    Write-Host "FAIL" -ForegroundColor Red
    Write-Host "One or more validation checks require attention."
}
