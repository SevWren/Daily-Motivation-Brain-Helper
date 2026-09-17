#Requires -Version 5.1
<#
.SYNOPSIS
    STA Harness — runs Pester tests tagged 'WPF' inside an STA runspace.

.DESCRIPTION
    WPF requires the Single-Threaded Apartment (STA) model. Standard Pester
    runs on an MTA thread and cannot instantiate WPF windows. This wrapper
    creates an STA runspace, runs Pester on Tests/WPF/ with -Tag WPF inside
    it, and emits coverage-wpf.xml (when -Coverage $true).

    Called by Invoke-Tests.ps1 on windows-latest. Skipped on non-Windows.

.PARAMETER RepoRoot
    Absolute path to the repository root. Defaults to two levels above this file.

.PARAMETER Coverage
    Enable JaCoCo code coverage output (default: $true).

.PARAMETER CI
    CI mode: emit TestResults-WPF.xml and exit with non-zero on failure.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [bool]$Coverage   = $true,
    [switch]$CI
)

if (-not $IsWindows) {
    Write-Host "Invoke-STAPester: skipped on non-Windows." -ForegroundColor Yellow
    exit 0
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host " WPF Smoke Tests (STA Harness)" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

$runspace = $null
$ps       = $null
try {
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = [System.Threading.ApartmentState]::STA
    $runspace.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $runspace.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace

    [void]$ps.AddScript({
        param($RepoRoot, $Coverage, $CI)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

        $config = New-PesterConfiguration
        $config.Run.Path     = Join-Path $RepoRoot 'Tests\WPF'
        $config.Filter.Tag   = @('WPF')
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Detailed'

        if ($CI) {
            $config.TestResult.Enabled      = $true
            $config.TestResult.OutputFormat = 'NUnitXml'
            $config.TestResult.OutputPath   = Join-Path $RepoRoot 'TestResults-WPF.xml'
        }

        if ($Coverage) {
            $config.CodeCoverage.Enabled      = $true
            $config.CodeCoverage.Path         = @(Join-Path $RepoRoot 'DailyMotivation.ps1')
            $config.CodeCoverage.OutputFormat = 'JaCoCo'
            $config.CodeCoverage.OutputPath   = Join-Path $RepoRoot 'coverage-wpf.xml'
        }

        return Invoke-Pester -Configuration $config
    })

    [void]$ps.AddParameter('RepoRoot', $RepoRoot)
    [void]$ps.AddParameter('Coverage', $Coverage)
    [void]$ps.AddParameter('CI',       $CI.IsPresent)

    $results = $ps.Invoke()

    if ($ps.HadErrors) {
        $ps.Streams.Error | ForEach-Object { Write-Error $_.ToString() }
        exit 1
    }

    $pesterResult = $results[0]
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host " WPF Results: Passed=$($pesterResult.PassedCount)  Failed=$($pesterResult.FailedCount)  Skipped=$($pesterResult.SkippedCount)" `
        -ForegroundColor $(if ($pesterResult.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "=====================================================================" -ForegroundColor Cyan

    exit $(if ($pesterResult.FailedCount -gt 0) { 1 } else { 0 })
}
finally {
    if ($ps)       { $ps.Dispose() }
    if ($runspace) { $runspace.Close(); $runspace.Dispose() }
}
