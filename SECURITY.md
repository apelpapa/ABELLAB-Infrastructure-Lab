# Security and privacy

This repository documents an isolated home lab. It intentionally excludes passwords, password hashes, tokens, API keys, private keys, recovery-state XML, raw event logs, and exported credential material.

The displayed user accounts are synthetic lab identities. The `192.168.2.0/24` addresses are RFC 1918 private addresses and are included to make the architecture and monitoring targets concrete.

Do not expose ESXi, RDP, SSH, SMB, Prometheus, Grafana, or Windows Exporter directly to the public internet. A different deployment should replace the example domain, IP addresses, and synthetic users before running provisioning code.

If you find sensitive material in this repository, report it privately to the repository owner rather than opening a public issue.
