#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for AG18-013: tasks.json checksum sidecar integrity verification.

.DESCRIPTION
    Linux-safe tests for the tasks persistence layer. The checksum sidecar is
    backward compatible: files without a sidecar still load, but a matching
    sidecar can detect silent byte-level corruption.
#>

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $script:ProjectRoot 'DailyMotivation.ps1') -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_AG18_013_$(New-Guid)"
    Initialize-AppData

    $script:ChecksumPath = $script:TasksPath + '.sha256'
}

AfterAll {
    if (Test-Path $env:APPDATA) {
        Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

Describe 'AG18-013 - tasks.json checksum sidecar' {
    BeforeEach {
        if (Test-Path $script:TasksPath) {
            Remove-Item -Path $script:TasksPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $script:ChecksumPath) {
            Remove-Item -Path $script:ChecksumPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Save-TasksJson writes a SHA-256 checksum sidecar for the live file bytes' {
        $task = [PSCustomObject]@{
            task_id        = 'checksum-task-001'
            task_name      = 'DailyMotivation_checksum-task-001'
            folder_path    = 'C:\Focus'
            folder_name    = 'Focus'
            scheduled_time = '2026-09-14T14:00:00'
            created_at     = '2026-09-14T09:00:00'
            status         = 'PENDING'
            snooze_count   = 0
        }

        Save-TasksJson @($task)

        Test-Path $script:ChecksumPath | Should -Be $true
        (Get-Content -Path $script:ChecksumPath -Raw -Encoding UTF8).Trim() | Should -Match '^[0-9A-F]{64}$'
        (Get-Content -Path $script:ChecksumPath -Raw -Encoding UTF8).Trim() | Should -Be (Get-FileSha256Hex -Path $script:TasksPath)
    }

    It 'Get-TasksJson loads tasks normally when the checksum matches' {
        $task = [PSCustomObject]@{
            task_id        = 'checksum-task-002'
            task_name      = 'DailyMotivation_checksum-task-002'
            folder_path    = 'C:\DeepWork'
            folder_name    = 'DeepWork'
            scheduled_time = '2026-09-15T14:00:00'
            created_at     = '2026-09-14T10:00:00'
            status         = 'PENDING'
            snooze_count   = 0
        }

        Save-TasksJson @($task)

        $result = @(Get-TasksJson)
        $result.Count | Should -Be 1
        $result[0].task_id | Should -Be 'checksum-task-002'
    }

    It 'Get-TasksJson returns empty array when checksum matches the timestamp but not the file bytes' {
        $task = [PSCustomObject]@{
            task_id        = 'checksum-task-003'
            task_name      = 'DailyMotivation_checksum-task-003'
            folder_path    = 'C:\Original'
            folder_name    = 'Original'
            scheduled_time = '2026-09-16T14:00:00'
            created_at     = '2026-09-14T11:00:00'
            status         = 'PENDING'
            snooze_count   = 0
        }
        Save-TasksJson @($task)

        $checksumTimeUtc = (Get-Item -Path $script:ChecksumPath).LastWriteTimeUtc
        '[{"task_id":"tampered-task","task_name":"DailyMotivation_tampered-task","folder_path":"C:\\Tampered","folder_name":"Tampered","scheduled_time":"2026-09-16T15:00:00","created_at":"2026-09-14T11:30:00","status":"PENDING","snooze_count":0}]' |
            Set-Content -Path $script:TasksPath -Encoding UTF8 -NoNewline
        [System.IO.File]::SetLastWriteTimeUtc($script:TasksPath, $checksumTimeUtc)

        @(Get-TasksJson).Count | Should -Be 0
    }

    It 'Get-TasksJson still loads legacy tasks.json when no checksum sidecar exists' {
        '[{"task_id":"legacy-task","task_name":"DailyMotivation_legacy-task","folder_path":"C:\\Legacy","folder_name":"Legacy","scheduled_time":"2026-09-17T14:00:00","created_at":"2026-09-14T12:00:00","status":"PENDING","snooze_count":0}]' |
            Set-Content -Path $script:TasksPath -Encoding UTF8 -NoNewline

        $result = @(Get-TasksJson)
        $result.Count | Should -Be 1
        $result[0].task_id | Should -Be 'legacy-task'
    }

    It 'Get-TasksJson ignores a stale checksum sidecar older than tasks.json' {
        $task = [PSCustomObject]@{
            task_id        = 'checksum-task-004'
            task_name      = 'DailyMotivation_checksum-task-004'
            folder_path    = 'C:\Fresh'
            folder_name    = 'Fresh'
            scheduled_time = '2026-09-18T14:00:00'
            created_at     = '2026-09-14T13:00:00'
            status         = 'PENDING'
            snooze_count   = 0
        }
        Save-TasksJson @($task)

        Start-Sleep -Milliseconds 50
        '[{"task_id":"manual-edit","task_name":"DailyMotivation_manual-edit","folder_path":"C:\\Manual","folder_name":"Manual","scheduled_time":"2026-09-18T15:00:00","created_at":"2026-09-14T13:30:00","status":"PENDING","snooze_count":0}]' |
            Set-Content -Path $script:TasksPath -Encoding UTF8 -NoNewline

        $result = @(Get-TasksJson)
        $result.Count | Should -Be 1
        $result[0].task_id | Should -Be 'manual-edit'
    }
}
