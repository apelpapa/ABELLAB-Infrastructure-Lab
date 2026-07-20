# Provisioning notes

These scripts are sanitized, parameterized versions of procedures used to build the live lab. They are included for review and reproducibility; they are not unattended production installers.

## Safety model

- Windows scripts support `-WhatIf` and avoid embedded credentials.
- Synthetic user creation is opt-in, requires a `SecureString`, and creates accounts disabled by default.
- The Linux join script shows its intended action unless explicitly run with `--apply`.
- Review domain names, addresses, storage paths, group names, and module prerequisites before execution.

## Directory structure

Preview on a domain controller:

```powershell
.\windows\Initialize-AbelLabDirectory.ps1 -WhatIf
```

Optionally create disabled synthetic users after reviewing the script:

```powershell
$temporaryPassword = Read-Host "Temporary password" -AsSecureString
.\windows\Initialize-AbelLabDirectory.ps1 `
    -CreateSyntheticUsers `
    -TemporaryPassword $temporaryPassword
```

## File services

Install the role first, confirm the intended data volume, and preview changes:

```powershell
Install-WindowsFeature FS-Resource-Manager -IncludeManagementTools
.\windows\Initialize-AbelLabFileServices.ps1 -DataRoot "D:\Shares" -WhatIf
```

Run without `-WhatIf` only on an isolated lab file server whose target folders and share names have been reviewed.

## Linux domain membership

Preview:

```bash
bash linux/join-domain.sh
```

Apply after configuring AD-aware DNS and reviewing variables:

```bash
sudo REALM_NAME=corp.abel-lab.test \
  JOIN_USER=Administrator \
  LINUX_ADMIN_GROUP=GG-Linux-Admins \
  bash linux/join-domain.sh --apply
```
