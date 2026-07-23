# Local development setup

## Prerequisites

| Tool | Purpose |
|------|---------|
| Windows 10 or 11 | App runtime and primary test host |
| PowerShell 7 (`pwsh`) | Develop and run tests |
| Pester 5.x | Test framework |
| ps2exe | Compile `DailyMotivation.exe` |
| Git | Source control |

```powershell
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
Install-Module ps2exe -Scope CurrentUser
```

Optional: PSScriptAnalyzer (CI pins a version — match CI when debugging analyzer failures).

## Clone and verify

```powershell
git clone https://github.com/SevWren/Daily-Motivation-Brain-Helper.git
cd Daily-Motivation-Brain-Helper
pwsh -File .\Invoke-Tests.ps1
```

Tests **dot-source** `DailyMotivation.ps1 -NoRun`. You do not need a built exe to run the suite.

## Build the executable

```powershell
.\build.ps1
```

Output: `DailyMotivation.exe` in the repo root (gitignored). Build uses:

- `-STA` (required for WPF)
- `-noConsole`
- Version metadata `2.0.0.0` (see `build.ps1`)

## Project layout (essentials)

| Path | Role |
|------|------|
| `DailyMotivation.ps1` | Entire application |
| `build.ps1` | ps2exe wrapper |
| `Invoke-Tests.ps1` | Test runner |
| `Tests/` | Pester unit + integration |
| `docs/` | Developer docs |
| `manual/` | User docs |
| `CONTEXT.md` | Domain language |

## Coding constraints

1. Prefer PowerShell syntax compatible with the **.NET Framework 4.x** host used by the compiled exe.
2. Never show blocking startup dialogs in **main** mode.
3. Use terms from `CONTEXT.md`.
4. Treat Windows test results as authoritative for Task Scheduler / registry tests.

## Next

- [Testing strategy](../testing/strategy.md)
- [CI](ci.md)
- [Architecture overview](../architecture/overview.md)
