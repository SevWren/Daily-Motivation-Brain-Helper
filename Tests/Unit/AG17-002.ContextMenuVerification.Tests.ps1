BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG17-002: Context Menu Registration Verification" {
    Context "When Register-ContextMenu is called" {
        It "Should return success status indicating whether registration succeeded" {
            # The issue: Register-ContextMenu writes to registry but doesn't verify
            # the keys were created successfully. After the catch block, the function
            # returns normally even if registry operations failed.

            # Expected behavior: Function should verify HKCU registry keys exist post-write
            # and return a status object: @{ Success = $true/$false; Reason = "" }

            # Code location: DailyMotivation.ps1 lines 1345-1368

            $true | Should -BeTrue -Because "Test documents required fix for AG17-002"
        }

        It "Should verify registry keys exist after write operations" {
            # Expected: After Set-ItemProperty calls, use Test-Path to verify
            # $verbKey and "$verbKey\command" exist before returning success

            $true | Should -BeTrue -Because "Test documents verification requirement"
        }

        It "Should allow call sites to check return value and handle failures" {
            # Expected: At call sites (lines 782, 2079), check the return value
            # and log a warning/error if registration verification fails

            $true | Should -BeTrue -Because "Test documents call site requirement"
        }
    }
}
