# Continuous integration

Workflow: [`.github/workflows/test.yml`](../../.github/workflows/test.yml)

## Jobs

| Job | Runner | Purpose |
|-----|--------|---------|
| **test** | `windows-latest` (matrix) | Pester via `Invoke-Tests.ps1 -CI -Coverage $true`; uploads `TestResults.xml` and `coverage.xml` |
| **coverage-gate** | `ubuntu-latest` | Downloads `coverage.xml` from the Windows test run; parses JaCoCo XML and enforces `$minPct` threshold (currently **53%**) |
| **analyze** | `windows-latest` | PSScriptAnalyzer + PS7-syntax gate for ps2exe |
| **build** | `windows-latest` | Needs test + coverage-gate + analyze; runs `build.ps1`, smoke-checks exe size, uploads artifact |

## Pinned tooling (CI)

| Module | Version (workflow) |
|--------|--------------------|
| Pester | 5.6.1 |
| PSScriptAnalyzer | 1.22.0 |
| ps2exe | 1.0.14 |

## Coverage threshold

The coverage gate enforces a minimum line-coverage percentage against `DailyMotivation.ps1`. Both thresholds must be kept in sync:

| File | Variable | Current value |
|------|----------|---------------|
| `Invoke-Tests.ps1` | `$CoverageThreshold` | `53` |
| `.github/workflows/test.yml` | `$minPct` | `53` |

The headless ceiling is ~68% (see [testing strategy](../testing/strategy.md#coverage-goals)).

## Artifacts

- `TestResults.xml` (NUnit)
- `coverage.xml` (JaCoCo, from Windows test run)
- `DailyMotivation.exe` (build job)

## Local parity

```powershell
.\Invoke-Tests.ps1 -CI -Coverage $true
```

Analyzer (if installed):

```powershell
Invoke-ScriptAnalyzer -Path DailyMotivation.ps1 -Severity Warning,Error
```

## Branch triggers

Configured for `main`, `develop`, `project-restart`, `project-restart-pwsh7` (see workflow file for current list).
