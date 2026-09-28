# Provisioning artifacts

These scripts are sanitized, parameterized versions of procedures used to build the live lab. They document the implementation and are included as reviewable project evidence.

## What the scripts cover

| Script | Purpose |
| --- | --- |
| `windows/Initialize-AbelLabDirectory.ps1` | Active Directory structure, groups, and optional synthetic accounts |
| `windows/Initialize-AbelLabFileServices.ps1` | Department shares, file permissions, and file-service controls |
| `linux/join-domain.sh` | Linux membership in the lab Active Directory domain |

## Safety model

- Windows scripts support `-WhatIf` and avoid embedded credentials.
- Synthetic user creation is opt-in, accepts a `SecureString`, and creates accounts disabled by default.
- The Linux join script defaults to a preview; applying changes is a separate explicit operation.
- The procedures were designed for the isolated lab and its documented topology.
