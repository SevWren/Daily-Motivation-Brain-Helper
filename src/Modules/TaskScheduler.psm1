# =============================================================================
# TaskScheduler.psm1
# Wrapper around Windows Task Scheduler for Daily Motivation Brain Helper.
# All task operations go through this module - no direct schtasks calls elsewhere.
# =============================================================================

$script:TaskPrefix   = "DailyMotivation_"
# Resolve LaunchMotivation.bat from the actual install location (parent of the Modules\ dir).
# This must NOT point to %APPDATA% -- the .bat lives beside the .ps1 scripts, not in user data.
$script:LauncherPath = Join-Path (Split-Path $PSScriptRoot -Parent) "LaunchMotivation.bat"

# --- Helper: load tasks.json ---
function Get-TasksJson {
    $path = Join-Path $env:APPDATA "DailyMotivationBrainHelper\tasks.json"
    if (-not (Test-Path $path)) { return @() }
    try {
        $result = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        # FIX-003: PowerShell 5.1 returns $null for "[]", and the comma operator wraps $null in array.
        # Return a clean empty array for both $null and actual empty results.
        if ($null -eq $result) { return @() }
        return @($result)
    }
    catch { return @() }
}

function Save-TasksJson {
    param([object[]]$Tasks)
    $path = Join-Path $env:APPDATA "DailyMotivationBrainHelper\tasks.json"
    # FIX-003: Handle null/empty cases explicitly. PowerShell's ConvertTo-Json on $null
    # or an array containing $null produces "null" or "[[]]" instead of "[]".
    if ($null -eq $Tasks -or $Tasks.Count -eq 0) {
        '[]' | Set-Content -Path $path -Encoding UTF8
    } else {
        ConvertTo-Json -InputObject $Tasks -Depth 4 | Set-Content -Path $path -Encoding UTF8
    }
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
    # GAP-006: Windows paths are case-insensitive; normalise before comparing.
    $normalizedInput = [System.IO.Path]::GetFullPath($FolderPath).ToLowerInvariant()
    if (-not $Force) {
        $existing = Get-MotivationTasks | Where-Object {
            $_.folder_path -and $_.folder_path.Length -gt 0 -and
            [System.IO.Path]::GetFullPath($_.folder_path).ToLowerInvariant() -eq $normalizedInput -and
            ([datetime]$_.scheduled_time).Date -eq $TriggerTime.Date -and
            $_.status -eq "PENDING"
        }
        if ($existing) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $true }
        }
    }

    # --- Generate task ID (GAP-007: retry on GUID collision - near-impossible but defensive) ---
    # Retry loop kept as additional defence; 5 attempts remains reasonable.
    $taskId   = [System.Guid]::NewGuid().ToString("N").Substring(0,16)
    $taskName = "$script:TaskPrefix$taskId"
    $attempts = 0
    while ((Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) -and ($attempts -lt 5)) {
        $taskId   = [System.Guid]::NewGuid().ToString("N").Substring(0,16)
        $taskName = "$script:TaskPrefix$taskId"
        $attempts++
    }

    # --- Register with Windows Task Scheduler ---
    $triggerStr = $TriggerTime.ToString("yyyy-MM-ddTHH:mm:ss")
    $action = New-ScheduledTaskAction `
        -Execute  "cmd.exe" `
        -Argument "/c `"$script:LauncherPath`""

    $trigger = New-ScheduledTaskTrigger -Once -At $TriggerTime

    # - StartWhenAvailable: run at next logon if missed (NPR-004)
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
        -MultipleInstances IgnoreNew

    # GAP-010: Detect network/UNC paths. Mapped drives may not be available to the
    # Task Scheduler session; UNC paths may need higher privilege to access at fire time.
    # Register with RunLevel Highest for network targets so the task has the best chance
    # of succeeding. On standard user accounts this equals the user's highest available
    # privilege (no UAC prompt); on admin accounts it runs elevated.
    # GAP-010: UNC paths must start with exactly two backslashes followed by a server name char.
    # Mapped drives: cache DriveInfo to avoid repeated constructor calls for the same path.
    $isUncPath    = $FolderPath -match '^\\\\[^\\]'
    $isMappedDrive = $false
    if ($FolderPath.Length -ge 2 -and $FolderPath[1] -eq ':') {
        try {
            $driveInfo     = [System.IO.DriveInfo]::new([string]$FolderPath[0])
            $isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
        } catch { $isMappedDrive = $false }
    }
    $isNetworkPath = $isUncPath -or $isMappedDrive
    $runLevel = if ($isNetworkPath) { 'Highest' } else { 'Limited' }

    $principal = New-ScheduledTaskPrincipal `
        -UserId    $env:USERNAME `
        -LogonType Interactive   `
        -RunLevel  $runLevel

    try {
        Register-ScheduledTask `
            -TaskName  $taskName   `
            -Action    $action     `
            -Trigger   $trigger    `
            -Settings  $settings   `
            -Principal $principal  `
            -Description "Daily Motivation Brain Helper - $FolderPath" `
            -Force | Out-Null
    } catch {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $_.Exception.Message }
    }

    # --- Persist to tasks.json ---
    $tasks = @(Get-TasksJson)
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
    $tasks = $tasks + $newTask
    Save-TasksJson $tasks

    return @{ Success = $true; TaskId = $taskId; IsDuplicate = $false; IsNetworkPath = $isNetworkPath }
}

function Get-MotivationTasks {
    <#
    .SYNOPSIS
    Returns all tasks from tasks.json, cross-checked against Windows Task Scheduler.
    Tasks no longer present in the scheduler are marked DELETED.
    #>
    $tasks = @(Get-TasksJson)
    foreach ($t in $tasks) {
        # Skip null or malformed entries
        if ($null -eq $t -or -not $t.PSObject.Properties) { continue }
        if ($t.status -eq "PENDING") {
            try {
                $wt = Get-ScheduledTask -TaskName $t.task_name -ErrorAction Stop
                # Task exists in scheduler - status stays PENDING
            } catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
                # ObjectNotFoundException: task is genuinely gone - mark deleted (ERR-008)
                $t.status = "DELETED"
            } catch [System.UnauthorizedAccessException] {
                # Access denied: task exists but we can't read it - do NOT mark deleted (ERR-008)
                Write-Warning "Get-MotivationTasks: access denied reading task '$($t.task_name)' - skipping status update."
            } catch {
                # Unknown error - treat as possibly-still-present, log and skip
                Write-Warning "Get-MotivationTasks: unexpected error for '$($t.task_name)': $_"
            }
        }
    }
    Save-TasksJson $tasks
    return ,$tasks
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

    # BUG-009: detect deletion failure so orphaned tasks don't keep firing
    try {
        Unregister-ScheduledTask -TaskName $target.task_name -Confirm:$false -ErrorAction Stop
    } catch {
        # Task may not exist (already fired or manually removed) - not a fatal error.
        # Log but continue so the tasks.json entry is still cleaned up.
        Write-Warning "Remove-MotivationTask: Unregister-ScheduledTask failed for '$($target.task_name)': $_"
    }

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
