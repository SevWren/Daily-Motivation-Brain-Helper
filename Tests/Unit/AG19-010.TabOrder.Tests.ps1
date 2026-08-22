#Requires -Modules Pester
<#
.SYNOPSIS
    Tests for AG19-010: Tab order/keyboard navigation is set on all interactive controls.
    Verifies TabIndex attributes are present in both main window and popup window XAML.
#>

Describe 'AG19-010 — Tab order' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
        $script:content = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
    }

    It 'Should set TabIndex=<TabIndex> on <Control>' -ForEach @(
        @{ Control = 'SelectFolderBtn'; TabIndex = 1 }
        @{ Control = 'TodayRadio';      TabIndex = 2 }
        @{ Control = 'TomorrowRadio';   TabIndex = 3 }
        @{ Control = 'ScheduleBtn';     TabIndex = 4 }
        @{ Control = 'UndoBtn';         TabIndex = 5 }
        @{ Control = 'LetsGoBtn';       TabIndex = 0 }
        @{ Control = 'SnoozeBtn';       TabIndex = 1 }
        @{ Control = 'SnoozeDropBtn';   TabIndex = 2 }
        @{ Control = 'DismissBtn';      TabIndex = 3 }
    ) {
        $script:content | Should -Match "x:Name=""$Control""[^<>]*TabIndex=""$TabIndex""" `
            -Because "$Control must have TabIndex=$TabIndex (AG19-010)"
    }
}
