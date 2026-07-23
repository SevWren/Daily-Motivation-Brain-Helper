# Contributing

Thanks for helping improve Daily Motivation Brain Helper.

## Project shape

- **One source file:** `DailyMotivation.ps1`
- **One binary:** `DailyMotivation.exe` (via `build.ps1` / ps2exe)
- **Domain language:** [CONTEXT.md](CONTEXT.md) — use these terms in code, commits, and docs
- **Agent notes:** [CLAUDE.md](CLAUDE.md) — architecture map and test-environment rules

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| Windows 10 or 11 | Runtime target for the app |
| PowerShell 7 (`pwsh`) | Development and testing |
| Pester **5.x** | `Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck` |
| ps2exe (for builds) | `Install-Module ps2exe -Scope CurrentUser` |

The compiled exe targets **.NET Framework 4.x** (ps2exe limitation). Avoid PowerShell 7-only features in runtime code paths (`??`, `?.`, `Join-String`, `ForEach-Object -Parallel`).

## Getting started

```powershell
# Clone and enter the repo
cd Daily-Motivation-Brain-Helper

# Run tests (no exe required — tests use -NoRun)
.\Invoke-Tests.ps1

# Optional: build the exe
.\build.ps1
```

More detail: [docs/development/local-setup.md](docs/development/local-setup.md).

## Testing rules (critical)

1. **Windows 10/11 PowerShell 7 is the primary validation environment.**
2. Tests that pass only in a Linux sandbox are **not** sufficient for Windows-only suites (Task Scheduler, registry, CIM).
3. Platform-abstraction tests (`*.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1`) may run on Linux with HeadlessPlatform.
4. Prefer `.\Invoke-Tests.ps1` over calling `Invoke-Pester` directly.

```powershell
.\Invoke-Tests.ps1                  # all tests + coverage (default)
.\Invoke-Tests.ps1 -CI              # exit code + NUnit XML
.\Invoke-Tests.ps1 -Tag Security    # filter by tag
.\Invoke-Tests.ps1 -Coverage $false # skip coverage
```

See [docs/testing/strategy.md](docs/testing/strategy.md).

## Code quality rules

- **No startup popups** in main mode — launch straight into the main window.
- Prefer comments that explain *why*, not bug IDs (`# AG19-003:` style is discouraged).
- Match domain terms from `CONTEXT.md` (MotivationTask, Open Folder, Handoff, OS Task, …).
- Keep the single-file architecture unless an ADR changes it.

## Pull requests

1. Branch from the active development branch.
2. Keep changes focused; update docs when behavior or public surface changes.
3. Run relevant tests on **Windows** before requesting review.
4. Fill out the PR template checklist.
5. Do not commit secrets, local `handoff.md` content meant to stay private, or large generated binaries unless intentional.

## Documentation

| Audience | Location |
|----------|----------|
| End users | [manual/](manual/README.md) |
| Developers | [docs/](docs/README.md) |
| Security reports | [SECURITY.md](SECURITY.md) |

## License

By contributing, you agree that your contributions are licensed under the same MIT License as the project.

---

_Last updated: 2026-07-23_
