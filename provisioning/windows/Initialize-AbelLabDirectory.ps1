[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RootOuName = "ABELLAB",
    [switch]$CreateSyntheticUsers,
    [securestring]$TemporaryPassword
)

$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

$domain = Get-ADDomain
$domainDn = $domain.DistinguishedName
$dnsRoot = $domain.DNSRoot

function Ensure-LabOu {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Path
    )

    $escapedName = $Name.Replace("'", "''")
    $existing = try {
        Get-ADOrganizationalUnit `
            -Filter "Name -eq '$escapedName'" `
            -SearchBase $Path `
            -SearchScope OneLevel `
            -ErrorAction Stop
    }
    catch {
        $null
    }

    if (-not $existing -and $PSCmdlet.ShouldProcess("OU=$Name,$Path", "Create organizational unit")) {
        New-ADOrganizationalUnit `
            -Name $Name `
            -Path $Path `
            -ProtectedFromAccidentalDeletion $true
    }
}

function Ensure-LabGroup {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [ValidateSet("Global", "DomainLocal")] [string]$Scope,
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Description
    )

    $existing = Get-ADGroup -Filter "SamAccountName -eq '$Name'" -ErrorAction SilentlyContinue
    if (-not $existing -and $PSCmdlet.ShouldProcess($Name, "Create $Scope security group")) {
        New-ADGroup `
            -Name $Name `
            -SamAccountName $Name `
            -GroupScope $Scope `
            -GroupCategory Security `
            -Path $Path `
            -Description $Description
    }
}

function Ensure-LabMembership {
    param(
        [Parameter(Mandatory)] [string]$Group,
        [Parameter(Mandatory)] [string]$Member
    )

    $groupObject = Get-ADGroup -Identity $Group -ErrorAction SilentlyContinue
    $memberObject = Get-ADObject `
        -Filter "SamAccountName -eq '$Member'" `
        -ErrorAction SilentlyContinue

    if (-not $groupObject -or -not $memberObject) {
        Write-Verbose "Membership deferred until both $Group and $Member exist."
        return
    }

    $present = Get-ADGroupMember -Identity $groupObject -Recursive:$false |
        Where-Object DistinguishedName -eq $memberObject.DistinguishedName

    if (-not $present -and $PSCmdlet.ShouldProcess("$Member -> $Group", "Add group membership")) {
        Add-ADGroupMember -Identity $Group -Members $Member
    }
}

Ensure-LabOu -Name $RootOuName -Path $domainDn
$root = "OU=$RootOuName,$domainDn"

"Users", "Computers", "Groups", "Service Accounts", "Disabled Objects" |
    ForEach-Object { Ensure-LabOu -Name $_ -Path $root }

$usersRoot = "OU=Users,$root"
"IT", "HR", "Finance", "Clinical", "Admin Accounts" |
    ForEach-Object { Ensure-LabOu -Name $_ -Path $usersRoot }

$computersRoot = "OU=Computers,$root"
"Workstations", "Member Servers" |
    ForEach-Object { Ensure-LabOu -Name $_ -Path $computersRoot }

$groupsOu = "OU=Groups,$root"
$groups = @(
    @{ Name="GG-All-Employees"; Scope="Global"; Description="All lab employees" }
    @{ Name="GG-IT-Users"; Scope="Global"; Description="Information Technology employees" }
    @{ Name="GG-IT-Helpdesk"; Scope="Global"; Description="IT help desk personnel" }
    @{ Name="GG-HR-Users"; Scope="Global"; Description="Human Resources employees" }
    @{ Name="GG-Finance-Users"; Scope="Global"; Description="Finance employees" }
    @{ Name="GG-Clinical-Users"; Scope="Global"; Description="Clinical operations employees" }
    @{ Name="GG-Linux-Admins"; Scope="Global"; Description="Authorized Linux administrators" }
    @{ Name="DL-IT-Share-RW"; Scope="DomainLocal"; Description="Modify access to IT file share" }
    @{ Name="DL-HR-Share-RW"; Scope="DomainLocal"; Description="Modify access to HR file share" }
    @{ Name="DL-Finance-Share-RW"; Scope="DomainLocal"; Description="Modify access to Finance file share" }
    @{ Name="DL-Clinical-Share-RW"; Scope="DomainLocal"; Description="Modify access to Clinical file share" }
)

foreach ($group in $groups) {
    Ensure-LabGroup -Name $group.Name -Scope $group.Scope -Path $groupsOu -Description $group.Description
}

@(
    @{ Group="GG-All-Employees"; Member="GG-IT-Users" }
    @{ Group="GG-All-Employees"; Member="GG-HR-Users" }
    @{ Group="GG-All-Employees"; Member="GG-Finance-Users" }
    @{ Group="GG-All-Employees"; Member="GG-Clinical-Users" }
    @{ Group="DL-IT-Share-RW"; Member="GG-IT-Users" }
    @{ Group="DL-HR-Share-RW"; Member="GG-HR-Users" }
    @{ Group="DL-Finance-Share-RW"; Member="GG-Finance-Users" }
    @{ Group="DL-Clinical-Share-RW"; Member="GG-Clinical-Users" }
) | ForEach-Object {
    Ensure-LabMembership -Group $_.Group -Member $_.Member
}

if ($CreateSyntheticUsers) {
    if (-not $TemporaryPassword) {
        throw "TemporaryPassword is required with CreateSyntheticUsers. Supply a SecureString; never store it in source control."
    }

    $users = @(
        @{ First="Al"; Last="Pacino"; Sam="apacino"; Ou="IT"; Title="Systems Administrator"; Department="Information Technology"; Groups=@("GG-IT-Users", "GG-Linux-Admins") }
        @{ First="John"; Last="Smith"; Sam="jsmith"; Ou="IT"; Title="Help Desk Technician"; Department="Information Technology"; Groups=@("GG-IT-Users", "GG-IT-Helpdesk") }
        @{ First="Michelle"; Last="Papazian"; Sam="mpapazian"; Ou="HR"; Title="HR Manager"; Department="Human Resources"; Groups=@("GG-HR-Users") }
        @{ First="Gordon"; Last="Ramsay"; Sam="gramsay"; Ou="Clinical"; Title="Clinical Nutrition Manager"; Department="Clinical Operations"; Groups=@("GG-Clinical-Users") }
        @{ First="Tony"; Last="Montana"; Sam="tmontana"; Ou="Finance"; Title="Financial Analyst"; Department="Finance"; Groups=@("GG-Finance-Users") }
    )

    foreach ($user in $users) {
        $existing = Get-ADUser -Filter "SamAccountName -eq '$($user.Sam)'" -ErrorAction SilentlyContinue
        if (-not $existing -and $PSCmdlet.ShouldProcess($user.Sam, "Create disabled synthetic user")) {
            New-ADUser `
                -Name "$($user.First) $($user.Last)" `
                -GivenName $user.First `
                -Surname $user.Last `
                -SamAccountName $user.Sam `
                -UserPrincipalName "$($user.Sam)@$dnsRoot" `
                -Department $user.Department `
                -Title $user.Title `
                -Path "OU=$($user.Ou),$usersRoot" `
                -AccountPassword $TemporaryPassword `
                -Enabled $false `
                -ChangePasswordAtLogon $true
        }

        foreach ($group in $user.Groups) {
            Ensure-LabMembership -Group $group -Member $user.Sam
        }
    }
}

Write-Host "Directory structure and access groups are present." -ForegroundColor Green
Write-Host "Synthetic users remain disabled until deliberately enabled for testing."
