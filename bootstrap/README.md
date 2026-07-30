# bootstrap

Installers only, no prose. Both are idempotent and support a dry run.

```bash
./install.sh --dry-run          # Linux / WSL
```

```powershell
& .\install.ps1 -DryRun         # Windows, PowerShell 7
```

The manual sequence these scripts automate, per-machine notes, troubleshooting and
rollback are in [`../docs/install.md`](../docs/install.md).
