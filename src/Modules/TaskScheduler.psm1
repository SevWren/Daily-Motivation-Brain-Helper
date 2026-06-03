# =============================================================================
# TaskScheduler.psm1
# Wrapper around Windows Task Scheduler for Daily Motivation Brain Helper.
# All task operations go through this module — no direct schtasks calls elsewhere.
# =============================================================================

$script:TaskPrefix   = "DailyMotivation_"
# Resolve LaunchMotivation.bat from the actual install location (parent of the Modules\ dir).
# This must NOT point to %APPDATA% -- the .bat lives beside the .ps1 scripts, not in user data.
$script:LauncherPath = Join-Path (Split-Path $PSScriptRoot -Parent) "LaunchMotivation.bat"

# --- Helper: load tasks.json ---
function Get-TasksJson {
    $path = Join-Path $env:APPDATA "DailyMotivationBrainHelper\tasks.json"
    if (-not (Test-Path $path)) { return @() }
    try { return @(Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { return @() }
}

function Save-TasksJson {
    param([object[]]$Tasks)
    $path = Join-Path $env:APPDATA "DailyMotivationBrainHelper\tasks.json"
    $Tasks | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8
}

function New-MotivationTask {
    <#
    .SYNOPSIS
    Creates a new Windows Scheduled Task and records it in tasks.json.

    .PARAMETER FolderPath
    Absolute Windows path to the folder to open.

    .PARAMETER TriggerTime
    DateTime when the popup should fire. Caller decides today vs. tomorrow.

    .PARAMETER Force
    If set, skips duplicate check and creates regardless.

    .OUTPUTS
    [hashtable] with keys: Success (bool), TaskId (string), IsDuplicate (bool)
    #>
    param(
        [Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)][datetime]$TriggerTime,
        [switch]$Force
    )

    # --- Duplicate check (B-16) ---
    if (-not $Force) {
        $existing = Get-MotivationTasks | Where-Object {
            $_.folder_path -eq $FolderPath -and
            ([datetime]$_.scheduled_time).Date -eq $TriggerTime.Date -and
            $_.status -eq "PENDING"
        }
        if ($existing) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $true }
        }
    }

    # --- Generate task ID ---
    $taskId   = [System.Guid]::NewGuid().ToString("N").Substring(0,8)
    $taskName = "$script:TaskPrefix$taskId"

    # --- Register with Windows Task Scheduler ---
    $triggerStr = $TriggerTime.ToString("yyyy-MM-ddTHH:mm:ss")
    $action = New-ScheduledTaskAction `
        -Execute  "cmd.exe" `
        -Argument "/c `"$script:LauncherPath`""

    $trigger = New-ScheduledTaskTrigger -Once -At $TriggerTime

    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable      `    # run at next logon if missed (NPR-004)
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal `
        -UserId    $env:USERNAME `
        -LogonType Interactive   `
        -RunLevel  Limited

    try {
        Register-ScheduledTask `
            -TaskName  $taskName   `
            -Action    $action     `
            -Trigger   $trigger    `
            -Settings  $settings   `
            -Principal $principal  `
            -Description "Daily Motivation Brain Helper — $FolderPath" `
            -Force | Out-Null
    } catch {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $_.Exception.Message }
    }

    # --- Persist to tasks.json ---
    $tasks   = Get-TasksJson
    $newTask = [PSCustomObject]@{
        task_id                 = $taskId
        task_name               = $taskName
        folder_path             = $FolderPath
        folder_name             = (Split-Path -Leaf $FolderPath)
        scheduled_time          = $triggerStr
        created_at              = (Get-Date -Format "o")
        status                  = "PENDING"
        snooze_count            = 0
        snooze_duration_minutes = 5
    }
    $tasks += $newTask
    Save-TasksJson $tasks

    return @{ Success = $true; TaskId = $taskId; IsDuplicate = $false }
}

function Get-MotivationTasks {
    <#
    .SYNOPSIS
    Returns all tasks from tasks.json, cross-checked against Windows Task Scheduler.
    Tasks no longer present in the scheduler are marked DELETED.
    #>
    $tasks = Get-TasksJson
    foreach ($t in $tasks) {
        if ($t.status -eq "PENDING") {
            $wt = Get-ScheduledTask -TaskName $t.task_name -ErrorAction SilentlyContinue
            if ($null -eq $wt) { $t.status = "DELETED" }
        }
    }
    Save-TasksJson $tasks
    return $tasks
}

function Remove-MotivationTask {
    <#
    .SYNOPSIS
    Deletes a scheduled task by task_id from both the scheduler and tasks.json.
    #>
    param([Parameter(Mandatory)][string]$TaskId)

    $tasks  = Get-TasksJson
    $target = $tasks | Where-Object { $_.task_id -eq $TaskId }
    if (-not $target) { return $false }

    Unregister-ScheduledTask -TaskName $target.task_name -Confirm:$false -ErrorAction SilentlyContinue

    $tasks = $tasks | Where-Object { $_.task_id -ne $TaskId }
    Save-TasksJson $tasks
    return $true
}

function Get-MotivationTaskStatus {
    param([Parameter(Mandatory)][string]$TaskId)
    $task = (Get-TasksJson) | Where-Object { $_.task_id -eq $TaskId }
    if ($task) { return $task.status }
    return $null
}

function Update-MotivationTaskStatus {
    param(
        [Parameter(Mandatory)][string]$TaskId,
        [Parameter(Mandatory)][string]$Status,
        [int]$SnoozeCount = -1,
        [int]$SnoozeDurationMinutes = -1
    )
    $tasks = Get-TasksJson
    foreach ($t in $tasks) {
        if ($t.task_id -eq $TaskId) {
            $t.status = $Status
            if ($SnoozeCount -ge 0) { $t.snooze_count = $SnoozeCount }
            if ($SnoozeDurationMinutes -ge 0) { $t.snooze_duration_minutes = $SnoozeDurationMinutes }
        }
    }
    Save-TasksJson $tasks
}

Export-ModuleMember -Function *
