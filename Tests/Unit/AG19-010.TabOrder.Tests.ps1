#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for AG19-010: Tab order/keyboard navigation is set on all interactive controls.
    Verifies TabIndex attributes are present in both main window and popup window XAML.
#>

BeforeAll {
    . "$PSScriptRoot/../../DailyMotivation.ps1" -NoRun
}

Describe "AG19-010: Tab Order/Keyboard Navigation" {
    Context "Main window controls have correct TabIndex values" {
        BeforeAll {
            $script:content = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        }

        It "Should set TabIndex=1 on SelectFolderBtn (first interactive control)" {
            # [^<>]* matches any attribute text within the same XML element, including newlines
            $script:content | Should -Match 'x:Name="SelectFolderBtn"[^<>]*TabIndex="1"' `
                -Because "SelectFolderBtn is the entry point for keyboard users and must be TabIndex=1 (AG19-010)"
        }

        It "Should set TabIndex=2 on TodayRadio (follows folder selection)" {
            $script:content | Should -Match 'x:Name="TodayRadio"[^<>]*TabIndex="2"' `
                -Because "TodayRadio follows SelectFolderBtn in logical tab flow and must be TabIndex=2 (AG19-010)"
        }

        It "Should set TabIndex=3 on TomorrowRadio (follows TodayRadio)" {
            $script:content | Should -Match 'x:Name="TomorrowRadio"[^<>]*TabIndex="3"' `
                -Because "TomorrowRadio follows TodayRadio in logical tab flow and must be TabIndex=3 (AG19-010)"
        }

        It "Should set TabIndex=4 on ScheduleBtn (primary action after selecting options)" {
            $script:content | Should -Match 'x:Name="ScheduleBtn"[^<>]*TabIndex="4"' `
                -Because "ScheduleBtn is the primary action and must be TabIndex=4 (AG19-010)"
        }

        It "Should set TabIndex=5 on UndoBtn (last in flow, only visible post-schedule)" {
            $script:content | Should -Match 'x:Name="UndoBtn"[^<>]*TabIndex="5"' `
                -Because "UndoBtn appears after scheduling and must be TabIndex=5 (AG19-010)"
        }
    }

    Context "Popup window controls have correct TabIndex values" {
        BeforeAll {
            $script:content = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        }

        It "Should set TabIndex=0 on LetsGoBtn (primary action — open folder)" {
            $script:content | Should -Match 'x:Name="LetsGoBtn"[^<>]*TabIndex="0"' `
                -Because "LetsGoBtn is the primary popup action and must have highest tab priority TabIndex=0 (AG19-010)"
        }

        It "Should set TabIndex=1 on SnoozeBtn (secondary action)" {
            $script:content | Should -Match 'x:Name="SnoozeBtn"[^<>]*TabIndex="1"' `
                -Because "SnoozeBtn is the secondary popup action and must be TabIndex=1 (AG19-010)"
        }

        It "Should set TabIndex=2 on SnoozeDropBtn (snooze duration picker)" {
            $script:content | Should -Match 'x:Name="SnoozeDropBtn"[^<>]*TabIndex="2"' `
                -Because "SnoozeDropBtn dropdown follows SnoozeBtn and must be TabIndex=2 (AG19-010)"
        }

        It "Should set TabIndex=3 on DismissBtn (lowest priority — dismiss for today)" {
            $script:content | Should -Match 'x:Name="DismissBtn"[^<>]*TabIndex="3"' `
                -Because "DismissBtn is the lowest priority popup action and must be TabIndex=3 (AG19-010)"
        }
    }
}
