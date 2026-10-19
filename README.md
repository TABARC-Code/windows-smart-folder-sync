# Smart Folder Sync

One-way PowerShell synchronisation using SHA-256, SHA-384 or SHA-512 to distinguish identical files.

Requires Windows PowerShell 5.1 or PowerShell 7+. Files are copied from source to destination; matching content is skipped.

## Commands

Preview changes without writing or removing anything:


```powershell
.\Smart-Folder-Sync.ps1 -Source 'C:\Projects' -Destination 'D:\Backup\Projects' -Mirror -WhatIf
```

Copy missing or changed files:


```powershell
.\Smart-Folder-Sync.ps1 -Source 'C:\Projects' -Destination 'D:\Backup\Projects'
```

Mirror the source. Files present only in the destination are moved to a timestamped quarantine directory outside the destination, rather than deleted:


```powershell
.\Smart-Folder-Sync.ps1 -Source 'C:\Projects' -Destination 'D:\Backup\Projects' -Mirror
```

To deliberately delete destination-only files permanently, add `-DeleteExtra` alongside `-Mirror`. To mirror an intentionally empty source, also add `-AllowEmptySource`.

The default quarantine directory is a sibling of the destination, named `.<destination>-sync-quarantine`. Specify a different folder with `-QuarantineDir`.

## Safety

- Source and destination must be separate, non-overlapping trees.
- `-WhatIf` is supported; preview destructive operations before applying them.
- A copied file is checked against the source hash before continuing.
- Symlink/reparse-point files are excluded from scanning. Test junction-heavy directory structures separately before trusting a mirror run.
- This is **not** a versioned backup system. Copies may replace changed destination files. Maintain separate historical backups.
- Avoid changing source files during a run. File locking and crash consistency are not guaranteed.
- Mirror quarantine is on the destination's parent drive by default; ensure that drive has enough capacity.
