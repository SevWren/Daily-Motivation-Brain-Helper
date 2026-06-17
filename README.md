# Daily Motivation Brain Helper

A Windows desktop utility that pops up a motivational message and opens a chosen folder in Explorer at a scheduled time — helping you start focused work sessions.

## Usage

Download `DailyMotivation.exe` and double-click it. No installation required. No companion files needed.

## Build from Source

**Requirements:** Windows 10/11, PowerShell 5.1, .NET Framework 4.5+

```powershell
# 1. Install ps2exe (once)
Install-Module ps2exe -Scope CurrentUser

# 2. Compile
.\build.ps1
```

The output is a single self-contained `DailyMotivation.exe`.

## Run Tests

```powershell
Install-Module Pester -Force -SkipPublisherCheck
.\Invoke-Tests.ps1
```

## License

MIT — see [LICENSE](LICENSE)
