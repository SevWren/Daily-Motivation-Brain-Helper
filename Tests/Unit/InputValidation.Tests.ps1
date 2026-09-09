#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Unit tests for input validation bugs (AG2-001 through AG2-025)
.NOTES
    Windows-only tests: Requires Windows Task Scheduler cmdlets
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_InputVal_Test_$(New-Guid)"
    Initialize-AppData

    # Override ExePath
    $script:ExePath = "C:\Test\DailyMotivation.exe"

    # Mock Windows Task Scheduler cmdlets only on Windows
    # Register returns task object (AG5-001 verification uses return value, not Get-ScheduledTask)
    if ($IsWindows) {
        Mock Register-ScheduledTask {
            param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
            return [PSCustomObject]@{ TaskName = $TaskName; State = 'Ready' }
        }
        Mock Unregister-ScheduledTask {
            param($TaskName, $Confirm)
        }
        Mock Get-ScheduledTask {
            param($TaskName)
            if ($TaskName -eq "DailyMotivation_*") { return @() }
            return $null
        }
    }
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG2-001: Missing null check on $FolderPath before length comparison' -Skip:(-not $IsWindows) {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    Context 'New-MotivationTask' {
        It 'Should handle null FolderPath without throwing NullReferenceException' {
            $result = $null
            { $result = New-MotivationTask -FolderPath $null -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }

        It 'Should handle empty FolderPath without throwing' {
            $result = $null
            { $result = New-MotivationTask -FolderPath '' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }

        It 'Should handle single character FolderPath without array index error' {
            $result = $null
            { $result = New-MotivationTask -FolderPath 'C' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }
    }

    Context 'Invoke-FolderScheduling' {
        It 'Should handle null FolderPath without throwing NullReferenceException' {
            $result = $null
            { $result = Invoke-FolderScheduling -FolderPath $null -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }

        It 'Should handle empty FolderPath without throwing' {
            $result = $null
            { $result = Invoke-FolderScheduling -FolderPath '' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
        }
    }
}

Describe 'AG2-004: Unvalidated array index access on $FolderPath' -Skip:(-not $IsWindows) {
    BeforeEach {
        '[]' | Set-Content (Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json') -Encoding UTF8
    }

    It 'Should handle single character path without array bounds exception' {
        $result = $null
        { $result = New-MotivationTask -FolderPath 'X' -TriggerTime ((Get-Date).AddHours(2)) } | Should -Not -Throw
    }
}

Describe 'BUG-1 Structural Guard: openExplorer reset removed from Show-PopupWindow finally block' {
    It 'DailyMotivation.ps1 contains no openExplorer assignment in Show-PopupWindow finally block' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody  = $src.Substring($functionStart, $functionEnd - $functionStart)
        $finallyMatch  = [regex]::Match($functionBody, 'finally\s*\{(.+?)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $finallyContent = $finallyMatch.Groups[1].Value
        $finallyContent -match '\$script:openExplorer\s*=' | Should -Be $false -Because 'BUG-1 fix: finally block must not reset openExplorer state'
    }
    It 'openExplorer state initialization before ShowDialog is preserved' {
        $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
        $functionStart = $src.IndexOf('function Show-PopupWindow')
        $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
        $functionBody  = $src.Substring($functionStart, $functionEnd - $functionStart)
        $functionBody -match '\$script:openExplorer\s*=\s*\$true' | Should -Be $true -Because 'Popup must initialize openExplorer=true before showing window'
    }
}
