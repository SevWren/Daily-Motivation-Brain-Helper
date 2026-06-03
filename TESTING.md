# Testing Guide - Daily Motivation Brain Helper

This guide covers the modern PowerShell testing infrastructure for this project.

## Quick Start

### Prerequisites

```powershell
# Install required modules
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
Install-Module -Name InvokeBuild -Scope CurrentUser

# Or use the build script
Invoke-Build InstallDependencies
```

### Run All Tests

```powershell
# Simple test run
.\Invoke-Tests.ps1

# With verbose output
.\Invoke-Tests.ps1 -Verbose

# CI mode (generates reports)
.\Invoke-Tests.ps1 -CI
```

### Run Specific Test Suites

```powershell
# Unit tests only
.\Invoke-Tests.ps1 -Tag Unit

# Integration tests only
.\Invoke-Tests.ps1 -Tag Integration

# Initialization tests (Issues #2-#8)
.\Invoke-Tests.ps1 -Tag Initialization
```

## Test Infrastructure

### Test Organization

```
Tests/
├── Unit/                          # Fast, isolated unit tests
│   ├── ConfigManager.Tests.ps1    # Tests for ConfigManager module
│   └── TaskScheduler.Tests.ps1    # Tests for TaskScheduler module
│
├── Integration/                   # End-to-end integration tests
│   └── Initialization.Tests.ps1   # Initialization system tests
│
└── Fixtures/                      # Test data
    ├── sample_app_settings.json
    └── sample_tasks.json
```

### Test Categories

| Category | Description | Examples |
|----------|-------------|----------|
| **Unit** | Test individual functions in isolation | ConfigManager functions, TaskScheduler functions |
| **Integration** | Test complete workflows | Full initialization, task creation + scheduling |
| **Initialization** | Test app startup and directory creation (Issues #2-#8) | Fresh install, AppData creation |
| **PathResolution** | Test $PSScriptRoot and path resolution (Issue #3) | Module loading, PS2EXE paths |
| **ErrorHandling** | Test error cases and recovery (Issue #6) | Corrupted configs, missing files |
| **Encoding** | Test UTF-8 encoding preservation | Unicode paths, emoji in config |

## Build System

This project uses **Invoke-Build** for modern PowerShell build automation.

### Build Tasks

```powershell
# View all available tasks
Invoke-Build ?

# Default build (Clean -> Analyze -> Test -> Build)
Invoke-Build

# Individual tasks
Invoke-Build Clean          # Clean output directory
Invoke-Build Analyze        # Run PSScriptAnalyzer
Invoke-Build Test           # Run Pester tests
Invoke-Build Build          # Build EXE files
Invoke-Build Package        # Create release ZIP

# Combined tasks
Invoke-Build TestUnit       # Run only unit tests
Invoke-Build TestIntegration # Run only integration tests
Invoke-Build QuickBuild     # Clean + Build (skip tests)
Invoke-Build Release        # Full release build + package
```

### Build Configuration

Build configuration is in `.build.ps1`:

```powershell
# Show current build configuration
Invoke-Build ShowConfig
```

## Code Quality

### PSScriptAnalyzer

Static analysis runs automatically during build:

```powershell
# Run analyzer manually
Invoke-Build Analyze

# Or directly
Invoke-ScriptAnalyzer -Path src -Recurse -Settings .PSScriptAnalyzerSettings.psd1
```

Configuration: `.PSScriptAnalyzerSettings.psd1`

**Rules enforced:**
- No cmdlet aliases (except 'cd', 'ls')
- Consistent indentation (4 spaces)
- Consistent brace placement
- UTF-8 encoding
- Comment-based help
- No global variables
- ShouldProcess for state-changing functions

### Code Coverage

Target: **80%+ coverage**

Coverage is calculated for:
- `src/Modules/ConfigManager.psm1`
- `src/Modules/TaskScheduler.psm1`

```powershell
# Run tests with coverage
.\Invoke-Tests.ps1 -Coverage $true

# View coverage.xml in CI tools or:
# https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters
```

## Writing Tests

### Test Structure (Pester 5.x)

```powershell
#Requires -Modules Pester

BeforeAll {
    # Runs once before all tests in this file
    Import-Module $PSScriptRoot\..\..\src\Modules\YourModule.psm1 -Force
}

AfterAll {
    # Runs once after all tests
    # Clean up any test artifacts
}

Describe 'Feature Name' {
    BeforeAll {
        # Runs once before all tests in this Describe block
    }

    Context 'When condition X' {
        BeforeEach {
            # Runs before EACH test in this Context
        }

        AfterEach {
            # Runs after EACH test in this Context
        }

        It 'Should do Y' {
            # Arrange
            $input = 'test value'

            # Act
            $result = Your-Function -Input $input

            # Assert
            $result | Should -Be 'expected value'
        }

        It 'Should do Z' {
            # Another test
        }
    }

    Context 'When condition Y' {
        # More tests
    }
}
```

### Test Best Practices

1. **One assertion per test** (where possible)
2. **Arrange-Act-Assert pattern**
3. **Descriptive test names** (`It 'Should create directory when it does not exist'`)
4. **Independent tests** (no shared state)
5. **Fast tests** (< 1 second for unit tests)
6. **Clean up** (remove temp files in AfterEach/AfterAll)
7. **Use fixtures** (avoid hardcoded test data)

### Mocking

```powershell
# Mock a command
BeforeAll {
    Mock Show-ErrorDialog { }
}

# Mock with specific parameter
Mock New-Item { } -ParameterFilter { $Path -eq 'C:\Test' }

# Verify mock was called
Should -Invoke Show-ErrorDialog -Times 1 -Exactly
```

### Testing Private Functions

```powershell
# Dot-source the module to access private functions
BeforeAll {
    . $PSScriptRoot\..\..\src\Modules\YourModule.psm1
}

It 'Should test private function' {
    Private-Function | Should -Be 'expected'
}
```

## Continuous Integration

### GitHub Actions

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

**Workflow**: `.github/workflows/test.yml`

**Jobs:**
1. **test**: Run all tests with code coverage
2. **build**: Build executables
3. **analyze**: Static analysis with PSScriptAnalyzer

### Local CI Simulation

```powershell
# Simulate CI environment
.\Invoke-Tests.ps1 -CI

# Full release build (what CI does)
Invoke-Build Release
```

## Debugging Tests

### Run Single Test File

```powershell
Invoke-Pester -Path Tests/Unit/ConfigManager.Tests.ps1 -Output Detailed
```

### Run Specific Test

```powershell
# By full name
Invoke-Pester -Path Tests/Unit/ConfigManager.Tests.ps1 `
              -FullNameFilter "*Initialize-AppData*"

# By tag
Invoke-Pester -Path Tests/ -Tag Initialization
```

### Interactive Debugging

```powershell
# Set breakpoint in test file
Set-PSBreakpoint -Script Tests/Unit/ConfigManager.Tests.ps1 -Line 50

# Run test
Invoke-Pester -Path Tests/Unit/ConfigManager.Tests.ps1

# Or use VS Code with PowerShell extension and F5
```

### Verbose Output

```powershell
.\Invoke-Tests.ps1 -Verbose

# Or
$VerbosePreference = 'Continue'
Invoke-Pester -Path Tests/Unit/ConfigManager.Tests.ps1
```

## Test Coverage for Initialization Bugs

The test suite specifically addresses issues documented in **GitHub Issues #2-#8**:

### Issue #2: Initialize-AppData not creating directory
**Tests:**
- `Tests/Unit/ConfigManager.Tests.ps1` → `Initialize-AppData` describe block
- `Tests/Integration/Initialization.Tests.ps1` → Fresh installation tests

### Issue #3: $PSScriptRoot resolution in PS2EXE
**Tests:**
- `Tests/Integration/Initialization.Tests.ps1` → Path resolution tests
- Manual testing required after EXE build

### Issue #4: Module import order
**Tests:**
- `Tests/Integration/Initialization.Tests.ps1` → Module import order tests

### Issue #5: DailyMotivation.ps1 initialization
**Tests:**
- `Tests/Integration/Initialization.Tests.ps1` → Standalone initialization tests
- Currently marked `-Skip` until fix implemented

### Issue #6: Silent exit behavior
**Tests:**
- `Tests/Integration/Initialization.Tests.ps1` → Error handling tests
- Some marked `-Skip` (UI dialogs can't be tested in CI)

### Issue #7: %TEMP% fallback
**Tests:**
- `Tests/Unit/ConfigManager.Tests.ps1` → Fallback tests
- Currently marked `-Skip` (pending fallback strategy decision)

## Common Testing Scenarios

### Test Fresh Installation

```powershell
# Delete AppData directory
Remove-Item "$env:APPDATA\DailyMotivationBrainHelper" -Recurse -Force

# Run initialization tests
.\Invoke-Tests.ps1 -Tag Initialization
```

### Test Corrupted Config Recovery

```powershell
# Run integration tests that corrupt files
.\Invoke-Tests.ps1 -Tag ErrorHandling
```

### Test UTF-8 Encoding

```powershell
# Run encoding tests
.\Invoke-Tests.ps1 -Tag Encoding
```

### Test Specific Module

```powershell
# ConfigManager only
Invoke-Pester -Path Tests/Unit/ConfigManager.Tests.ps1

# TaskScheduler only
Invoke-Pester -Path Tests/Unit/TaskScheduler.Tests.ps1
```

## Troubleshooting

### "Pester module not found"

```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
```

### "Tests pass locally but fail in CI"

- Check Windows Task Scheduler availability (CI may not have it)
- Verify test isolation (no shared state)
- Check for hardcoded paths

### "Code coverage not generated"

```powershell
# Ensure coverage is enabled
.\Invoke-Tests.ps1 -Coverage $true

# Check that module paths exist
Test-Path src/Modules/*.psm1
```

### "PSScriptAnalyzer errors"

```powershell
# Run analyzer to see issues
Invoke-Build Analyze

# Fix formatting issues automatically (where possible)
Invoke-Formatter -ScriptDefinition (Get-Content src/YourScript.ps1 -Raw)
```

## Resources

- [Pester Documentation](https://pester.dev/)
- [PSScriptAnalyzer Rules](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/readme)
- [Invoke-Build Documentation](https://github.com/nightroman/Invoke-Build)
- [PowerShell Best Practices](https://poshcode.gitbook.io/powershell-practice-and-style/)

## Contributing

When contributing:

1. **Write tests first** (TDD)
2. **Run full test suite** before submitting PR
3. **Maintain or improve code coverage**
4. **Fix PSScriptAnalyzer warnings**
5. **Update tests for bug fixes**
6. **Document new test fixtures**

```powershell
# Before submitting PR
Invoke-Build

# This runs:
# - Clean
# - PSScriptAnalyzer
# - All tests with coverage
# - Build executables
```
