#Requires -Version 7.0
#Requires -Modules Pester
<#
.SYNOPSIS
    Runs all Pester tests for Daily Motivation Brain Helper (Windows & Linux compatible).

.PARAMETER Tag
    Run only tests with specified tags.

.PARAMETER ExcludeTag
    Exclude tests with specified tags.

.PARAMETER CI
    CI mode: exit with error code on test failure, generate XML reports.

.PARAMETER Coverage
    Enable code coverage analysis (default: $true).

.PARAMETER LogOutput
    Capture all terminal output to a timestamped log file under the project's
    'output\' directory (default: $true). Use -LogOutput $false to disable.

.EXAMPLE
    .\Invoke-Tests.ps1
    Runs all tests with code coverage, logging console output to output\.

.EXAMPLE
    .\Invoke-Tests.ps1 -Coverage $false
    Runs all tests without code coverage; console output is still logged to output\.

.EXAMPLE
    .\Invoke-Tests.ps1 -CI -Coverage $true
    Runs in CI mode with coverage report.

.NOTES
    Runs on both Windows PowerShell/pwsh (Windows) and pwsh (Linux/macOS).
    Requires PowerShell 7+ so it matches DailyMotivation.ps1's runtime target
    and runs identically on Linux and Windows.
#>
[CmdletBinding()]
param(
    [string[]]$Tag,
    [string[]]$ExcludeTag,
    [switch]$CI,
    [bool]$Coverage = $true,
    [bool]$LogOutput = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
Push-Location $RepoRoot

# Track whether we actually started a transcript, so we only stop one we started.
$transcriptStarted = $false
$transcriptPath = $null

try {
    if ($LogOutput) {
        # Use a path-safe, cross-platform timestamp (no colons, works on Windows & Linux).
        $timestamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
        $outputDir   = Join-Path $RepoRoot 'output'
        if (-not (Test-Path -LiteralPath $outputDir)) {
            $null = New-Item -ItemType Directory -Path $outputDir -Force
        }
        $transcriptPath = Join-Path $outputDir "TestRun_$timestamp.log"

        try {
            Start-Transcript -Path $transcriptPath -Force | Out-Null
            $transcriptStarted = $true
        } catch {
            Write-Warning "Could not start transcript logging: $($_.Exception.Message)"
        }
    }

    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Daily Motivation Brain Helper - Test Suite" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " Platform: $([System.Environment]::OSVersion.Platform) | PSVersion: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray

    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule) {
        throw "Pester not found. Install with: Install-Module -Name Pester -Force -SkipPublisherCheck"
    }
    Write-Host "Using Pester $($pesterModule.Version)" -ForegroundColor Green
    if ($pesterModule.Version.Major -lt 5) {
        Write-Warning "Pester 5.x+ recommended. Found: $($pesterModule.Version)"
    }

    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

    # Story 2.3: Parse DailyMotivation.ps1 for syntax errors before running Pester.
    # A syntax error produces an opaque Pester crash without this check.
    $scriptPath = Join-Path $RepoRoot 'DailyMotivation.ps1'
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptPath, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        Write-Host "SYNTAX ERROR in DailyMotivation.ps1:" -ForegroundColor Red
        $parseErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "DailyMotivation.ps1 syntax OK" -ForegroundColor Green

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

    # Story 2.4: Enforce coverage threshold in CI mode.
    # $CoverageThreshold aligned with the 70% minimum in the CI coverage-gate job.
    $CoverageThreshold = 70
    if ($CI -and $Coverage -and $null -ne $result.CodeCoverage) {
        $pct = [math]::Round($result.CodeCoverage.CoveragePercent, 1)
        Write-Host ""
        Write-Host "Code coverage: $pct% (threshold: $CoverageThreshold%)" -ForegroundColor $(
            if ($pct -lt $CoverageThreshold) { 'Red' } else { 'Green' })
        if ($pct -lt $CoverageThreshold) {
            Write-Host "COVERAGE BELOW THRESHOLD: $pct% < $CoverageThreshold%" -ForegroundColor Red
            exit 1
        }
    }

    if ($result.FailedCount -gt 0) {
        Write-Host "TESTS FAILED" -ForegroundColor Red
        if ($CI) { exit 1 }
    } else {
        Write-Host "ALL TESTS PASSED" -ForegroundColor Green
        if ($CI) { exit 0 }
    }
}
finally {
    if ($transcriptStarted) {
        try {
            Stop-Transcript | Out-Null
            Write-Host "Console output logged to: $transcriptPath" -ForegroundColor DarkGray
        } catch {
            # Transcript may already have been stopped (e.g. by an inner error path).
        }
    }
    Pop-Location
}
