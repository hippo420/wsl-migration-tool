# WSL Distribution Migration Tool (GUI)

A Windows Forms-based PowerShell tool to safely migrate your installed WSL distribution to another drive or folder.

# Features

  + List installed WSL distributions

  + Select distribution via GUI

  + Migrate to another folder/drive

  + Progress indicator

  + Safe export → unregister → import process

  + Automatic cleanup of temporary files

# Requirements

  + Windows 10 / 11

  + WSL installed

  + PowerShell 5.1+

  + Administrator privileges

# How It Works

```bash
wsl --export

wsl --unregister

wsl --import --version
```
This ensures the distribution is safely migrated.

# ▶ How To Run
```bash
# Run PowerShell as Administrator
.\migration-wsl-tool.ps1
```

If script execution is blocked:
```
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
# Important Notes

  + Do NOT use a drive root (e.g., D:\) as target.

  + Large distributions may take time to export/import.

  + SSD is recommended for faster migration.

  + Backup important data before migration.

# Example Use Case

Move Ubuntu from:
```makefile
C:\Users\...\AppData\Local\Packages\
```

to:
```makefile
D:\WSL\Ubuntu
```
