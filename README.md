# windows-smart-folder-sync
One-way synchronisation from Source to Destination using file hashing. Slower than timestamps, but far more reliable when clocks, copies, or tools lie.

# Smart Folder Sync (PowerShell)

One-way synchronisation from Source to Destination using file hashing.
Slower than timestamps, but far more reliable when clocks, copies, or tools lie.

## Requirements

- Windows
- PowerShell 5.1 or PowerShell 7+

## Usage

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Smart-Folder-Sync.ps1 -Source "C:\Data" -Destination "D:\Backup\Data"
Mirror mode (also removes destination files not present in source):

powershell
Copy code
.\Smart-Folder-Sync.ps1 -Source "C:\Data" -Destination "D:\Backup\Data" -Mirror
