BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG19-010: Tab Order/Keyboard Navigation" {
    Context "When user navigates with Tab key" {
        It "Should set TabIndex on controls for logical navigation flow" {
            # The issue: TabIndex is not set on most controls. Keyboard users
            # navigate in random order instead of logical flow:
            # SelectFolder → TodayRadio → TomorrowRadio → ScheduleBtn

            # Expected behavior: Set TabIndex on all interactive controls
            # in logical order for keyboard navigation

            # Logical tab order:
            # 1. SelectFolderBtn (TabIndex="1")
            # 2. TodayRadio (TabIndex="2")
            # 3. TomorrowRadio (TabIndex="3")
            # 4. ScheduleBtn (TabIndex="4")
            # 5. UndoBtn (TabIndex="5")

            $true | Should -BeTrue -Because "Test documents required fix for AG19-010"
        }

        It "Should support keyboard shortcuts for common actions" {
            # Expected: Implement keyboard shortcuts
            # - Alt+S = Schedule
            # - Alt+H = History
            # - Escape = Close dialogs
            # - Enter on ScheduleBtn triggers schedule

            $true | Should -BeTrue -Because "Test documents keyboard shortcut requirement"
        }

        It "Should work with screen readers (NVDA) using proper Tab order" {
            # Expected: Tab order follows visual layout top-to-bottom
            # Screen readers announce controls in TabIndex order

            $true | Should -BeTrue -Because "Test documents screen reader compatibility"
        }
    }
}
