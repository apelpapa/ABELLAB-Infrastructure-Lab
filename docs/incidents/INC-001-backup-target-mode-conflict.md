# INC-001: One-time backup conflicted with the scheduled backup target

## Summary

During a controlled recovery drill on `LAB-FS01`, an explicitly scoped one-time VSS copy backup was directed to `E:`, the destination already managed by the scheduled Windows Server Backup policy. Windows warned that this could overwrite the scheduled backup and then stopped before completion while pruning the target VHD.

## Evidence

- Failed operation: selected-folder VSS copy from `D:` to `E:`
- Windows Server Backup error: `0x80070020`
- Locked path: `D:\System Volume Information\SRM\DataScreenDatabase.xml.alt`
- Reported cause: the file was in use by another process
- Related service: File Server Resource Manager

## Impact assessment

- The controlled source file remained present and retained its expected SHA-256 hash.
- No backup or recovery operation remained active.
- Existing full recovery versions `07/20/2026-03:03` and `07/20/2026-21:27` remained discoverable.
- No production or user data was involved.

## Resolution

The selected-folder command was not retried. Instead, `wbadmin start backup -quiet` was run without a new target or include list, causing Windows Server Backup to use its existing scheduled full-server policy. Version `07/20/2026-22:05` completed successfully with file, volume, application, bare-metal, and system-state recovery capabilities.

The isolated test file was then deleted, recovered to an alternate path, and verified against its original SHA-256 hash. One file and 155 bytes were recovered with zero failures.

## Preventive lesson

Do not mix a separately defined one-time backup with a destination already managed by a scheduled Windows Server Backup policy. Use the existing policy without overriding its parameters, or provide a separate recovery-drill target.
