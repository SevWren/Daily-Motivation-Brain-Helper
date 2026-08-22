#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for build.ps1 script - AG16-001, AG16-002
.DESCRIPTION
    Tests that build script properly validates Invoke-ps2exe exit codes
    and fails fast when compilation errors occur.
#>

Describe 'AG16-001: Invoke-ps2exe Exit Code Validation' {
    It 'Should check exit code after Invoke-ps2exe command' {
        $buildScript = Get-Content (Join-Path $PSScriptRoot '..\..\build.ps1') -Raw

        # Should check $LASTEXITCODE after Invoke-ps2exe
        $hasExitCodeCheck = $buildScript -match '\$LASTEXITCODE'

        $hasExitCodeCheck | Should -Be $true -Because "Build script must check exit code to detect ps2exe compilation failures"
    }

    It 'Should exit with error if Invoke-ps2exe returns non-zero exit code' {
        $buildScript = Get-Content (Join-Path $PSScriptRoot '..\..\build.ps1') -Raw

        # Should have pattern like: if ($LASTEXITCODE -ne 0) { exit 1 }
        $hasExitOnFailure = $buildScript -match 'if.*\$LASTEXITCODE.*-ne\s*0.*exit\s+1' -or
                            $buildScript -match 'if.*\$LASTEXITCODE.*-gt\s*0.*exit' -or
                            $buildScript -match '\$LASTEXITCODE.*throw|exit\s+\$LASTEXITCODE'

        $hasExitOnFailure | Should -Be $true -Because "Build must fail fast when ps2exe compilation fails"
    }
}

Describe 'AG16-002: Build Output Validation' {
    It 'Should validate output file size before declaring success' {
        $buildScript = Get-Content (Join-Path $PSScriptRoot '..\..\build.ps1') -Raw

        # Should check file size (not just existence)
        $hasFileSizeCheck = $buildScript -match 'Get-Item.*\.Length' -or
                           $buildScript -match '\(.*\)\.Length\s*-[lg][te]'

        $hasFileSizeCheck | Should -Be $true -Because "Build must validate exe is not empty or corrupted"
    }

    It 'Should reject output files smaller than minimum expected size (100KB)' {
        $buildScript = Get-Content (Join-Path $PSScriptRoot '..\..\build.ps1') -Raw

        # Should have minimum size validation
        $hasMinSizeValidation = $buildScript -match '\.Length\s*-lt\s*\d+' -or
                               $buildScript -match 'if\s*\(\$size\s*-lt'

        $hasMinSizeValidation | Should -Be $true -Because "Build must reject suspiciously small exe files (likely corrupted)"
    }
}

Describe 'AG16-018: Build Script Parameter Support' {
    It 'Should support CmdletBinding for ShouldProcess' {
        $buildScript = Get-Content (Join-Path $PSScriptRoot '..\..\build.ps1') -Raw

        # Should have [CmdletBinding()] at top
        $hasCmdletBinding = $buildScript -match '\[CmdletBinding\('

        $hasCmdletBinding | Should -Be $true -Because "Build script should support -WhatIf and -Confirm for safety"
    }
}
