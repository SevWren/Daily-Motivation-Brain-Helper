#Requires -Version 5.1
#Requires -Modules Pester
<#
.SYNOPSIS
    Runs all Pester tests for Daily Motivation Brain Helper.

.PARAMETER Tag
    Run only tests with specified tags.

.PARAMETER ExcludeTag
    Exclude tests with specified tags.

.PARAMETER CI
    CI mode: exit with error code on test failure, generate XML reports.

.PARAMETER Coverage
    Enable code coverage analysis (default: $true).

.EXAMPLE
    .\Invoke-Tests.ps1
    Runs all tests with code coverage.

.EXAMPLE
    .\Invoke-Tests.ps1 -CI -Coverage $true
    Runs in CI mode with coverage report.
#>
[CmdletBinding()]
param(
    [string[]]$Tag,
    [string[]]$ExcludeTag,
    [switch]$CI,
    [bool]$Coverage = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
Push-Location $RepoRoot

try {
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Daily Motivation Brain Helper - Test Suite" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan

    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule) {
        throw "Pester not found. Install with: Install-Module -Name Pester -Force -SkipPublisherCheck"
    }
    Write-Host "Using Pester $($pesterModule.Version)" -ForegroundColor Green
    if ($pesterModule.Version.Major -lt 5) {
        Write-Warning "Pester 5.x+ recommended. Found: $($pesterModule.Version)"
    }

    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

    $config = New-PesterConfiguration
    $config.Run.Path    = Join-Path $RepoRoot 'Tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'

    if ($Tag)        { $config.Filter.Tag        = $Tag }
    if ($ExcludeTag) { $config.Filter.ExcludeTag = $ExcludeTag }

    if ($CI) {
        $config.Run.Exit = $true
        $config.TestResult.Enabled      = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath   = Join-Path $RepoRoot 'TestResults.xml'
    }

    if ($Coverage) {
        $config.CodeCoverage.Enabled      = $true
        $config.CodeCoverage.Path         = @(Join-Path $RepoRoot 'DailyMotivation.ps1')
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
        $config.CodeCoverage.OutputPath   = Join-Path $RepoRoot 'coverage.xml'
    }

    $result = Invoke-Pester -Configuration $config

    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Results: Passed=$($result.PassedCount)  Failed=$($result.FailedCount)  Skipped=$($result.SkippedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "=====================================================================" -ForegroundColor Cyan

    if ($result.FailedCount -gt 0) {
        Write-Host "TESTS FAILED" -ForegroundColor Red
        if ($CI) { exit 1 }
    } else {
        Write-Host "ALL TESTS PASSED" -ForegroundColor Green
        if ($CI) { exit 0 }
    }
}
finally {
    Pop-Location
}
