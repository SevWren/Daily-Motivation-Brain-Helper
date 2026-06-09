# Contributing

**Last Reviewed**: 2026-06-09

## Reporting Issues
Open an issue on GitHub with:
- Windows version
- PowerShell version (`$PSVersionTable.PSVersion`)
- Steps to reproduce
- Contents of `%TEMP%\DailyMotivation_debug.log`

## Development Workflow

### Prerequisites
```powershell
# Install development dependencies
Invoke-Build InstallDependencies
```

This installs:
- Pester 5.x (testing framework)
- PSScriptAnalyzer (code quality)
- Invoke-Build (build automation)
- ps2exe (PowerShell to EXE compiler)

### Before Submitting a PR
1. **Run tests**: `.\Invoke-Tests.ps1`
2. **Run static analysis**: `Invoke-Build Analyze`
3. **Check code coverage**: `.\Invoke-Tests.ps1 -CI` (target: 80%+)
4. All tests must pass
5. No PSScriptAnalyzer warnings

### Test-Driven Development
- Add tests for new features in `Tests/Unit/` or `Tests/Integration/`
- Follow existing test patterns (see `Tests/README.md`)
- Integration tests should cover end-to-end scenarios
- Aim for 80%+ code coverage on new modules/functions

## Pull Requests
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. **Write tests first** (TDD approach recommended)
4. Implement feature with tests passing
5. Run full test suite and static analysis
6. Commit with a clear message describing the why, not just the what
7. Open a PR against `main`

## Documentation
All PRD changes require corresponding updates to ACCEPTANCE_CRITERIA.md and TRACEABILITY_MATRIX.md.

## Code Quality Standards
- All code must pass PSScriptAnalyzer with project settings (`.PSScriptAnalyzerSettings.psd1`)
- New functions require Pester tests (minimum 80% coverage)
- Follow PowerShell best practices (see `TESTING.md`)
- No cmdlet aliases except 'cd', 'ls'
- 4-space indentation (no tabs)
- UTF-8 encoding for all files
- Comment-based help for exported functions

## Code Style
- PowerShell: follow existing script conventions in modules
- All diagnostic output must go to the debug log, never to stdout
- ASCII-only characters in PowerShell scripts (no smart quotes, em dashes)
- Use `Set-StrictMode -Version Latest` in entry points
- Use `$ErrorActionPreference = "Stop"` in entry points
- Explicit `-ErrorAction Stop` in module functions

## Build System
```powershell
Invoke-Build              # Full build with tests
Invoke-Build QuickBuild   # Build without tests
Invoke-Build Release      # Create release package
Invoke-Build Clean        # Remove build artifacts
Invoke-Build Analyze      # Run PSScriptAnalyzer only
Invoke-Build Test         # Run tests only
```

See `.build.ps1` for all available tasks and `TESTING.md` for detailed testing guide.
