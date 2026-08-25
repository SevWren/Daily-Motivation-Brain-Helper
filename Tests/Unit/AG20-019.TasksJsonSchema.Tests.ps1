#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Contract tests for tasks.json schema robustness (AG20-019).
    Verifies that Get-TasksJson / Get-MotivationTasks / Remove-MotivationTask do not throw
    when tasks.json contains entries with missing or null required fields.
.NOTES
    All read-path tests are platform-agnostic (no Task Scheduler dependency).
    Remove-MotivationTask no-op test uses HeadlessPlatform to bypass Sync-TaskStatuses.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Schema_Test_$(New-Guid)"
    Initialize-AppData

    function New-TestTask([hashtable]$Overrides = @{}, [string[]]$Without = @()) {
        $props = [ordered]@{
            task_id        = 'aaaabbbb-0001-0001-0001-000000000001'
            task_name      = 'DailyMotivation_test_default'
            folder_path    = 'C:\Test'
            folder_name    = 'Test'
            scheduled_time = '2026-09-01T14:00:00'
            created_at     = (Get-Date -Format 'o')
            status         = 'PENDING'
            snooze_count   = 0
        }
        foreach ($k in $Overrides.Keys) { $props[$k] = $Overrides[$k] }
        foreach ($k in $Without) { $props.Remove($k) }
        return [PSCustomObject]$props
    }
}

AfterAll {
    if (Test-Path $env:APPDATA) { Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'tasks.json schema contract  -  malformed entries' {

    BeforeEach {
        # Reset tasks.json to empty before each test
        Set-Content -Path $script:TasksPath -Value '[]' -Encoding UTF8 -NoNewline
    }

    Context 'Get-TasksJson with null task_id' {
        It 'does not throw when an entry has task_id = $null' {
            $badTask = New-TestTask @{task_id=$null; task_name='DailyMotivation_test_nullid'}
            @($badTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            { Get-TasksJson } | Should -Not -Throw
        }

        It 'returns the entry (or skips it) without throwing  -  either behavior is acceptable' {
            $badTask = New-TestTask @{task_id=$null; task_name='DailyMotivation_test_nullid'}
            @($badTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            # AG18-010: entries with null task_id are filtered out; the result is an
            # empty collection. Assert on .Count rather than piping to Should -- an empty
            # array @() sends nothing through the pipeline so Should receives $null.
            $result = @(Get-TasksJson)
            $result.Count | Should -Be 0
        }
    }

    Context 'Get-MotivationTasks with null task_id' {
        It 'does not throw when an entry has task_id = $null' {
            $badTask = New-TestTask @{task_id=$null; task_name='DailyMotivation_test_nullid2'}
            @($badTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            { Get-MotivationTasks } | Should -Not -Throw
        }
    }

    Context 'Get-TasksJson with missing task_name key' {
        It 'does not throw when an entry is missing the task_name property' {
            $badTask = New-TestTask @{task_id='aaaabbbb-0001-0001-0001-000000000001'} -Without 'task_name'
            @($badTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            { Get-TasksJson } | Should -Not -Throw
        }
    }

    Context 'Get-TasksJson with null status' {
        It 'does not throw when an entry has status = $null' {
            $badTask = New-TestTask @{
                task_id   = 'ccccdddd-0003-0003-0003-000000000003'
                task_name = 'DailyMotivation_test_nullstatus'
                status    = $null
            }
            @($badTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            { Get-TasksJson } | Should -Not -Throw
        }
    }

    Context 'Get-MotivationTasks with mixed valid and invalid entries' {
        It 'returns at minimum the valid entry without throwing' {
            $validTask = [PSCustomObject]@{
                task_id        = 'eeeeffff-0005-0005-0005-000000000005'
                task_name      = 'DailyMotivation_test_valid'
                folder_path    = 'C:\ValidFolder'
                folder_name    = 'ValidFolder'
                scheduled_time = '2026-09-01T14:00:00'
                created_at     = (Get-Date -Format 'o')
                status         = 'PENDING'
                snooze_count   = 0
            }
            $nullIdTask = [PSCustomObject]@{
                task_id        = $null
                task_name      = 'DailyMotivation_test_invalid_nullid'
                folder_path    = 'C:\BadFolder'
                folder_name    = 'BadFolder'
                scheduled_time = '2026-09-02T08:00:00'
                created_at     = (Get-Date -Format 'o')
                status         = $null
                snooze_count   = 0
            }
            @($validTask, $nullIdTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            { Get-MotivationTasks } | Should -Not -Throw

            $tasks = Get-MotivationTasks
            # The valid entry must be present in the result
            $validFound = $tasks | Where-Object { $_.task_id -eq 'eeeeffff-0005-0005-0005-000000000005' }
            $validFound | Should -Not -BeNullOrEmpty
        }

        It 'returns a non-null array (not $null) for mixed entries' {
            $validTask = [PSCustomObject]@{
                task_id        = 'ffffaaaa-0006-0006-0006-000000000006'
                task_name      = 'DailyMotivation_test_valid2'
                folder_path    = 'C:\ValidFolder2'
                folder_name    = 'ValidFolder2'
                scheduled_time = '2026-09-03T10:00:00'
                created_at     = (Get-Date -Format 'o')
                status         = 'PENDING'
                snooze_count   = 0
            }
            $missingNameTask = [PSCustomObject]@{
                task_id        = 'ffffaaaa-0007-0007-0007-000000000007'
                folder_path    = 'C:\BadFolder2'
                folder_name    = 'BadFolder2'
                scheduled_time = '2026-09-04T12:00:00'
                created_at     = (Get-Date -Format 'o')
                status         = 'PENDING'
                snooze_count   = 0
            }
            @($validTask, $missingNameTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            $tasks = Get-MotivationTasks
            $tasks | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Remove-MotivationTask with a non-existent TaskId' {
        It 'returns $false without throwing when TaskId does not match any entry (platform-agnostic via HeadlessPlatform)' {
            # Inject HeadlessPlatform so Remove-MotivationTask skips Sync-TaskStatuses
            # (Sync-TaskStatuses requires Windows Task Scheduler cmdlets)
            $script:Platform = [HeadlessPlatform]::new()

            $validTask = [PSCustomObject]@{
                task_id        = 'bbbbcccc-0008-0008-0008-000000000008'
                task_name      = 'DailyMotivation_test_removenoop'
                folder_path    = 'C:\SomeFolder'
                folder_name    = 'SomeFolder'
                scheduled_time = '2026-09-05T09:00:00'
                created_at     = (Get-Date -Format 'o')
                status         = 'PENDING'
                snooze_count   = 0
            }
            @($validTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            { Remove-MotivationTask -TaskId 'does-not-exist-00000000000' } | Should -Not -Throw

            $result = Remove-MotivationTask -TaskId 'does-not-exist-00000000000'
            $result | Should -Be $false

            # Existing task must be untouched
            $remaining = Get-TasksJson
            $remaining | Where-Object { $_.task_id -eq 'bbbbcccc-0008-0008-0008-000000000008' } | Should -Not -BeNullOrEmpty

            # Restore platform to null
            $script:Platform = $null
        }

        It 'is a graceful no-op on Windows with mocked Task Scheduler cmdlets' -Skip:(-not $IsWindows) {
            Mock Unregister-ScheduledTask { }
            Mock Get-ScheduledTask { return $null }
            Mock Sync-TaskStatuses { }

            $validTask = [PSCustomObject]@{
                task_id        = 'bbbbcccc-0009-0009-0009-000000000009'
                task_name      = 'DailyMotivation_test_removenoop2'
                folder_path    = 'C:\SomeFolder2'
                folder_name    = 'SomeFolder2'
                scheduled_time = '2026-09-06T09:00:00'
                created_at     = (Get-Date -Format 'o')
                status         = 'PENDING'
                snooze_count   = 0
            }
            @($validTask) | ConvertTo-Json | Set-Content $script:TasksPath -Encoding UTF8

            { Remove-MotivationTask -TaskId 'nonexistent-id-windows-test' } | Should -Not -Throw

            $result = Remove-MotivationTask -TaskId 'nonexistent-id-windows-test'
            $result | Should -Be $false
        }
    }
}
