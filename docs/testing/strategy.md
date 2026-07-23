# Test strategy

## Environments

| Environment | Role |
|-------------|------|
| **Windows 10/11 + PowerShell 7** | **Primary.** Source of truth for Task Scheduler, registry, and most unit tests |
| **Linux PowerShell 7** | Secondary. Platform-abstraction tests only |

**Do not** treat Linux-only green results as proof that Windows suites pass. Mocks and CIM/registry behavior differ.

## Runner

```powershell
.\Invoke-Tests.ps1                 # all tests; coverage on by default
.\Invoke-Tests.ps1 -CI             # exit on failure; NUnit XML
.\Invoke-Tests.ps1 -Tag Security
.\Invoke-Tests.ps1 -ExcludeTag Slow
.\Invoke-Tests.ps1 -Coverage $false
```

Parameters (`Invoke-Tests.ps1`):

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Tag` | `string[]` | Include only these Pester tags |
| `-ExcludeTag` | `string[]` | Exclude tags |
| `-CI` | switch | `Run.Exit`, NUnit `TestResults.xml` |
| `-Coverage` | `bool` | Default `$true`; JaCoCo `coverage.xml` on `DailyMotivation.ps1` |

## Loading the app under test

Every suite that needs functions uses:

```powershell
. .\DailyMotivation.ps1 -NoRun
```

`-NoRun` defines functions but skips the entry-point switch (no UI).

## Test layout

| Area | Path | Notes |
|------|------|-------|
| Unit | `Tests/Unit/*.Tests.ps1` | Config, scheduler, security, UI, messages, … |
| Integration | `Tests/Integration/SingleFile.Tests.ps1` | Single-file contract |
| Windows-heavy | `TaskScheduler.Tests.ps1`, `ContextMenu.Tests.ps1` | Prefer Windows host |
| Platform-safe | `*.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1` | HeadlessPlatform |

## Platform adapter

When `$script:Platform` is set, scheduling/dialog calls go through the adapter instead of live Windows cmdlets. Production leaves `$script:Platform = $null`.

See [ADR-003](../architecture/adr-003-platform-adapter.md).

## Coverage goals

Coverage is collected for `DailyMotivation.ps1`. Treat coverage as a signal, not a substitute for Windows behavioral tests.

## Pester version

**Pester 5.x required.** File-scoped `BeforeAll` mocks and `-ForEach` on `It` are v5 features. Pester 4 is unsupported.
