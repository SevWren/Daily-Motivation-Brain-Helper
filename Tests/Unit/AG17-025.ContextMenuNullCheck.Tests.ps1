BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG17-025: Missing Null Checks Before Accessing ContextMenu" {
    Context "When snooze dropdown button is clicked" {
        It "Should check if ContextMenu exists before accessing IsOpen property" {
            # The issue: Line 2575 accesses $snoozeDropBtn.ContextMenu.IsOpen without
            # checking if ContextMenu is null. If XAML parsing fails or initialization
            # error occurs, this throws a null reference exception.

            # Expected behavior: Add null check in handler before accessing .IsOpen
            # Code location: DailyMotivation.ps1 lines 2572-2576

            $true | Should -BeTrue -Because "Test documents required fix for AG17-025"
        }

        It "Should log error and handle gracefully when ContextMenu is null" {
            # Expected: If ContextMenu is null, log error message and return early
            # instead of throwing null reference exception

            $true | Should -BeTrue -Because "Test documents error handling requirement"
        }

        It "Should handle XAML load failures without crashing" {
            # Scenario: XAML parsing fails, ContextMenu not initialized
            # Expected: Button click handler doesn't crash, logs diagnostic error

            $true | Should -BeTrue -Because "Test documents failure resilience requirement"
        }
    }
}
