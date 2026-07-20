# Validation strategy

The lab uses small, role-specific checks that report clear pass/fail outcomes. A screenshot is retained as a point-in-time record, while the script provides the inspectable test logic.

## Test matrix

| Validation | System and identity | Checks |
|---|---|---|
| End-user least privilege | LAB-CL01 as `ABELLAB\jsmith` | AD group token, GPO drive mapping, authorized IT write, denied HR write |
| FSRM enforcement | LAB-CL01 as `ABELLAB\mpapazian` | HR group token, H: mapping, allowed `.txt`, blocked `.exe`, denied Finance write |
| Domain services health | LAB-DC01 as domain administrator | DNS/KDC/Netlogon/NTDS, SYSVOL/NETLOGON, AD DNS, LDAP SRV record, focused DCDIAG |
| Backup and recovery | LAB-FS01 as domain administrator | Backup volume, 02:00 policy, recovery capabilities, deletion, alternate restore, SHA-256 equality |
| Linux integration | LAB-LNX01 as authorized AD administrator | Machine trust, SSSD online, identity/group lookup, sudo, Docker, Prometheus, Grafana |
| Monitoring alert | LAB-LNX01 and selected exporter | Pending after target loss, firing after one minute, inactive after recovery |

## Run the Windows checks

Run each script on the named system in an elevated Windows PowerShell 5.1 session when administrative modules are required.

```powershell
# LAB-CL01 as the synthetic IT user
.\scripts\windows\Show-AccessValidation.ps1

# LAB-CL01 as the synthetic HR user
.\scripts\windows\Show-FsrmValidation.ps1

# LAB-DC01 as a domain administrator
.\scripts\windows\Show-DomainHealthValidation.ps1

# LAB-FS01 after a controlled restore drill
.\scripts\windows\Show-RecoveryValidation.ps1
```

The recovery validator reads the latest `Recovery-Result-*.xml` artifact created by the controlled drill. Those local XML artifacts are excluded from source control because they contain machine-specific paths and operational state.

## Run the Linux check

The validation expects passwordless noninteractive `sudo` for the commands it probes. That was enabled only for the authorized synthetic lab administrator used for the recorded test.

```bash
bash scripts/linux/show-linux-validation.sh
```

## Static repository validation

Static checks do not need an Active Directory environment:

```powershell
pwsh -NoProfile -File tests/Test-PowerShellSyntax.ps1
```

```bash
bash tests/validate.sh
```

The Bash validator performs shell syntax checks and, when Docker is installed, validates the Compose render and Prometheus configuration/rules with `promtool` from the pinned Prometheus image.

## Controlled-failure procedure

The alert test is deliberately narrow:

1. Confirm all Prometheus targets are healthy.
2. Stop one exporter service on a non-production lab system.
3. Observe `ExporterDown` enter pending state.
4. Wait for the one-minute hold period and confirm firing state.
5. Restart the exporter and confirm the rule returns to inactive.

The recovery test follows a similar pattern: create one isolated file, capture its hash, confirm a successful backup version, delete only the prevalidated path, restore to a different directory, and compare hashes.
