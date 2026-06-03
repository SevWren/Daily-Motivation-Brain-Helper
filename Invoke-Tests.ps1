#Requires -Version 5.1
#Requires -Modules Pester
<#
.SYNOPSIS
    Runs all Pester tests for Daily Motivation Brain Helper

.DESCRIPTION
    Executes unit and integration tests using Pester 5.x with code coverage analysis.
    Supports filtering by tags, generating reports, and CI/CD integration.

.PARAMETER Tag
    Run only tests with specified tags (e.g., 'Unit', 'Integration', 'Initialization')

.PARAMETER ExcludeTag
    Exclude tests with specified tags

.PARAMETER CI
    Run in CI mode: exits with error code on test failures, generates reports

.PARAMETER Coverage
    Enable code coverage analysis (default: $true)

.EXAMPLE
    .\Invoke-Tests.ps1
    Runs all tests with code coverage

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag Unit
    Runs only unit tests

.EXAMPLE
    .\Invoke-Tests.ps1 -CI
    Runs all tests in CI mode with reports

.EXAMPLE
    .\Invoke-Tests.ps1 -Tag Integration -ExcludeTag Slow
    Runs integration tests excluding slow tests
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Tag,

    [Parameter()]
    [string[]]$ExcludeTag,

    [Parameter()]
    [switch]$CI,

    [Parameter()]
    [bool]$Coverage = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure we're in the repo root
$RepoRoot = $PSScriptRoot
Push-Location $RepoRoot

try {
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Daily Motivation Brain Helper - Test Suite" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Check Pester version
    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule) {
        throw "Pester module not found. Install with: Install-Module -Name Pester -Force -SkipPublisherCheck"
    }

    Write-Host "Using Pester version: $($pesterModule.Version)" -ForegroundColor Green

    if ($pesterModule.Version.Major -lt 5) {
        Write-Warning "Pester 5.x or higher is recommended. Current version: $($pesterModule.Version)"
    }

    # Import Pester
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

    # Load configuration
    $configPath = Join-Path $RepoRoot 'PesterConfiguration.psd1'
    if (Test-Path $configPath) {
        $configData = Import-PowerShellDataFile -Path $configPath
    } else {
        Write-Warning "PesterConfiguration.psd1 not found, using defaults"
        $configData = @{}
    }

    # Build Pester configuration
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $RepoRoot 'Tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'

    # Apply tag filters
    if ($Tag) {
        $config.Filter.Tag = $Tag
        Write-Host "Filtering by tags: $($Tag -join ', ')" -ForegroundColor Yellow
    }

    if ($ExcludeTag) {
        $config.Filter.ExcludeTag = $ExcludeTag
        Write-Host "Excluding tags: $($ExcludeTag -join ', ')" -ForegroundColor Yellow
    }

    # CI mode configuration
    if ($CI) {
        Write-Host "Running in CI mode" -ForegroundColor Yellow
        $config.Run.Exit = $true
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = Join-Path $RepoRoot 'TestResults.xml'
    }

    # Code coverage configuration
    if ($Coverage) {
        Write-Host "Code coverage analysis enabled" -ForegroundColor Yellow
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = @(
            (Join-Path $RepoRoot 'src\Modules\*.psm1')
        )
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
        $config.CodeCoverage.OutputPath = Join-Path $RepoRoot 'coverage.xml'
    }

    Write-Host ""
    Write-Host "Starting test execution..." -ForegroundColor Cyan
    Write-Host ""

    # Run tests
    $result = Invoke-Pester -Configuration $config

    # Display results
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Test Results Summary" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "Total Tests:  $($result.TotalCount)" -ForegroundColor White
    Write-Host "Passed:       $($result.PassedCount)" -ForegroundColor Green
    Write-Host "Failed:       $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Skipped:      $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "Duration:     $($result.Duration)" -ForegroundColor White

    if ($Coverage -and $result.CodeCoverage) {
        $coveragePercent = [math]::Round(($result.CodeCoverage.CoveredPercent), 2)
        $coverageColor = switch ($coveragePercent) {
            { $_ -ge 80 } { 'Green' }
            { $_ -ge 60 } { 'Yellow' }
            default { 'Red' }
        }

        Write-Host ""
        Write-Host "Code Coverage: $coveragePercent%" -ForegroundColor $coverageColor
        Write-Host "  Lines Covered:   $($result.CodeCoverage.CoveredCommands) / $($result.CodeCoverage.CommandCount)" -ForegroundColor White
    }

    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Output report locations
    if ($CI) {
        Write-Host "Test results saved to: TestResults.xml" -ForegroundColor Green
        if ($Coverage) {
            Write-Host "Coverage report saved to: coverage.xml" -ForegroundColor Green
        }
    }

    # Exit with error code if tests failed
    if ($result.FailedCount -gt 0) {
        Write-Host "❌ TESTS FAILED" -ForegroundColor Red
        if ($CI) {
            exit 1
        }
    } else {
        Write-Host "✅ ALL TESTS PASSED" -ForegroundColor Green
        if ($CI) {
            exit 0
        }
    }

} finally {
    Pop-Location
}
