# Engineering decisions

## Use a type-1 hypervisor

ESXi keeps the host dedicated to virtualization and resembles the administration model used in VMware environments. The laptop is unsupported consumer hardware, so the project documents the driver and hybrid-CPU workarounds as lab-only accommodations.

## Keep domain services and file services separate

`LAB-DC01` provides identity, DNS, and policy. `LAB-FS01` owns data, SMB permissions, FSRM, and recovery. Separating roles makes access and failure boundaries easier to reason about and avoids treating the domain controller as a general file server.

## Use group-based authorization

Resource permissions are assigned to domain-local groups, not individual accounts. Global groups express department or role membership. This makes onboarding and access review repeatable and demonstrates least-privilege administration.

## Join Linux to the same identity plane

The Ubuntu server uses realmd, Kerberos, and SSSD rather than a separate set of local administrator identities. An AD group controls realm login and sudo delegation, showing that a mixed Windows/Linux environment can use centralized identity.

## Keep monitoring local and declarative

Prometheus, Grafana, and Node Exporter run through Docker Compose. Their definitions are versionable and reproducible, while the services bind only to the LAN monitoring address. Windows Exporter firewall rules restrict scraping to the monitoring server.

## Prove recovery with content integrity

A backup-complete message alone does not prove recoverability. The drill deletes one controlled file, restores it to an alternate location, and confirms the restored SHA-256 hash equals the original hash.

## Prefer evidence over a public management login

A public demo account would require exposing sensitive infrastructure administration surfaces. The safer proof is source-controlled configuration, executable validation, incident documentation, and a local live walkthrough when requested.
