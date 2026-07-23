# Continuous integration

Workflow: [`.github/workflows/test.yml`](../../.github/workflows/test.yml)

## Jobs

| Job | Runner | Purpose |
|-----|--------|---------|
| **test** | `windows-latest` | Pester via `Invoke-Tests.ps1 -CI -Coverage $true` |
| **analyze** | `windows-latest` | PSScriptAnalyzer + PS7-syntax gate for ps2exe |
| **build** | `windows-latest` | Needs test+analyze; runs `build.ps1`, smoke-checks exe size, uploads artifact |

## Pinned tooling (CI)

| Module | Version (workflow) |
|--------|--------------------|
| Pester | 5.6.1 |
| PSScriptAnalyzer | 1.22.0 |
| ps2exe | 1.0.14 |

## Artifacts

- `TestResults.xml` (NUnit)
- `coverage.xml` (JaCoCo)
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
