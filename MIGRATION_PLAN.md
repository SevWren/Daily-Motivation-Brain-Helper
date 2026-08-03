# Migration Plan: `project-restart-pwsh7` → `main`

**Status:** Planned
**Target window:** Week of 2026-08-10 (2026-08-10 through 2026-08-14)
**Code freeze:** 2026-08-09 23:59 UTC
**Method:** Force-push (history rewrite)
**Executed by:** Repository owner (@SevWren)

---

## Overview

`main` currently holds the PowerShell 5.1 multi-file implementation (v1.x). The
`project-restart-pwsh7` branch holds the completed PowerShell 7 single-file port
(v2.0.0). This plan governs the force-push of `project-restart-pwsh7` onto `main`,
permanently replacing its history and file tree.

The `project-restart-pwsh7` branch is production-ready: it has a full Pester test
suite, CI/CD pipeline, PSScriptAnalyzer compliance, governance documentation, and
architecture decision records. The migration is a controlled promotion, not an
emergency rewrite.

---

## What Changes

| Area | Before (`main` v1.x) | After (`main` v2.0.0) |
|---|---|---|
| Runtime | PowerShell 5.1 | PowerShell 7 |
| .NET target | .NET Framework 4.x | .NET (via ps2exe, PS7) |
| Entry point | `src/MainApp.ps1` + `src/DailyMotivation.ps1` | `DailyMotivation.ps1` (single file at root) |
| Execution modes | Separate files per mode | Unified file: `/popup`, `/setfolder`, default UI |
| Build script | `.build.ps1` (InvokeBuild, 12 tasks) | `build.ps1` |
| Source layout | `src/` directory tree | Single file at repository root |
| Modules | `src/Modules/ConfigManager.psm1`, `src/Modules/TaskScheduler.psm1` | Absorbed into `DailyMotivation.ps1` |
| Shell extension | `src/ShellExtension/` (separate C# + PS bridge) | Integrated into `DailyMotivation.ps1` |
| Docs structure | Flat `docs/*.md` | Organized subdirectories (`docs/architecture/`, `docs/development/`, `docs/testing/`, etc.) |
| Governance files | None | `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, `CHANGELOG.md`, `CONTEXT.md` |
| Test count | 180+ Pester tests | Updated suite for single-file architecture |
| CI/CD | `test.yml` | Updated workflows with ps2exe build and coverage artifacts |
| Config location | `%APPDATA%\DailyMotivationBrainHelper\` | `%APPDATA%\DailyMotivationBrainHelper\` (unchanged) |

---

## Exact Schedule

| Date / Time (UTC) | Action | Owner |
|---|---|---|
| 2026-08-09 23:59 | **Code freeze** — no further merges to `main` | All contributors |
| 2026-08-10 (Mon) | Create snapshot tag `v1.1-pre-migration` | @SevWren |
| 2026-08-10 (Mon) | Create backup branch `backup/main-pre-pwsh7` | @SevWren |
| 2026-08-10 – 2026-08-14 | Force-push `project-restart-pwsh7` → `main` | @SevWren |
| Post-push (same day) | Verify CI passes on the new `main` | @SevWren |
| Post-push | Publish `UPGRADE_NOTES.md` on `main` | @SevWren |
| Post-push | Update GitHub repo description to reflect PS7 requirement | @SevWren |
| Post-push | Close or retarget any remaining open PRs | @SevWren + contributors |

---

## Pre-Migration Snapshot

Before the force-push, the current state of `main` is preserved in two forms:

### Annotated tag (permanent)

```bash
git checkout main
git pull origin main
git tag -a v1.1-pre-migration -m "Snapshot before pwsh7 migration (2026-08-09)"
git push origin v1.1-pre-migration
```

### Backup branch (browsable)

```bash
git checkout main
git checkout -b backup/main-pre-pwsh7
git push origin backup/main-pre-pwsh7
git checkout main
```

Both the tag and the branch will be kept indefinitely as a reference for the
PowerShell 5.1 codebase.

---

## Migration Steps

```bash
# 1. Ensure local copies are current
git fetch origin
git checkout project-restart-pwsh7
git pull origin project-restart-pwsh7

# 2. Create the pre-migration snapshot (see above)

# 3. Force-push project-restart-pwsh7 onto main
git push origin project-restart-pwsh7:main --force

# 4. Update local main
git checkout main
git pull origin main

# 5. Verify CI passes
#    Watch the Actions tab on GitHub for the test and build workflows.

# 6. Smoke-test locally (Windows, PowerShell 7)
pwsh -File .\Invoke-Tests.ps1
```

---

## Rollback Steps

If the migration causes a critical regression, restore `main` from the pre-migration
snapshot using either the tag or the backup branch:

```bash
# Option A — restore from the annotated tag
git checkout main
git reset --hard v1.1-pre-migration
git push origin main --force

# Option B — restore from the backup branch
git push origin backup/main-pre-pwsh7:main --force
```

After a rollback, open an issue describing the regression before attempting the
migration again.

---

## Breaking Changes Summary

| Category | Change | Impact |
|---|---|---|
| **Runtime** | PowerShell 5.1 → PowerShell 7 required | Users on PS5.1-only systems cannot run post-migration builds |
| **Entry point** | `src/MainApp.ps1` removed; `DailyMotivation.ps1` at root | Any scripts or shortcuts pointing to `src/MainApp.ps1` will break |
| **Modules** | `src/Modules/ConfigManager.psm1` and `src/Modules/TaskScheduler.psm1` removed | External imports of these modules will break |
| **Build** | `.build.ps1` (InvokeBuild) replaced by `build.ps1` | CI or local scripts calling `Invoke-Build` against `.build.ps1` must be updated |
| **Shell extension** | `src/ShellExtension/` directory removed | Re-registration required using the new single-file approach |
| **Docs** | Flat `docs/*.md` replaced by subdirectory tree | Bookmarks or direct links to old doc paths will 404 |
| **Git history** | History rewritten | Clones and forks based on old `main` history will diverge |

---

## Open PR Handling

All open PRs targeting `main` must be resolved before or immediately after migration.

- **Option A (preferred — before migration):** Rebase your branch onto
  `project-restart-pwsh7` and retarget the PR to `project-restart-pwsh7`.
- **Option B (after migration):** Rebase your branch onto the new `main`
  (which will be identical to `project-restart-pwsh7` post-migration) and reopen.

PRs left targeting the pre-migration `main` tree will become unmergeable after the
force-push because the base history no longer exists on the remote.

---

## Post-Migration Checklist

- [ ] Confirm GitHub Actions CI passes on the new `main`
- [ ] Publish `UPGRADE_NOTES.md` on `main` with full upgrade and developer setup guide
- [ ] Update GitHub repository description and topics to reflect PowerShell 7
- [ ] Verify the `v1.1-pre-migration` tag is visible on GitHub Releases/Tags page
- [ ] Verify `backup/main-pre-pwsh7` branch is accessible
- [ ] Close or retarget any open PRs that were not handled pre-migration
- [ ] Optionally archive `project-restart-pwsh7` (or leave as reference)
- [ ] Announce migration completion to any open issues that referenced the migration

---

## References

- [`project-restart-pwsh7` branch](https://github.com/SevWren/Daily-Motivation-Brain-Helper/tree/project-restart-pwsh7)
- [CHANGELOG.md on `project-restart-pwsh7`](https://github.com/SevWren/Daily-Motivation-Brain-Helper/blob/project-restart-pwsh7/CHANGELOG.md)
- Pre-migration snapshot tag: `v1.1-pre-migration`
- Pre-migration backup branch: `backup/main-pre-pwsh7`
- Post-migration guide: `UPGRADE_NOTES.md` (to be published after migration)
