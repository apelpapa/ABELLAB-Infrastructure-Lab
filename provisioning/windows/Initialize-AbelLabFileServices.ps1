[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$DataRoot = "D:\Shares",
    [UInt64]$QuotaSize = 25GB,
    [string]$DomainNetbiosName = "ABELLAB"
)

$ErrorActionPreference = "Stop"
Import-Module SmbShare
Import-Module FileServerResourceManager

$shares = @(
    @{ Name="IT"; Group="DL-IT-Share-RW"; Screen=$false }
    @{ Name="HR"; Group="DL-HR-Share-RW"; Screen=$true }
    @{ Name="Finance"; Group="DL-Finance-Share-RW"; Screen=$true }
    @{ Name="Clinical"; Group="DL-Clinical-Share-RW"; Screen=$true }
)

foreach ($share in $shares) {
    $path = Join-Path $DataRoot $share.Name
    if ($PSCmdlet.ShouldProcess($path, "Create directory and apply least-privilege ACL")) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        & icacls.exe $path /inheritance:r | Out-Null
        & icacls.exe $path /grant:r `
            "BUILTIN\Administrators:(OI)(CI)(F)" `
            "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" `
            "${DomainNetbiosName}\Domain Admins:(OI)(CI)(F)" `
            "${DomainNetbiosName}\$($share.Group):(OI)(CI)(M)" | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "icacls failed for $path."
        }
    }

    $existingShare = Get-SmbShare -Name $share.Name -ErrorAction SilentlyContinue
    if (-not $existingShare -and $PSCmdlet.ShouldProcess($share.Name, "Create SMB share")) {
        New-SmbShare `
            -Name $share.Name `
            -Path $path `
            -FolderEnumerationMode AccessBased `
            -FullAccess "$DomainNetbiosName\Domain Admins" `
            -ChangeAccess "$DomainNetbiosName\$($share.Group)"
    }
}

$quotaTemplate = "ABELLAB 25GB Department"
if (-not (Get-FsrmQuotaTemplate -Name $quotaTemplate -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($quotaTemplate, "Create hard-quota template")) {
        New-FsrmQuotaTemplate -Name $quotaTemplate -Size $QuotaSize
    }
}

foreach ($share in $shares) {
    $path = Join-Path $DataRoot $share.Name
    if (-not (Get-FsrmQuota -Path $path -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($path, "Apply FSRM quota")) {
            New-FsrmQuota -Path $path -Template $quotaTemplate
        }
    }
}

$fileGroup = "ABELLAB Executables"
if (-not (Get-FsrmFileGroup -Name $fileGroup -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($fileGroup, "Create executable file group")) {
        New-FsrmFileGroup `
            -Name $fileGroup `
            -IncludePattern @("*.exe", "*.msi", "*.bat", "*.cmd", "*.com", "*.scr")
    }
}

$screenTemplate = "ABELLAB Block Executables"
if (-not (Get-FsrmFileScreenTemplate -Name $screenTemplate -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($screenTemplate, "Create active file-screen template")) {
        New-FsrmFileScreenTemplate `
            -Name $screenTemplate `
            -IncludeGroup $fileGroup `
            -Active
    }
}

foreach ($share in $shares | Where-Object Screen) {
    $path = Join-Path $DataRoot $share.Name
    if (-not (Get-FsrmFileScreen -Path $path -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($path, "Apply executable file screen")) {
            New-FsrmFileScreen -Path $path -Template $screenTemplate
        }
    }
}

Write-Host "File shares, quotas, and file screens are present." -ForegroundColor Green
