#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for AG17-002: Register-ContextMenu verifies that registry keys were
    successfully created after write operations and returns a structured result object.
#>

BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG17-002: Context Menu Registration Verification" {
    Context "Register-ContextMenu source code structure" {
        BeforeAll {
            $script:content = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw

            $funcStart           = $script:content.IndexOf('function Register-ContextMenu')
            $funcEnd             = $script:content.IndexOf('function Unregister-ContextMenu', $funcStart)
            $script:funcBody     = $script:content.Substring($funcStart, $funcEnd - $funcStart)
        }

        It "Should verify verbKey exists with Test-Path after writing it" {
            $script:funcBody | Should -Match 'Test-Path \$verbKey' `
                -Because "Register-ContextMenu must call Test-Path on verbKey after Set-ItemProperty to confirm the registry key was actually created (AG17-002)"
        }

        It "Should verify cmdKey exists with Test-Path after writing it" {
            $script:funcBody | Should -Match 'Test-Path \$cmdKey' `
                -Because "Register-ContextMenu must call Test-Path on cmdKey after Set-ItemProperty to confirm the command key was actually created (AG17-002)"
        }

        It "Should return @{ Success = `$true } on the happy path" {
            $script:funcBody | Should -Match 'Success\s*=\s*\$true' `
                -Because "Callers check .Success to decide whether to log a warning; must be explicitly returned (AG17-002)"
        }

        It "Should return @{ Success = `$false; Reason = ... } when verification fails" {
            $script:funcBody | Should -Match 'Success\s*=\s*\$false' `
                -Because "Must return failure status when registry key verification fails so callers can log/act (AG17-002)"

            $script:funcBody | Should -Match 'Reason\s*=' `
                -Because "Must include Reason field so callers have a diagnostic message to log (AG17-002)"
        }

        It "Should check return value at the call site in Invoke-FolderScheduling" {
            $schedFuncStart = $script:content.IndexOf('function Invoke-FolderScheduling')
            $schedFuncEnd   = $script:content.IndexOf('function ', $schedFuncStart + 100)
            $schedBody      = $script:content.Substring($schedFuncStart, $schedFuncEnd - $schedFuncStart)

            $schedBody | Should -Match '\$regResult\s*=\s*Register-ContextMenu' `
                -Because "Invoke-FolderScheduling must capture the return value of Register-ContextMenu (AG17-002)"

            $schedBody | Should -Match 'regResult\.Success' `
                -Because "Invoke-FolderScheduling must check .Success on the result to handle registration failures (AG17-002)"
        }
    }
}
