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
$allPassed = $true

Write-Host "ABELLAB DOMAIN SERVICES HEALTH VALIDATION" -ForegroundColor Cyan
Write-Host ("Validated: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
Write-Host ("Server:    {0}" -f $computer.Name)
Write-Host ("Domain:    {0}" -f $computer.Domain)
Write-Host ("Address:   192.168.2.53")
Write-Host ""

Write-Host "ACTIVE DIRECTORY SERVICES" -ForegroundColor Cyan

$services = Get-Service DNS,KDC,Netlogon,NTDS
$servicesPassed = @($services | Where-Object Status -ne "Running").Count -eq 0
Show-Result "Core services" $servicesPassed "DNS, KDC, Netlogon, and NTDS running"
if (-not $servicesPassed) { $allPassed = $false }

$shares = Get-SmbShare -Name SYSVOL,NETLOGON -ErrorAction SilentlyContinue
$sharesPassed = @($shares).Count -eq 2
Show-Result "Domain shares" $sharesPassed "SYSVOL and NETLOGON published"
if (-not $sharesPassed) { $allPassed = $false }

$zone = Get-DnsServerZone -Name "corp.abel-lab.test" -ErrorAction SilentlyContinue
$zonePassed = $null -ne $zone -and $zone.IsDsIntegrated -and $zone.DynamicUpdate -eq "Secure"
Show-Result "AD-integrated DNS" $zonePassed "Secure dynamic updates enabled"
if (-not $zonePassed) { $allPassed = $false }

Write-Host ""
Write-Host "SERVICE DISCOVERY AND DIAGNOSTICS" -ForegroundColor Cyan

$siteRecordPassed = $false
try {
    $siteRecord = Resolve-DnsName "_ldap._tcp.Default-First-Site-Name._sites.corp.abel-lab.test" -Type SRV
    $siteRecordPassed = $siteRecord.NameTarget -contains "lab-dc01.corp.abel-lab.test"
}
catch {
    $siteRecordPassed = $false
}
Show-Result "LDAP site locator" $siteRecordPassed "LAB-DC01 advertised on TCP 389"
if (-not $siteRecordPassed) { $allPassed = $false }

$dcdiagOutput = dcdiag /test:Advertising /test:Services /test:SysVolCheck /test:NetLogons /test:DNS /q 2>&1
$diagnosticsPassed = $LASTEXITCODE -eq 0 -and -not $dcdiagOutput
Show-Result "Focused DCDIAG" $diagnosticsPassed "Advertising, services, SYSVOL, Netlogon, and DNS"
if (-not $diagnosticsPassed) { $allPassed = $false }

$domain = Get-ADDomain
$forest = Get-ADForest
$directoryPassed = $domain.DNSRoot -eq "corp.abel-lab.test" -and $forest.RootDomain -eq "corp.abel-lab.test"
Show-Result "Directory identity" $directoryPassed "Domain and forest metadata resolved"
if (-not $directoryPassed) { $allPassed = $false }

Write-Host ""
Write-Host "DIRECTORY INVENTORY" -ForegroundColor Cyan
Write-Host ("Enabled users: {0}" -f @(Get-ADUser -Filter 'Enabled -eq $true').Count)
Write-Host ("Security groups: {0}" -f @(Get-ADGroup -Filter 'GroupCategory -eq "Security"').Count)
Write-Host ("Domain computers: {0}" -f @(Get-ADComputer -Filter *).Count)
Write-Host ("Organizational units: {0}" -f @(Get-ADOrganizationalUnit -Filter *).Count)

Write-Host ""
Write-Host "OVERALL RESULT: " -NoNewline

if ($allPassed) {
    Write-Host "PASS" -ForegroundColor Green
    Write-Host "Active Directory and DNS services operate as designed."
}
else {
    Write-Host "FAIL" -ForegroundColor Red
    Write-Host "One or more validation checks require attention."
    if ($dcdiagOutput) {
        Write-Host "Run focused DCDIAG manually for diagnostic detail."
    }
}
