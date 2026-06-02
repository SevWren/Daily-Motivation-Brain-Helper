# Contributing

## Reporting Issues
Open an issue on GitHub with:
- Windows version
- PowerShell version (`$PSVersionTable.PSVersion`)
- Steps to reproduce
- Contents of `%TEMP%\DailyMotivation_debug.log`

## Pull Requests
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit with a clear message describing the why, not just the what
4. Open a PR against `main`

## Documentation
All PRD changes require corresponding updates to ACCEPTANCE_CRITERIA.md and TRACEABILITY_MATRIX.md.

## Code Style
- PowerShell: follow existing script conventions in DailyMotivation.ps1
- All diagnostic output must go to the debug log, never to stdout
- ASCII-only characters in PowerShell scripts (no smart quotes, em dashes)
