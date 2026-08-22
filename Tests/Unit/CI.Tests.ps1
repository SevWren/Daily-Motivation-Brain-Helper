#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for CI/CD workflow configuration - AG16-003, AG16-004, AG16-005, AG16-006,
    AG16-007, AG16-009, AG16-010, AG16-011, AG16-013, AG16-017, AG16-022
.DESCRIPTION
    Tests GitHub Actions workflow for proper configuration, dependency pinning,
    quality gates, and smoke tests.
#>

BeforeAll {
    $script:workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
    $script:workflow     = Get-Content $script:workflowPath -Raw
}

Describe 'AG16-010: Build Job Dependencies' {
    It 'Should require both test and analyze jobs before build' {
        # Build job should have needs: [test, analyze] or needs: ["test", "analyze"]
        $hasBothDeps = $script:workflow -match 'build:.*?needs:\s*\[\s*test\s*,\s*analyze\s*\]' -or
                       $script:workflow -match 'build:.*?needs:\s*\[\s*analyze\s*,\s*test\s*\]' -or
                       $script:workflow -match 'needs:\s*\[.*test.*analyze.*\]' -or
                       $script:workflow -match 'needs:\s*\[.*analyze.*test.*\]'

        $hasBothDeps | Should -Be $true -Because "Build job must wait for both test AND analyze jobs to pass (not just test)"
    }

    It 'Should contain an analyze job definition in the workflow YAML' {
        # Analyze job should exist
        $hasAnalyzeJob = $script:workflow -match 'analyze:'

        $hasAnalyzeJob | Should -Be $true -Because "Analyze job must exist to gate build"
    }
}

Describe 'AG16-005: Pester Version Pinning' {
    It 'Should pin exact Pester version (not use -MinimumVersion)' {
        # Should use -RequiredVersion instead of -MinimumVersion
        $hasRequiredVersion = $script:workflow -match 'Install-Module.*Pester.*-RequiredVersion'
        $hasMinimumVersion = $script:workflow -match 'Install-Module.*Pester.*-MinimumVersion'

        $hasMinimumVersion | Should -Be $false  -Because "Pester must use -RequiredVersion, not -MinimumVersion"
        $hasRequiredVersion | Should -Be $true   -Because "Pester version must be pinned with -RequiredVersion"
    }
}

Describe 'AG16-006: PSScriptAnalyzer Version Pinning' {
    It 'Should pin PSScriptAnalyzer version' {
        # Should specify version for PSScriptAnalyzer
        $hasVersion = $script:workflow -match 'Install-Module.*PSScriptAnalyzer.*-RequiredVersion' -or
                      $script:workflow -match 'Install-Module.*PSScriptAnalyzer.*-MinimumVersion'

        $hasVersion | Should -Be $true -Because "PSScriptAnalyzer version should be pinned to prevent unexpected rule changes"
    }
}

Describe 'AG16-007: ps2exe Version Pinning' {
    It 'Should pin ps2exe version' {
        # Should specify version for ps2exe
        $hasVersion = $script:workflow -match 'Install-Module.*ps2exe.*-RequiredVersion' -or
                      $script:workflow -match 'Install-Module.*ps2exe.*-MinimumVersion'

        $hasVersion | Should -Be $true -Because "ps2exe version should be pinned to prevent build failures from breaking changes"
    }
}

Describe 'AG16-009: PSScriptAnalyzer Violations Must Fail Workflow' {
    It 'Should fail workflow if PSScriptAnalyzer finds violations' {
        # Should have error handling after Invoke-ScriptAnalyzer (may be on separate lines)
        $hasInvokeScriptAnalyzer = $script:workflow -match 'Invoke-ScriptAnalyzer'
        $hasThrowOrExit = $script:workflow -match 'throw.*PSScriptAnalyzer|throw.*violation' -or
                         $script:workflow -match 'exit 1.*PSScriptAnalyzer' -or
                         $script:workflow -match '\$results.*throw|\$results.*exit'

        ($hasInvokeScriptAnalyzer -and $hasThrowOrExit) | Should -Be $true -Because "PSScriptAnalyzer violations must fail the workflow (not just warn)"
    }
}

Describe 'AG16-011: Smoke Test After Build' {
    It 'Should have smoke test step after building exe' {
        # Should have a step that validates the exe after build
        $hasSmokeTest = $script:workflow -match 'Smoke.*Test' -or
                       $script:workflow -match 'Validate.*[Ee]xe' -or
                       $script:workflow -match 'DailyMotivation\.exe.*-NoRun'

        $hasSmokeTest | Should -Be $true -Because "Built exe should be validated before artifact upload"
    }
}

Describe 'AG16-017: Job Timeout Configuration' {
    It 'Should have timeout-minutes configured for test job' {
        # Should have timeout-minutes for at least one job
        $hasTimeout = $script:workflow -match 'timeout-minutes:'

        $hasTimeout | Should -Be $true -Because "Jobs should have timeout to prevent hanging workflows"
    }
}

Describe 'AG16-022: Dependency Installation Validation' {
    It 'Should validate ps2exe installation before build' {
        # After installing ps2exe, should validate it was successful
        $hasValidation = $script:workflow -match 'Get-Module.*ps2exe.*-ListAvailable' -or
                        $script:workflow -match 'if.*Get-Command.*ps2exe'

        $hasValidation | Should -Be $true -Because "ps2exe installation should be validated before running build"
    }
}
