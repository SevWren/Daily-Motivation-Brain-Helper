#Requires -Version 5.1
<#
.SYNOPSIS
    Compile DailyMotivation.ps1 -> DailyMotivation.exe via PS2EXE
.DESCRIPTION
    Builds the executable with proper error handling and validation.
    Fixes AG16-001, AG16-002, AG16-018.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$InputFile  = Join-Path $PSScriptRoot "DailyMotivation.ps1"
$OutputFile = Join-Path $PSScriptRoot "DailyMotivation.exe"

if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Write-Error "ps2exe module not installed. Run: Install-Module ps2exe -Scope CurrentUser"
    exit 1
}

Write-Host "Building $OutputFile ..."

# AG16-018: Support ShouldProcess for -WhatIf
if ($PSCmdlet.ShouldProcess($OutputFile, "Build executable")) {
    Invoke-ps2exe `
        -inputFile  $InputFile `
        -outputFile $OutputFile `
        -STA `
        -noConsole `
        -title   "Daily Motivation Brain Helper" `
        -version "2.0.0.0" `
        -company "SevWren"

    # AG16-001: Check exit code after Invoke-ps2exe
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed: ps2exe returned exit code $LASTEXITCODE"
        exit 1
    }

    # AG16-002: Validate output file exists and has minimum size
    if (Test-Path $OutputFile) {
        $size = (Get-Item $OutputFile).Length

        # AG16-002: Reject suspiciously small files (likely corrupted)
        $minSizeBytes = 100KB
        if ($size -lt $minSizeBytes) {
            Write-Error "Build failed: output file too small ($size bytes, minimum $minSizeBytes bytes). Likely corrupted."
            exit 1
        }

        Write-Host "Build succeeded. Output: $OutputFile ($([math]::Round($size/1KB, 1)) KB)"
    } else {
        Write-Error "Build failed: output file not found."
        exit 1
    }
}
