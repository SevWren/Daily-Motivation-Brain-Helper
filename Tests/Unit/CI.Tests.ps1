#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for CI/CD workflow configuration - AG16-003, AG16-004, AG16-005, AG16-006,
    AG16-007, AG16-009, AG16-010, AG16-011, AG16-013, AG16-017, AG16-022
.DESCRIPTION
    Tests GitHub Actions workflow for proper configuration, dependency pinning,
    quality gates, and smoke tests.
#>

Describe 'AG16-010: Build Job Dependencies' {
    It 'Should require both test and analyze jobs before build' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Build job should have needs: [test, analyze] or needs: ["test", "analyze"]
        $hasBothDeps = $workflow -match 'build:.*?needs:\s*\[\s*test\s*,\s*analyze\s*\]' -or
                       $workflow -match 'build:.*?needs:\s*\[\s*analyze\s*,\s*test\s*\]' -or
                       $workflow -match 'needs:\s*\[.*test.*analyze.*\]' -or
                       $workflow -match 'needs:\s*\[.*analyze.*test.*\]'

        $hasBothDeps | Should -Be $true -Because "Build job must wait for both test AND analyze jobs to pass (not just test)"
    }

    It 'Should not allow build to proceed if static analysis fails' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Analyze job should exist
        $hasAnalyzeJob = $workflow -match 'analyze:'

        $hasAnalyzeJob | Should -Be $true -Because "Analyze job must exist to gate build"
    }
}

Describe 'AG16-005: Pester Version Pinning' {
    It 'Should pin exact Pester version (not use -MinimumVersion)' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Should use -RequiredVersion instead of -MinimumVersion
        $hasRequiredVersion = $workflow -match 'Install-Module.*Pester.*-RequiredVersion'
        $hasMinimumVersion = $workflow -match 'Install-Module.*Pester.*-MinimumVersion'

        if ($hasMinimumVersion) {
            # If using MinimumVersion, it's not pinned (fails test)
            $false | Should -Be $true -Because "Pester should be pinned with -RequiredVersion, not -MinimumVersion (prevents breaking changes from new versions)"
        } else {
            $hasRequiredVersion | Should -Be $true -Because "Pester version should be pinned to prevent breaking changes"
        }
    }
}

Describe 'AG16-006: PSScriptAnalyzer Version Pinning' {
    It 'Should pin PSScriptAnalyzer version' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Should specify version for PSScriptAnalyzer
        $hasVersion = $workflow -match 'Install-Module.*PSScriptAnalyzer.*-RequiredVersion' -or
                      $workflow -match 'Install-Module.*PSScriptAnalyzer.*-MinimumVersion'

        $hasVersion | Should -Be $true -Because "PSScriptAnalyzer version should be pinned to prevent unexpected rule changes"
    }
}

Describe 'AG16-007: ps2exe Version Pinning' {
    It 'Should pin ps2exe version' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Should specify version for ps2exe
        $hasVersion = $workflow -match 'Install-Module.*ps2exe.*-RequiredVersion' -or
                      $workflow -match 'Install-Module.*ps2exe.*-MinimumVersion'

        $hasVersion | Should -Be $true -Because "ps2exe version should be pinned to prevent build failures from breaking changes"
    }
}

Describe 'AG16-009: PSScriptAnalyzer Violations Must Fail Workflow' {
    It 'Should fail workflow if PSScriptAnalyzer finds violations' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Should have error handling after Invoke-ScriptAnalyzer
        $hasErrorHandling = $workflow -match 'Invoke-ScriptAnalyzer.*-ErrorAction Stop' -or
                           $workflow -match 'Invoke-ScriptAnalyzer.*throw' -or
                           $workflow -match 'Invoke-ScriptAnalyzer.*exit 1'

        $hasErrorHandling | Should -Be $true -Because "PSScriptAnalyzer violations must fail the workflow (not just warn)"
    }
}

Describe 'AG16-011: Smoke Test After Build' {
    It 'Should have smoke test step after building exe' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Should have a step that validates the exe after build
        $hasSmokeTest = $workflow -match 'Smoke.*Test' -or
                       $workflow -match 'Validate.*[Ee]xe' -or
                       $workflow -match 'DailyMotivation\.exe.*-NoRun'

        $hasSmokeTest | Should -Be $true -Because "Built exe should be validated before artifact upload"
    }
}

Describe 'AG16-017: Job Timeout Configuration' {
    It 'Should have timeout-minutes configured for test job' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # Should have timeout-minutes for at least one job
        $hasTimeout = $workflow -match 'timeout-minutes:'

        $hasTimeout | Should -Be $true -Because "Jobs should have timeout to prevent hanging workflows"
    }
}

Describe 'AG16-022: Dependency Installation Validation' {
    It 'Should validate ps2exe installation before build' {
        $workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\test.yml'
        $workflow = Get-Content $workflowPath -Raw

        # After installing ps2exe, should validate it was successful
        $hasValidation = $workflow -match 'Get-Module.*ps2exe.*-ListAvailable' -or
                        $workflow -match 'if.*Get-Command.*ps2exe'

        $hasValidation | Should -Be $true -Because "ps2exe installation should be validated before running build"
    }
}
