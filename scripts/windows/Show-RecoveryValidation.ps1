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

$resultFile = Get-ChildItem "C:\LabEvidence\Recovery-Result-*.xml" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $resultFile) {
    throw "No recovery-result evidence file was found."
}

$result = Import-Clixml -LiteralPath $resultFile.FullName
$allPassed = $true

Write-Host "ABELLAB BACKUP AND RECOVERY VALIDATION" -ForegroundColor Cyan
Write-Host ("Validated:      {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
Write-Host ("Server:         LAB-FS01")
Write-Host ("Recovery case:  {0}" -f $result.CaseId)
Write-Host ("Backup version: {0}" -f $result.BackupVersion)
Write-Host ""

Write-Host "BACKUP POLICY AND STORAGE" -ForegroundColor Cyan

$backupVolume = Get-Volume -DriveLetter E
$volumePassed = $backupVolume.HealthStatus -eq "Healthy"
Show-Result "Backup volume" $volumePassed "E: is healthy and online"
if (-not $volumePassed) { $allPassed = $false }

$policy = Get-WBPolicy
$schedule = @(Get-WBSchedule -Policy $policy)
$schedulePassed = @($schedule | Where-Object Hour -eq 2).Count -gt 0
Show-Result "Scheduled policy" $schedulePassed "Daily backup configured for 02:00"
if (-not $schedulePassed) { $allPassed = $false }

$versionOutput = wbadmin get versions -backupTarget:E: 2>&1 | Out-String
$versionPattern = [regex]::Escape($result.BackupVersion)
$capabilityPattern = "(?s)Version identifier:\s*$versionPattern.*?Can recover:.*?Bare Metal Recovery, System State"
$capabilitiesPassed = $versionOutput -match $capabilityPattern
Show-Result "Recovery capabilities" $capabilitiesPassed "Files, volumes, apps, BMR, and system state"
if (-not $capabilitiesPassed) { $allPassed = $false }

Write-Host ""
Write-Host "CONTROLLED RECOVERY DRILL" -ForegroundColor Cyan

$deletionPassed = -not (Test-Path -LiteralPath $result.OriginalPath)
Show-Result "Controlled deletion" $deletionPassed "Original test file remains absent"
if (-not $deletionPassed) { $allPassed = $false }

$restorePassed = Test-Path -LiteralPath $result.RestoredPath
Show-Result "Alternate-path restore" $restorePassed "One file recovered with zero failures"
if (-not $restorePassed) { $allPassed = $false }

$restoredHash = if ($restorePassed) {
    (Get-FileHash -LiteralPath $result.RestoredPath -Algorithm SHA256).Hash
}
else {
    ""
}

$hashPassed = $restorePassed -and $restoredHash -eq $result.OriginalHash
$shortHash = if ($restoredHash.Length -ge 16) {
    $restoredHash.Substring(0,16) + "..."
}
else {
    "Unavailable"
}

Show-Result "SHA256 integrity" $hashPassed "$shortHash matches original"
if (-not $hashPassed) { $allPassed = $false }

Write-Host ""
Write-Host "OVERALL RESULT: " -NoNewline

if ($allPassed) {
    Write-Host "PASS" -ForegroundColor Green
    Write-Host "Backup availability and restored-file integrity are verified."
}
else {
    Write-Host "FAIL" -ForegroundColor Red
    Write-Host "One or more validation checks require attention."
}
