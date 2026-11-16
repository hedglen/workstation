# Workstation 2.0

A lean, curated Windows 11 setup. **This branch is a review candidate, not yet merged into master.**

## Install from a local checkout

Open PowerShell 7 in the repository root:

```powershell
.\install.ps1                          # Preview only (default)
.\install.ps1 -Validate -ContinueOnError # Check exact WinGet package IDs, no installs
.\install.ps1 -Install -ContinueOnError  # Install approved WinGet packages
```

**Do not run the old `irm .../master/install.ps1 | iex` command.** The master branch still contains the legacy bootstrap. This branch's installer requires its adjacent `apps.json` file, so download or clone the branch before running.

## What is included

- `apps.json`: one curated manifest, currently 30 WinGet entries, including Snipaste (`liule.Snipaste`) and EarTrumpet (`File-New-Project.EarTrumpet`).
- Scrivener is approved, but its installer/WinGet ID and license workflow still need confirmation.
- Eight additional apps are listed under `verifyPackageId` until installation methods are verified.
- Manual steps include ModernZ, portable Revo, license activation, account sign-ins, and config review.
- Roon is optional, not installed automatically.
- Browser-based office, email, and calendar require no desktop installer.

## Safety and limitations

The installer is preview-only by default, requires WinGet, checks exact IDs, and skips packages WinGet recognizes as installed. It does not alter Windows startup, registry, privacy settings, or perform debloating. It does not restore configurations automatically. The original repository history and older files remain available on this branch for inspection, **but many legacy documents, scripts, and manifests are not part of Workstation 2.0 and must not be run**. The old `apps/winget-packages.json` and `apps/scoop-packages.json` are archival references, **not** inputs to the new installer.

The user's original 28 WinGet IDs passed a Windows discovery check; the two newly added IDs need a new validation run. A successful validation proves discoverability, not successful installation. No installation or config migration has been tested on a clean Windows machine.

Never commit passwords, license keys, or private configuration data. Keep separate backups of important files.

## Next steps

1. Validate the two new WinGet IDs on Windows and resolve remaining application installation methods.
2. Review WezTerm, Rio, PowerShell, and mpv configs before copying any of them.
3. Audit or archive legacy files before merging this branch into `master`.
4. Test a fresh-machine install before publishing a one-command bootstrap.
