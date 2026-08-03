#Requires -Modules Pester
<#
.SYNOPSIS
    Integration tests for AG20-001: Multi-folder scheduling scenarios.
    Verifies that scheduling, listing, and removing multiple tasks maintains
    tasks.json consistency and correct state across all operations.
    Windows-only: requires Task Scheduler cmdlets.
#>

BeforeAll {
    if (-not $IsWindows) {
        Write-Host "Skipping AG20-001 - Windows Task Scheduler required" -ForegroundColor Yellow
        return
    }
    $script:RepoRoot = Join-Path $PSScriptRoot '..\..'
    . (Join-Path $script:RepoRoot 'DailyMotivation.ps1') -NoRun
    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Multi_$(New-Guid)"
    Initialize-AppData
    $script:ExePath = 'C:\Test\DailyMotivation.exe'
    $script:MockedTasks = @{}
    Mock Register-ScheduledTask {
        param($TaskName,$Action,$Trigger,$Settings,$Principal,$Description,$Force,$ErrorAction)
        $script:MockedTasks[$TaskName] = [PSCustomObject]@{ TaskName=$TaskName; Triggers=@($Trigger) }
        return $null
    }
    Mock Unregister-ScheduledTask {
        param($TaskName,$Confirm)
        if ($script:MockedTasks.ContainsKey($TaskName)) { $script:MockedTasks.Remove($TaskName) }
    }
    Mock Get-ScheduledTask {
        param($TaskName,$ErrorAction)
        if ($TaskName -eq 'DailyMotivation_*') { return @($script:MockedTasks.Values) }
        if ($script:MockedTasks.ContainsKey($TaskName)) { return $script:MockedTasks[$TaskName] }
        throw "Task not found: $TaskName"
    }
}

AfterAll {
    if (-not $IsWindows) { return }
    if (Test-Path $env:APPDATA) { Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG20-001 Multi-Folder Scheduling Integration' -Skip:(-not $IsWindows) {

    BeforeEach {
        $script:MockedTasks = @{}
        $script:AppDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
        if (Test-Path $script:AppDir) {
            Remove-Item -Path $script:AppDir -Recurse -Force
        }
        Initialize-AppData
    }

    It 'Schedule 3 different folders - Get-MotivationTasks returns 3 tasks with correct folder paths' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3

        $folderPaths = $tasks | ForEach-Object { $_.folder_path }
        $folderPaths | Should -Contain $folder1
        $folderPaths | Should -Contain $folder2
        $folderPaths | Should -Contain $folder3
    }

    It 'Remove the MIDDLE task (task 2 of 3) - adjacent entries remain intact with no data corruption' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        # Remove the middle task (task 2)
        $removeResult = Remove-MotivationTask -TaskId $r2.TaskId
        $removeResult | Should -Be $true

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 2

        $folderPaths = $tasks | ForEach-Object { $_.folder_path }
        $folderPaths | Should -Contain $folder1
        $folderPaths | Should -Not -Contain $folder2
        $folderPaths | Should -Contain $folder3

        # Verify task IDs are exactly task 1 and task 3 (no data corruption)
        $taskIds = $tasks | ForEach-Object { $_.task_id }
        $taskIds | Should -Contain $r1.TaskId
        $taskIds | Should -Not -Contain $r2.TaskId
        $taskIds | Should -Contain $r3.TaskId
    }

    It 'Schedule a 4th folder after removal of middle task - total becomes 3 tasks' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'
        $folder4 = 'C:\Projects\Delta'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        Remove-MotivationTask -TaskId $r2.TaskId

        $r4 = New-MotivationTask -FolderPath $folder4 -TriggerTime ((Get-Date).AddHours(5))
        $r4.Success | Should -Be $true

        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3

        $folderPaths = $tasks | ForEach-Object { $_.folder_path }
        $folderPaths | Should -Contain $folder1
        $folderPaths | Should -Not -Contain $folder2
        $folderPaths | Should -Contain $folder3
        $folderPaths | Should -Contain $folder4
    }

    It 'tasks.json is valid and parseable JSON after all operations (no corruption)' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'
        $folder4 = 'C:\Projects\Delta'

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime ((Get-Date).AddHours(2))
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        Remove-MotivationTask -TaskId $r2.TaskId

        $r4 = New-MotivationTask -FolderPath $folder4 -TriggerTime ((Get-Date).AddHours(5))
        $r4.Success | Should -Be $true

        $appDir = Join-Path $env:APPDATA 'DailyMotivationBrainHelper'
        $tasksJsonPath = Join-Path $appDir 'tasks.json'
        Test-Path $tasksJsonPath | Should -Be $true

        $raw = Get-Content -Path $tasksJsonPath -Raw
        $raw | Should -Not -BeNullOrEmpty

        # ConvertFrom-Json throws on invalid JSON — this assertion catches corruption
        { $raw | ConvertFrom-Json } | Should -Not -Throw

        $parsed = $raw | ConvertFrom-Json
        $parsedArray = @($parsed)
        $parsedArray.Count | Should -Be 3
    }

    It 'Schedule same folder twice on the same date - second call returns IsDuplicate=$true, count stays at 3' {
        $folder1 = 'C:\Projects\Alpha'
        $folder2 = 'C:\Projects\Beta'
        $folder3 = 'C:\Projects\Gamma'

        $triggerTime = (Get-Date).AddHours(2)

        $r1 = New-MotivationTask -FolderPath $folder1 -TriggerTime $triggerTime
        $r2 = New-MotivationTask -FolderPath $folder2 -TriggerTime ((Get-Date).AddHours(3))
        $r3 = New-MotivationTask -FolderPath $folder3 -TriggerTime ((Get-Date).AddHours(4))

        $r1.Success | Should -Be $true
        $r2.Success | Should -Be $true
        $r3.Success | Should -Be $true

        # Attempt to schedule folder1 again at the same trigger time (same date)
        $rDupe = New-MotivationTask -FolderPath $folder1 -TriggerTime $triggerTime
        $rDupe.Success    | Should -Be $false
        $rDupe.IsDuplicate | Should -Be $true

        # Count must remain at 3 — duplicate was rejected
        $tasks = Get-MotivationTasks
        $tasks.Count | Should -Be 3
    }
}
