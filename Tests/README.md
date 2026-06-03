# Test Suite - Daily Motivation Brain Helper

Comprehensive test suite using Pester 5.x with unit and integration tests.

## Directory Structure

```
Tests/
├── Unit/                     # Unit tests for individual modules
│   ├── ConfigManager.Tests.ps1
│   └── TaskScheduler.Tests.ps1
├── Integration/             # Integration tests for end-to-end scenarios
│   └── Initialization.Tests.ps1
├── Fixtures/                # Test data and sample files
│   ├── sample_app_settings.json
│   └── sample_tasks.json
└── README.md
```

## Running Tests

### All Tests
```powershell
.\Invoke-Tests.ps1
```

### Unit Tests Only
```powershell
.\Invoke-Tests.ps1 -Tag Unit
```

### Integration Tests Only
```powershell
.\Invoke-Tests.ps1 -Tag Integration
```

### Specific Tags
```powershell
.\Invoke-Tests.ps1 -Tag Initialization
.\Invoke-Tests.ps1 -Tag ErrorHandling
```

### CI Mode
```powershell
.\Invoke-Tests.ps1 -CI
# Generates TestResults.xml and coverage.xml
```

### Without Code Coverage
```powershell
.\Invoke-Tests.ps1 -Coverage $false
```

## Using Invoke-Build

### Run Tests via Build Script
```powershell
Invoke-Build Test
Invoke-Build TestUnit
Invoke-Build TestIntegration
```

### Full Build with Tests
```powershell
Invoke-Build
# Runs: Clean -> Analyze -> Test -> Build
```

## Test Tags

Tests are tagged for easy filtering:

- **Unit**: Unit tests for individual functions
- **Integration**: End-to-end integration tests
- **Initialization**: Tests for app initialization system (Issues #2-#8)
- **PathResolution**: Tests for path resolution in PS2EXE
- **ErrorHandling**: Tests for error handling and recovery
- **Encoding**: UTF-8 encoding tests
- **E2E**: Complete end-to-end scenarios

## Prerequisites

### Required Modules
```powershell
# Install required modules
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

### Using Build Script
```powershell
# Install all dependencies automatically
Invoke-Build InstallDependencies
```

## Code Coverage

Code coverage is enabled by default and covers:
- `src/Modules/ConfigManager.psm1`
- `src/Modules/TaskScheduler.psm1`

Coverage reports are generated in JaCoCo format: `coverage.xml`

Target coverage: **80%+**

## Writing New Tests

### Unit Test Template

```powershell
#Requires -Modules Pester

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\src\Modules\YourModule.psm1') -Force
}

Describe 'Your-Function' {
    Context 'When condition X' {
        It 'Should do Y' {
            # Arrange
            $input = 'test'

            # Act
            $result = Your-Function -Input $input

            # Assert
            $result | Should -Be 'expected'
        }
    }
}
```

### Integration Test Template

```powershell
#Requires -Modules Pester

BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot '..\..\'
}

Describe 'Feature Integration' -Tag 'Integration' {
    Context 'When doing end-to-end operation' {
        BeforeEach {
            # Setup test environment
        }

        It 'Should complete full workflow' {
            # Test complete feature flow
        }
    }
}
```

## Continuous Integration

### GitHub Actions

The `.github/workflows/test.yml` workflow runs tests on every push and PR.

### Local CI Simulation

```powershell
.\Invoke-Tests.ps1 -CI
# Mimics CI environment
```

## Test Data

### Fixtures

The `Fixtures/` directory contains sample data files:
- `sample_app_settings.json`: Sample application settings
- `sample_tasks.json`: Sample scheduled tasks

Use these in tests to avoid hardcoding test data.

### Temporary Directories

Tests create temporary directories for isolation:
```powershell
$testDir = Join-Path ([System.IO.Path]::GetTempPath()) "Test_$(New-Guid)"
```

Always clean up in `AfterAll` blocks.

## Debugging Tests

### Run Single Test
```powershell
Invoke-Pester -Path Tests/Unit/ConfigManager.Tests.ps1 -Output Detailed
```

### Run Specific Test Block
```powershell
Invoke-Pester -Path Tests/Unit/ConfigManager.Tests.ps1 -FullNameFilter "*Initialize-AppData*"
```

### Verbose Output
```powershell
.\Invoke-Tests.ps1 -Verbose
```

## Known Issues and Skipped Tests

Some tests are marked `-Skip` for the following reasons:

### ConfigManager Tests
- **%TEMP% fallback test**: Requires mocking `New-Item` which is complex in Pester 5
  - Will be implemented when fallback strategy is finalized (Issue #7)

### TaskScheduler Tests
- **Windows Task Scheduler integration**: Requires administrative privileges
  - Covered in integration test suite with manual testing

### Integration Tests
- **DailyMotivation.ps1 initialization**: Depends on Issue #5 fix
- **Error dialog tests**: Cannot test UI dialogs in non-interactive context
- **PS2EXE path resolution**: Requires building EXE and testing

## Contributing Tests

When fixing bugs or adding features:

1. **Add failing test first** (TDD approach)
2. **Implement fix**
3. **Verify test passes**
4. **Update related integration tests**
5. **Check code coverage** (should not decrease)

All tests should:
- Have clear descriptive names
- Test one thing per `It` block
- Clean up after themselves
- Be independent (no shared state between tests)
- Run quickly (< 1 second per test for unit tests)

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Project conventions
- [INITIALIZATION-BUGS.md](../INITIALIZATION-BUGS.md) - Bug analysis and test requirements
- [GitHub Issues #2-#8](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues) - Initialization system fixes
