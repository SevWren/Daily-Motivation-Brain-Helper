#Requires -Version 7.0
# =============================================================================
# DailyMotivation.ps1 -- Daily Motivation Brain Helper
# Single-file entry point. All logic, XAML, and data are inline.
# Compile: Invoke-ps2exe DailyMotivation.ps1 DailyMotivation.exe -STA -noConsole
#
# Execution modes:
#   DailyMotivation.exe               -> main UI (folder picker + scheduler)
#   DailyMotivation.exe /popup        -> notification popup (called by Task Scheduler)
#   DailyMotivation.exe /setfolder "C:\path" -> context menu handler
#
# NOTE: Source code runs on PowerShell 7, but compiles to .NET Framework 4.x exe
#       (ps2exe limitation). Avoid PowerShell 7-only features in runtime code paths.
#       UTF-8 file encoding required for emoji in XAML &#x...; references.
# =============================================================================

# ============================================================
# SECTION 1: Param block
# ============================================================
param(
    [string]$Mode       = "main",
    [string]$FolderPath = "",
    [switch]$NoRun      # When set, defines all functions but skips the entry point.
                        # Use when dot-sourcing in Pester tests: . .\DailyMotivation.ps1 -NoRun
)

# ============================================================
# SECTION 2: Debug logging + platform detection
# ============================================================
# Cross-platform temp directory resolution
$script:TempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
$script:DebugLog = Join-Path $script:TempDir "DailyMotivation_debug.log"

function Write-DLog {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Add-Content -Path $script:DebugLog -Value $line -ErrorAction SilentlyContinue
}

# Platform detection
# PowerShell 7+ has $IsWindows variable; compiled exe always runs on Windows
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $script:IsWindowsPlatform = $IsWindows
} else {
    # Fallback for ps2exe compiled exe (.NET Framework 4.x target)
    $script:IsWindowsPlatform = $true
}

# Platform adapter (null by default, tests can inject HeadlessPlatform)
$script:Platform = $null

# Assembly loading (deferred - only when NOT dot-sourcing with -NoRun)
$script:AssembliesLoaded = $false

function Initialize-WindowsAssemblies {
    if ($script:AssembliesLoaded) { return }
    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
        $script:AssembliesLoaded = $true
        Write-DLog "Assemblies loaded OK"
    }
    catch {
        Write-DLog "Assembly load failed: $_" "WARN"
        Write-Error "Could not load UI components (.NET Framework required): $_"
        exit 1
    }
}

# ============================================================
# SECTION 2.5: Platform Abstraction (for cross-platform testing)
# ============================================================

<#
.SYNOPSIS
    Platform abstraction seam for OS-agnostic PowerShell 7 testing.

.DESCRIPTION
    HeadlessPlatform adapter enables tests to run on Linux CI without Windows dependencies.
    Per architecture-report.html Candidate 3 (Strong recommendation).

    Future: WindowsPlatform adapter will encapsulate all Windows-specific APIs
    (WPF, Task Scheduler, Registry, explorer.exe).
#>

class HeadlessPlatform {
    [string] GetAppDataPath() {
        # Always return Unix-style cross-platform path for testing
        # Simulate Linux XDG Base Directory spec even when running on Windows
        # This allows tests to verify cross-platform behavior
        if ($env:HOME -and $env:HOME -notlike "C:\*") {
            # Running on actual Linux/Unix or HOME is set to Unix-style path
            return Join-Path $env:HOME ".local/share/DailyMotivationBrainHelper"
        }
        # Running on Windows - return Unix-style path for test compatibility
        # Use /tmp as base to avoid Windows-specific paths (C:\, AppData, etc.)
        return "/tmp/.local/share/DailyMotivationBrainHelper"
    }

    [void] OpenFolder([string]$path) {
        # No-op for headless testing
        Write-DLog "HeadlessPlatform: OpenFolder($path) - no-op"
    }

    [hashtable] ScheduleTask([hashtable]$params) {
        # Mock task scheduling
        Write-DLog "HeadlessPlatform: ScheduleTask - mock"
        return @{ Success = $true; TaskId = "headless-mock-" + [guid]::NewGuid().ToString("N").Substring(0, 16) }
    }

    [void] UnscheduleTask([string]$taskId) {
        # No-op for headless testing
        Write-DLog "HeadlessPlatform: UnscheduleTask($taskId) - no-op"
    }

    [void] RegisterContextMenu([string]$exePath) {
        # No-op for headless testing
        Write-DLog "HeadlessPlatform: RegisterContextMenu($exePath) - no-op"
    }

    [string] ShowDialog([string]$message, [string]$title, [string]$buttons, [string]$icon) {
        # Return default button for headless testing
        Write-DLog "HeadlessPlatform: ShowDialog - returning default"
        return "OK"
    }
}

# ============================================================
# SECTION 3: Configuration functions
# ============================================================

function Initialize-AppData {
    <#
    Creates platform-specific app data directory and default config files.
    Uses platform adapter if available (for cross-platform testing).
    Falls back to %APPDATA% on Windows, $HOME/.local/share on Linux.
    Re-resolves all paths from current environment so test redirects work (FIX-001).
    #>
    # Use platform adapter if injected (for testing), otherwise use environment
    if ($script:Platform) {
        $script:AppDataDir = $script:Platform.GetAppDataPath()
    }
    elseif ($env:APPDATA) {
        $script:AppDataDir = Join-Path $env:APPDATA "DailyMotivationBrainHelper"
    }
    else {
        # Linux fallback: XDG Base Directory spec
        $baseDir = if ($env:HOME) { $env:HOME } else { "~" }
        $script:AppDataDir = Join-Path $baseDir ".local/share/DailyMotivationBrainHelper"
    }
    $script:ConfigPath   = Join-Path $script:AppDataDir "config.json"
    $script:PopupCfgPath = Join-Path $script:AppDataDir "popup_config.json"
    $script:TasksPath    = Join-Path $script:AppDataDir "tasks.json"
    $script:LogPath      = Join-Path $script:AppDataDir "popup_log.txt"

    if (-not (Test-Path $script:AppDataDir)) {
        try {
            New-Item -ItemType Directory -Path $script:AppDataDir -Force -ErrorAction Stop | Out-Null
        }
        catch {
            $fallback = Join-Path $script:TempDir "DailyMotivationBrainHelper"
            Write-Warning "Initialize-AppData: Could not create '$script:AppDataDir'. Falling back to '$fallback'."
            New-Item -ItemType Directory -Path $fallback -Force | Out-Null
            $script:AppDataDir   = $fallback
            $script:ConfigPath   = Join-Path $script:AppDataDir "config.json"
            $script:PopupCfgPath = Join-Path $script:AppDataDir "popup_config.json"
            $script:TasksPath    = Join-Path $script:AppDataDir "tasks.json"
            $script:LogPath      = Join-Path $script:AppDataDir "popup_log.txt"
        }
    }

    # config.json - app settings (2-key schema per NFR-002)
    if (-not (Test-Path $script:ConfigPath)) {
        [ordered]@{
            default_trigger_hour   = 14
            task_warning_threshold = 5
        } | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
    }

    # popup_config.json - written by main/setfolder mode, read by /popup mode
    if (-not (Test-Path $script:PopupCfgPath)) {
        [ordered]@{
            glyph         = "[+]"
            title         = ""
            body          = ""
            explorer_path = ""
            folder_name   = ""
            task_id       = ""
        } | ConvertTo-Json | Set-Content -Path $script:PopupCfgPath -Encoding UTF8
    }

    # tasks.json
    if (-not (Test-Path $script:TasksPath)) {
        Set-Content -Path $script:TasksPath -Value "[]" -Encoding UTF8 -NoNewline
    }
}

function Get-Config {
    try {
        return Get-Content $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return [PSCustomObject]@{ default_trigger_hour = 14; task_warning_threshold = 5 }
    }
}

function Save-Config {
    param([PSCustomObject]$Config)
    $Config | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
}

function Get-PopupConfig {
    try {
        return Get-Content $script:PopupCfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch { return $null }
}

function Set-PopupConfig {
    param(
        [string]$Glyph,
        [string]$Title,
        [string]$Body,
        [string]$ExplorerPath,
        [string]$TaskId
    )
    [ordered]@{
        glyph         = $Glyph
        title         = $Title
        body          = $Body
        explorer_path = $ExplorerPath
        folder_name   = (Split-Path -Leaf $ExplorerPath)
        task_id       = $TaskId
    } | ConvertTo-Json | Set-Content -Path $script:PopupCfgPath -Encoding UTF8
}

function Write-OutcomeLog {
    param(
        [string]$TaskId,
        [string]$FolderName,
        [string]$FolderPath,
        [string]$Outcome,
        [int]$SnoozeCount = 0
    )
    $ts    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] | $TaskId | $FolderName | $FolderPath | $Outcome | $SnoozeCount"
    Add-Content -Path $script:LogPath -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Show-ErrorDialog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = "Daily Motivation Brain Helper"
    )
    try {
        [System.Windows.MessageBox]::Show($Message, $Title, "OK", "Error") | Out-Null
    }
    catch {
        try {
            [System.Windows.Forms.MessageBox]::Show($Message, $Title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
        catch { [Console]::Error.WriteLine("ERROR [$Title]: $Message") }
    }
}

# ============================================================
# SECTION 4: Task Scheduler functions
# ============================================================

function Get-TasksJson {
    $path = $script:TasksPath
    if (-not (Test-Path $path)) { return @() }
    try {
        $result = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        # FIX-003: Ensure consistent array handling for empty JSON arrays
        if ($null -eq $result) { return @() }
        return @($result)
    }
    catch { return @() }
}

function Save-TasksJson {
    param([object[]]$Tasks)
    $path = $script:TasksPath
    # FIX-003: explicit null/empty handling to avoid "null" or broken JSON
    if ($null -eq $Tasks -or $Tasks.Count -eq 0) {
        Set-Content -Path $path -Value '[]' -Encoding UTF8 -NoNewline
    }
    else {
        ConvertTo-Json -InputObject $Tasks -Depth 4 | Set-Content -Path $path -Encoding UTF8
    }
}

function New-MotivationTask {
    <#
    .SYNOPSIS
    Creates a Windows Scheduled Task and records it in tasks.json.
    The task action calls this same exe with /popup argument (-STA baked in by build).
    #>
    param(
        [Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)][datetime]$TriggerTime,
        [switch]$Force
    )

    # Duplicate check (B-16) - case-insensitive path, same date (GAP-006)
    $normalizedInput = [System.IO.Path]::GetFullPath($FolderPath).ToLowerInvariant()
    if (-not $Force) {
        $existing = Get-MotivationTasks | Where-Object {
            # Check property exists first (guard against malformed/legacy task objects)
            ($null -ne $_ -and $_.PSObject.Properties['folder_path']) -and
            $_.folder_path -and $_.folder_path.Length -gt 0 -and
            [System.IO.Path]::GetFullPath($_.folder_path).ToLowerInvariant() -eq $normalizedInput -and
            ([datetime]$_.scheduled_time).Date -eq $TriggerTime.Date -and
            $_.status -eq "PENDING"
        }
        if ($existing) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $true }
        }
    }

    # Use platform adapter if available (for cross-platform testing)
    if ($script:Platform) {
        # Platform adapter handles task scheduling
        $taskResult = $script:Platform.ScheduleTask(@{
            FolderPath = $FolderPath
            TriggerTime = $TriggerTime
            ExePath = if ($script:ExePath) { $script:ExePath } else { "DailyMotivation.exe" }
        })

        if (-not $taskResult.Success) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Platform adapter failed" }
        }

        $taskId = $taskResult.TaskId
        $taskName = "DailyMotivation_$taskId"
        $isNetworkPath = $false  # Platform adapter doesn't need network path detection
    }
    else {
        # Windows-specific Task Scheduler logic
        # Generate task ID with collision retry (GAP-007)
        $taskId   = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
        $taskName = "DailyMotivation_$taskId"
        $attempts = 0
        while ((Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) -and ($attempts -lt 5)) {
            $taskId   = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
            $taskName = "DailyMotivation_$taskId"
            $attempts++
        }

        # Task Scheduler action: call this exe directly with /popup
        # $script:ExePath is set at entry point to $MyInvocation.MyCommand.Path
        # Tests override $script:ExePath before calling this function
        $exeForTask = if ($script:ExePath) { $script:ExePath } else { "DailyMotivation.exe" }
        $action = New-ScheduledTaskAction -Execute $exeForTask -Argument "/popup"

        $trigger  = New-ScheduledTaskTrigger -Once -At $TriggerTime
        $settings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
            -MultipleInstances IgnoreNew

        # GAP-010: network path detection for RunLevel assignment
        $isUncPath     = $FolderPath -match '^\\\\[^\\]'
        $isMappedDrive = $false
        if ($FolderPath.Length -ge 2 -and $FolderPath[1] -eq ':') {
            try {
                $driveInfo     = [System.IO.DriveInfo]::new([string]$FolderPath[0])
                $isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
            }
            catch { $isMappedDrive = $false }
        }
        $isNetworkPath = $isUncPath -or $isMappedDrive
        $runLevel      = if ($isNetworkPath) { 'Highest' } else { 'Limited' }

        $principal = New-ScheduledTaskPrincipal `
            -UserId    $env:USERNAME `
            -LogonType Interactive   `
            -RunLevel  $runLevel

        try {
            Register-ScheduledTask `
                -TaskName    $taskName  `
                -Action      $action    `
                -Trigger     $trigger   `
                -Settings    $settings  `
                -Principal   $principal `
                -Description "Daily Motivation Brain Helper - $FolderPath" `
                -Force | Out-Null
        }
        catch {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $_.Exception.Message }
        }
    }

    # Persist to tasks.json
    $tasks   = @(Get-TasksJson)
    $newTask = [PSCustomObject]@{
        task_id        = $taskId
        task_name      = $taskName
        folder_path    = $FolderPath
        folder_name    = (Split-Path -Leaf $FolderPath)
        scheduled_time = $TriggerTime.ToString("yyyy-MM-ddTHH:mm:ss")
        created_at     = (Get-Date -Format "o")
        status         = "PENDING"
        snooze_count   = 0
    }
    $tasks = $tasks + $newTask
    Save-TasksJson $tasks

    return @{ Success = $true; TaskId = $taskId; IsDuplicate = $false; IsNetworkPath = $isNetworkPath }
}

function Sync-TaskStatuses {
    # Explicit reconciliation: check Windows Task Scheduler and update task statuses
    # Call this function when you need up-to-date status from the OS
    # Skip reconciliation if platform adapter is active (tests/headless mode)
    if ($script:Platform) { return }

    $tasks = @(Get-TasksJson)
    $changed = $false

    foreach ($t in $tasks) {
        if ($null -eq $t -or -not $t.PSObject.Properties) { continue }
        if ($t.status -eq "PENDING") {
            try {
                Get-ScheduledTask -TaskName $t.task_name -ErrorAction Stop | Out-Null
            }
            catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
                $t.status = "DELETED"   # task genuinely gone (ERR-008)
                $changed = $true
            }
            catch [System.UnauthorizedAccessException] {
                Write-Warning "Sync-TaskStatuses: access denied reading '$($t.task_name)'"
            }
            catch {
                Write-Warning "Sync-TaskStatuses: unexpected error for '$($t.task_name)': $_"
            }
        }
    }

    if ($changed) {
        Save-TasksJson $tasks
    }
}

function Get-MotivationTasks {
    # Pure reader - returns tasks from disk without side effects
    return @(Get-TasksJson)
}

function Remove-MotivationTask {
    param([Parameter(Mandatory)][string]$TaskId)
    $tasks  = Get-TasksJson
    $target = $tasks | Where-Object { $_.task_id -eq $TaskId }
    if (-not $target) { return $false }

    # Use platform adapter if available (for cross-platform testing)
    if ($script:Platform) {
        $script:Platform.UnscheduleTask($TaskId)
    }
    else {
        # Windows-specific Task Scheduler logic
        try {
            Unregister-ScheduledTask -TaskName $target.task_name -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-Warning "Remove-MotivationTask: '$($target.task_name)': $_"
        }
    }

    $tasks = $tasks | Where-Object { $_.task_id -ne $TaskId }
    Save-TasksJson $tasks
    return $true
}

# ============================================================================
# BUSINESS LOGIC - Hoisted from UI functions for testability
# ============================================================================

function Get-ScheduleTime {
    param(
        [Parameter(Mandatory)]
        [object]$TodayRadioControl
    )
    $cfg  = Get-Config
    $hour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { 14 }
    if ($TodayRadioControl.IsVisible -and $TodayRadioControl.IsChecked) {
        return (Get-Date).Date.AddHours($hour)
    }
    return (Get-Date).Date.AddDays(1).AddHours($hour)
}

function Update-TaskListUI {
    param(
        [Parameter(Mandatory)]
        [object]$TaskListControl,
        [Parameter(Mandatory)]
        [object]$NoTasksLabelControl
    )
    $tasks   = Get-MotivationTasks | Where-Object { $_.status -ne "DELETED" }
    $pending = @($tasks | Where-Object { $_.status -eq "PENDING" })
    $TaskListControl.ItemsSource          = $pending
    $NoTasksLabelControl.Visibility       = if ($pending.Count -eq 0) { "Visible" } else { "Collapsed" }
}

function Get-HistoryData {
    if (-not (Test-Path $script:LogPath)) { return @() }
    $lines = @(Get-Content $script:LogPath -Encoding UTF8 |
        Where-Object { $_ -match '^\[' } |
        Select-Object -Last 30)
    if (-not $lines -or $lines.Count -eq 0) { return @() }

    $items = foreach ($line in $lines) {
        $parts = $line -split '\s*\|\s*'
        if ($parts.Count -ge 5) {
            $outcome = $parts[4].Trim()
            [PSCustomObject]@{
                Timestamp      = $parts[0].Trim('[', ']')
                FolderName     = $parts[2].Trim()
                OutcomeDisplay = $outcome
                OutcomeColor   = switch ($outcome) {
                    "Opened"    { "#52B788" }
                    "Dismissed" { "#E07A5F" }
                    default     { "#8888A8" }
                }
            }
        }
    }
    return @($items)
}

function Update-HistoryUI {
    param(
        [Parameter(Mandatory)]
        [object]$HistoryListControl
    )
    $items = Get-HistoryData
    $HistoryListControl.ItemsSource = $items
}

function Start-UndoTimer {
    param(
        [Parameter(Mandatory)]
        [string]$TaskId,
        [Parameter(Mandatory)]
        [string]$ScheduledFor,
        [Parameter(Mandatory)]
        [object]$UndoLabelControl,
        [Parameter(Mandatory)]
        [object]$UndoProgressControl,
        [Parameter(Mandatory)]
        [object]$UndoBannerControl
    )
    $script:lastTaskId     = $TaskId
    $script:undoSeconds    = 30
    $UndoLabelControl.Text        = "Scheduled for $ScheduledFor - undo in 30s"
    $UndoProgressControl.Value    = 30
    $UndoBannerControl.Visibility = "Visible"
    $script:undoTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:undoTimer.Interval = [System.TimeSpan]::FromSeconds(1)
    $script:undoTimer.Add_Tick({
            $script:undoSeconds--
            $UndoProgressControl.Value = $script:undoSeconds
            $UndoLabelControl.Text     = "Scheduled - undo in $($script:undoSeconds)s"
            if ($script:undoSeconds -le 0) {
                $script:undoTimer.Stop()
                $UndoBannerControl.Visibility = "Collapsed"
                $script:lastTaskId     = $null
            }
        })
    $script:undoTimer.Start()
}

function Stop-UndoTimer {
    param(
        [Parameter(Mandatory)]
        [object]$UndoBannerControl
    )
    if ($script:undoTimer) { $script:undoTimer.Stop(); $script:undoTimer = $null }
    $UndoBannerControl.Visibility = "Collapsed"
}

function Set-SnoozeDuration {
    param(
        [Parameter(Mandatory)]
        [int]$Minutes,
        [Parameter(Mandatory)]
        [object]$SnoozeBtnControl
    )
    $script:snoozeMinutes       = $Minutes
    # Use if-else for .NET Framework 4.x compatibility (ps2exe target)
    if ($Minutes -lt 60) {
        $SnoozeBtnControl.Content = "Snooze ${Minutes}m"
    } else {
        $SnoozeBtnControl.Content = "Snooze 1h"
    }
}

function Invoke-FolderScheduling {
    <#
    .SYNOPSIS
        Schedules a folder for motivational popup with business logic extracted from UI.
    .DESCRIPTION
        Core scheduling logic extracted from Show-MainWindow's Do-Schedule nested function.
        Handles folder validation, duplicate detection, task creation, and popup config setup.
        UI concerns (MessageBox, task list refresh, undo timer) remain in the caller.
    .PARAMETER FolderPath
        The folder path to schedule.
    .PARAMETER TriggerTime
        When the popup should trigger.
    .PARAMETER Force
        Bypass duplicate detection and schedule anyway.
    .OUTPUTS
        Hashtable with Success, TaskId, IsDuplicate, IsNetworkPath keys.
    #>
    param(
        [Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)][datetime]$TriggerTime,
        [switch]$Force
    )

    # Detect network paths (UNC or mapped drives)
    $isUncPath = $FolderPath -match '^\\\\[^\\]'
    $isMappedDrive = $false
    if ($FolderPath.Length -ge 2 -and $FolderPath[1] -eq ':') {
        try {
            $driveInfo = [System.IO.DriveInfo]::new([string]$FolderPath[0])
            $isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
        }
        catch { $isMappedDrive = $false }
    }
    $isNetworkPath = $isUncPath -or $isMappedDrive

    # Validate folder path (skip for UNC paths which might not be accessible)
    if (-not $isUncPath -and -not (Test-Path $FolderPath -PathType Container)) {
        return @{
            Success = $false
            TaskId = $null
            IsDuplicate = $false
            IsNetworkPath = $isNetworkPath
            Error = "Folder not found: $FolderPath"
        }
    }

    # Get random motivational message
    $msg = Get-RandomMessage

    # Attempt to create task
    $result = New-MotivationTask -FolderPath $FolderPath -TriggerTime $TriggerTime

    # Handle duplicate detection
    if ($result.IsDuplicate) {
        if (-not $Force) {
            # Return duplicate status, let caller decide (e.g., show confirmation dialog)
            return @{
                Success = $false
                TaskId = $null
                IsDuplicate = $true
                IsNetworkPath = $isNetworkPath
            }
        }
        # Force scheduling despite duplicate
        $result = New-MotivationTask -FolderPath $FolderPath -TriggerTime $TriggerTime -Force
    }

    # Check if task creation succeeded
    if (-not $result.Success) {
        return @{
            Success = $false
            TaskId = $null
            IsDuplicate = $false
            IsNetworkPath = $isNetworkPath
            Error = $result.Error
        }
    }

    # Write popup config for the scheduled task
    Set-PopupConfig -Glyph $msg.Glyph -Title $msg.Title -Body $msg.Body `
        -ExplorerPath $FolderPath -TaskId $result.TaskId

    # REQ-010: Register context menu on successful scheduling
    if ($script:ExePath) {
        Register-ContextMenu -ExePath $script:ExePath
    }

    # Return success with all metadata
    return @{
        Success = $true
        TaskId = $result.TaskId
        IsDuplicate = $false
        IsNetworkPath = $isNetworkPath
    }
}

# ============================================================
# SECTION 5: Context Menu (HKCU registry verb, no COM, no admin)
# REQ-010: right-click on folder in Explorer -> "Set as tomorrow's folder"
# ============================================================

function Register-ContextMenu {
    param([string]$ExePath)
    $verbKey = "HKCU:\Software\Classes\Directory\shell\ScheduleMotivation"
    $cmdKey  = "$verbKey\command"
    try {
        New-Item -Path $verbKey -Force | Out-Null
        Set-ItemProperty -Path $verbKey -Name "(Default)" -Value "Set as tomorrow's folder (Daily Motivation)"
        New-Item -Path $cmdKey -Force | Out-Null
        Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value "`"$ExePath`" /setfolder `"%1`""
        Write-DLog "Context menu registered for: $ExePath"
    }
    catch {
        Write-DLog "Register-ContextMenu failed: $_" "WARN"
    }
}

function Unregister-ContextMenu {
    Remove-Item "HKCU:\Software\Classes\Directory\shell\ScheduleMotivation" `
        -Recurse -Force -ErrorAction SilentlyContinue
    Write-DLog "Context menu unregistered"
}

# ============================================================
# SECTION 6: Main Window XAML (inline from MainWindow.xaml)
# ============================================================
[xml]$MainXaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="MainWin"
    Title="Daily Motivation Brain Helper"
    Width="520" SizeToContent="Height"
    WindowStartupLocation="CenterScreen"
    ResizeMode="CanMinimize"
    Background="#0D1117"
    FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Base button style -->
        <Style x:Key="PrimaryBtn" TargetType="Button">
            <Setter Property="Background"   Value="#00BCD4"/>
            <Setter Property="Foreground"   Value="#0D1117"/>
            <Setter Property="FontSize"     Value="13"/>
            <Setter Property="FontWeight"   Value="SemiBold"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"      Value="18,8"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="Opacity"      Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6"
                                Opacity="{TemplateBinding Opacity}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.4"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryBtn" TargetType="Button">
            <Setter Property="Background"   Value="#1C1C2C"/>
            <Setter Property="Foreground"   Value="#8888A8"/>
            <Setter Property="FontSize"     Value="12"/>
            <Setter Property="BorderBrush"  Value="#2A2A42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"      Value="14,6"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border Background="#0D1117" Padding="28,24,28,24">
        <StackPanel>

            <!-- Header accent bar -->
            <Border Background="#00BCD4" Height="3" CornerRadius="2" Margin="0,0,0,20"/>

            <!-- Title -->
            <TextBlock Text="Daily Motivation Brain Helper"
                       FontSize="17" FontWeight="Bold" Foreground="#E8E8F4"
                       Margin="0,0,0,20"/>

            <!-- Last Folder Banner (B-01) - hidden until reimplemented -->
            <Border x:Name="LastFolderBanner"
                    Background="#111B22" BorderBrush="#00BCD4" BorderThickness="1"
                    CornerRadius="7" Padding="14,10" Margin="0,0,0,16"
                    Visibility="Collapsed">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" VerticalAlignment="Center">
                        <TextBlock Text="&#x1F4A1; Schedule same folder as last time?"
                                   FontSize="12" Foreground="#00BCD4" FontWeight="SemiBold"/>
                        <TextBlock x:Name="LastFolderPath"
                                   FontSize="11" Foreground="#6666A0"
                                   TextTrimming="CharacterEllipsis" MaxWidth="240"/>
                    </StackPanel>
                    <Button x:Name="LastFolderYesBtn" Grid.Column="1"
                            Content="Yes, Schedule" Style="{StaticResource PrimaryBtn}"
                            FontSize="11" Padding="10,5" Margin="10,0,6,0"
                            ToolTip="Schedule the same folder you used last time"/>
                    <Button x:Name="LastFolderDismissBtn" Grid.Column="2"
                            Content="&#x2715;" Style="{StaticResource SecondaryBtn}"
                            FontSize="11" Padding="8,5" Width="28"
                            ToolTip="Dismiss this suggestion"/>
                </Grid>
            </Border>

            <!-- Drop Zone + Select Folder -->
            <Border x:Name="DropZone"
                    Background="#111B22" BorderBrush="#2A2A42" BorderThickness="1"
                    CornerRadius="8" Padding="20,18" Margin="0,0,0,16"
                    AllowDrop="True">
                <StackPanel>
                    <TextBlock Text="Drop a folder here, or use the button below"
                               FontSize="12" Foreground="#4A4A6A"
                               HorizontalAlignment="Center" Margin="0,0,0,10"
                               ToolTip="Drag any folder from Windows Explorer and drop it here"/>
                    <Button x:Name="SelectFolderBtn"
                            Content="&#x1F4C2;  Select Folder"
                            Style="{StaticResource SecondaryBtn}"
                            HorizontalAlignment="Center" Padding="20,8"
                            ToolTip="Choose the folder you want to open at the scheduled time"/>
                    <TextBlock x:Name="SelectedPathLabel"
                               Text="No folder selected"
                               FontSize="11" Foreground="#4A4A6A"
                               HorizontalAlignment="Center" Margin="0,8,0,0"
                               TextTrimming="CharacterEllipsis"/>
                </StackPanel>
            </Border>

            <!-- Schedule Time Options -->
            <StackPanel Margin="0,0,0,16">
                <TextBlock Text="Schedule for:"
                           FontSize="12" Foreground="#8888A8" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal">
                    <RadioButton x:Name="TodayRadio"
                                 Content="Today at 2:00 PM"
                                 FontSize="12" Foreground="#E8E8F4"
                                 Margin="0,0,24,0"
                                 Visibility="Collapsed"
                                 ToolTip="Schedule this folder to open today at 2:00 PM"/>
                    <RadioButton x:Name="TomorrowRadio"
                                 Content="Tomorrow at 2:00 PM"
                                 FontSize="12" Foreground="#E8E8F4"
                                 IsChecked="True"
                                 ToolTip="Schedule this folder to open tomorrow at 2:00 PM"/>
                </StackPanel>
            </StackPanel>

            <!-- Schedule Button -->
            <Button x:Name="ScheduleBtn"
                    Content="Schedule"
                    Style="{StaticResource PrimaryBtn}"
                    IsEnabled="False"
                    HorizontalAlignment="Left"
                    Padding="28,10"
                    ToolTip="Create a reminder to open this folder at the scheduled time"/>

            <!-- Undo Banner (B-04) -->
            <Border x:Name="UndoBanner"
                    Background="#0E2A1A" BorderBrush="#2D6A4F" BorderThickness="1"
                    CornerRadius="7" Padding="14,10" Margin="0,14,0,0"
                    Visibility="Collapsed">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="UndoLabel"
                                   Text="&#x2713; Scheduled"
                                   FontSize="12" Foreground="#52B788" FontWeight="SemiBold"/>
                        <ProgressBar x:Name="UndoProgress"
                                     Height="3" Margin="0,4,0,0"
                                     Background="#1B3A2A" Foreground="#00BCD4"
                                     Maximum="30" Value="30"
                                     BorderThickness="0"/>
                    </StackPanel>
                    <Button x:Name="UndoBtn" Grid.Column="1"
                            Content="Undo"
                            Style="{StaticResource SecondaryBtn}"
                            FontSize="11" Padding="12,5" Margin="10,0,0,0"
                            ToolTip="Cancel the schedule you just created"/>
                </Grid>
            </Border>

            <!-- Divider -->
            <Border Background="#1F1F30" Height="1" Margin="0,20,0,16"/>

            <!-- Recent Folders (B-02) - hidden until reimplemented -->
            <StackPanel x:Name="RecentFoldersPanel" Visibility="Collapsed" Margin="0,0,0,16">
                <TextBlock Text="Recent Folders"
                           FontSize="12" FontWeight="SemiBold" Foreground="#8888A8" Margin="0,0,0,8"/>
                <ItemsControl x:Name="RecentFoldersList">
                    <ItemsControl.ItemTemplate>
                        <DataTemplate>
                            <Grid Margin="0,3">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="&#x1F4C1;" FontSize="13" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                    <TextBlock Text="{Binding FolderName}" FontSize="12" Foreground="#C8C8E8"/>
                                    <TextBlock Text="{Binding FolderPath}" FontSize="10" Foreground="#4A4A6A"
                                               TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                                <Button Grid.Column="2" Tag="{Binding FolderPath}"
                                        Content="Schedule Again"
                                        Style="{StaticResource SecondaryBtn}"
                                        FontSize="10" Padding="8,4"/>
                            </Grid>
                        </DataTemplate>
                    </ItemsControl.ItemTemplate>
                </ItemsControl>
            </StackPanel>

            <!-- Scheduled Tasks -->
            <TextBlock Text="Scheduled Tasks"
                       FontSize="12" FontWeight="SemiBold" Foreground="#8888A8" Margin="0,0,0,8"/>
            <ItemsControl x:Name="TaskList">
                <ItemsControl.ItemTemplate>
                    <DataTemplate>
                        <Grid Margin="0,4">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                <TextBlock Text="{Binding folder_name}" FontSize="12" Foreground="#C8C8E8"/>
                                <TextBlock Text="{Binding scheduled_time}" FontSize="10" Foreground="#4A4A6A"/>
                            </StackPanel>
                            <Border Grid.Column="1"
                                    Background="#1A2A3A" CornerRadius="4" Padding="6,2" Margin="8,0">
                                <TextBlock Text="{Binding status}" FontSize="10" Foreground="#00BCD4"/>
                            </Border>
                            <Button Grid.Column="2" Tag="{Binding task_id}"
                                    Content="&#x2715;"
                                    Style="{StaticResource SecondaryBtn}"
                                    Width="28" Padding="0"
                                    ToolTip="Remove this scheduled task permanently"/>
                        </Grid>
                    </DataTemplate>
                </ItemsControl.ItemTemplate>
            </ItemsControl>
            <TextBlock x:Name="NoTasksLabel"
                       Text="No tasks scheduled."
                       FontSize="11" Foreground="#3A3A5A"
                       Margin="0,4,0,0" Visibility="Visible"/>

            <!-- History Toggle (B-18) -->
            <Button x:Name="HistoryToggleBtn"
                    Content="&#x1F4CB;  View History"
                    Style="{StaticResource SecondaryBtn}"
                    HorizontalAlignment="Left"
                    Margin="0,16,0,0" Padding="12,6"
                    ToolTip="See a log of your past folder openings"/>

            <!-- History panel -->
            <Border x:Name="HistoryPanel"
                    Background="#0A0A14" BorderBrush="#2A2A42" BorderThickness="1"
                    CornerRadius="7" Padding="14,12" Margin="0,8,0,0"
                    Visibility="Collapsed">
                <StackPanel>
                    <Grid>
                        <TextBlock Text="History" FontSize="12" FontWeight="SemiBold" Foreground="#8888A8"/>
                        <Button x:Name="ClearHistoryBtn"
                                Content="Clear" HorizontalAlignment="Right"
                                Style="{StaticResource SecondaryBtn}"
                                FontSize="10" Padding="8,3"
                                ToolTip="Clear all history entries"/>
                    </Grid>
                    <ItemsControl x:Name="HistoryList" Margin="0,8,0,0">
                        <ItemsControl.ItemTemplate>
                            <DataTemplate>
                                <Grid Margin="0,3">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="130"/>
                                        <ColumnDefinition Width="120"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="{Binding Timestamp}" FontSize="10" Foreground="#4A4A6A" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Column="1" Text="{Binding FolderName}" FontSize="11" Foreground="#C8C8E8" VerticalAlignment="Center"
                                               TextTrimming="CharacterEllipsis"/>
                                    <TextBlock Grid.Column="2" Text="{Binding OutcomeDisplay}" FontSize="11" VerticalAlignment="Center"
                                               Foreground="{Binding OutcomeColor}"/>
                                </Grid>
                            </DataTemplate>
                        </ItemsControl.ItemTemplate>
                    </ItemsControl>
                </StackPanel>
            </Border>

        </StackPanel>
    </Border>
</Window>
'@

# ============================================================
# SECTION 7: Main Window Logic
# ============================================================

function Show-MainWindow {
    # Check Task Scheduler service
    $schedSvc = Get-Service -Name Schedule -ErrorAction SilentlyContinue
    if ($schedSvc -and $schedSvc.Status -ne "Running") {
        $fix = [System.Windows.MessageBox]::Show(
            "Windows Task Scheduler is not running.`n`nThis app requires it to schedule folder openings.`n`nWould you like to start the service now?",
            "Task Scheduler Required", "YesNo", "Warning")
        if ($fix -eq "Yes") {
            try { Start-Service Schedule -ErrorAction Stop }
            catch {
                Show-ErrorDialog "Could not start Task Scheduler. Please run Services.msc and start 'Task Scheduler' manually."
                return
            }
        }
        else { return }
    }

    # Build window from inline XAML
    # Strip x:Name on root Window (harmless but keeps loader clean)
    $localXaml = $MainXaml.Clone()
    try { $localXaml.Window.RemoveAttribute("x:Name") } catch {}
    $reader = [System.Xml.XmlNodeReader]::new($localXaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    if ($null -eq $window -or $window -isnot [System.Windows.Window]) {
        Show-ErrorDialog "UI failed to load. Please reinstall the application."
        return
    }

    function Find { param($n) $window.FindName($n) }

    $dropZone          = Find "DropZone"
    $selectFolderBtn   = Find "SelectFolderBtn"
    $selectedPathLabel = Find "SelectedPathLabel"
    $todayRadio        = Find "TodayRadio"
    $scheduleBtn       = Find "ScheduleBtn"
    $lastFolderBanner  = Find "LastFolderBanner"   # kept in XAML; hidden (TODO: B-01)
    $undoBanner        = Find "UndoBanner"
    $undoLabel         = Find "UndoLabel"
    $undoProgress      = Find "UndoProgress"
    $undoBtn           = Find "UndoBtn"
    $taskList          = Find "TaskList"
    $noTasksLabel      = Find "NoTasksLabel"
    $historyToggleBtn  = Find "HistoryToggleBtn"
    $historyPanel      = Find "HistoryPanel"
    $historyList       = Find "HistoryList"
    $clearHistoryBtn   = Find "ClearHistoryBtn"

    # Features not yet reimplemented - keep panels hidden
    $lastFolderBanner.Visibility                  = "Collapsed"
    (Find "RecentFoldersPanel").Visibility         = "Collapsed"

    # State
    $script:selectedPath = ""
    $script:lastTaskId   = $null
    $script:undoTimer    = $null
    $script:undoSeconds  = 30

    function Set-SelectedPath {
        param([string]$Path)
        if (-not (Test-Path $Path -PathType Container)) {
            [System.Windows.MessageBox]::Show(
                "That path does not exist or is not a folder:`n$Path",
                "Invalid Folder", "OK", "Warning") | Out-Null
            return
        }
        $script:selectedPath          = $Path
        $selectedPathLabel.Text       = $Path
        $selectedPathLabel.Foreground = "#C8C8E8"
        $scheduleBtn.IsEnabled        = $true
    }

    function Do-Schedule {
        param([string]$FolderPath)
        $triggerTime = Get-ScheduleTime -TodayRadioControl $todayRadio

        # Attempt to schedule the folder (business logic extracted to Invoke-FolderScheduling)
        $result = Invoke-FolderScheduling -FolderPath $FolderPath -TriggerTime $triggerTime

        # Handle validation errors
        if (-not $result.Success -and -not $result.IsDuplicate) {
            if ($result.Error) {
                [System.Windows.MessageBox]::Show($result.Error, "Invalid Folder", "OK", "Warning") | Out-Null
            }
            else {
                Show-ErrorDialog "Could not create the scheduled task."
            }
            return
        }

        # Handle duplicate detection with user confirmation
        if ($result.IsDuplicate) {
            $dateLabel = $triggerTime.ToString("dddd, MMMM d")
            $confirm = [System.Windows.MessageBox]::Show(
                "This folder is already scheduled for $dateLabel.`n`nSchedule again anyway?",
                "Already Scheduled", "YesNo", "Question")
            if ($confirm -eq "No") { return }

            # Force scheduling despite duplicate
            $result = Invoke-FolderScheduling -FolderPath $FolderPath -TriggerTime $triggerTime -Force
            if (-not $result.Success) {
                Show-ErrorDialog "Could not create the scheduled task.`n$($result.Error)"
                return
            }
        }

        # Show network path warning if applicable
        if ($result.IsNetworkPath) {
            [System.Windows.MessageBox]::Show(
                "Scheduled, but '$FolderPath' is a network location. The popup may fail if the share is unavailable at trigger time.`n`nTip: Use a UNC path instead of a mapped drive letter.",
                "Network Path Warning", "OK", "Warning") | Out-Null
        }

        # Update UI
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
        $dateLabel = $triggerTime.ToString("dddd 'at' h:mm tt")
        Start-UndoTimer -TaskId $result.TaskId -ScheduledFor $dateLabel -UndoLabelControl $undoLabel -UndoProgressControl $undoProgress -UndoBannerControl $undoBanner
    }

    # Show Today radio only before trigger hour
    $cfg  = Get-Config
    $hour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { 14 }
    if ((Get-Date).Hour -lt $hour) { $todayRadio.Visibility = "Visible" }

    # --- Event handlers ---
    $selectFolderBtn.Add_Click({
            $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
            $dialog.Description         = "Select the folder you want to open tomorrow"
            $dialog.ShowNewFolderButton = $false
            if ($dialog.ShowDialog() -eq "OK") { Set-SelectedPath $dialog.SelectedPath }
        })

    $dropZone.Add_PreviewDragOver({
            param($s, $e)
            $e.Effects = if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
                [System.Windows.DragDropEffects]::Copy
            }
            else { [System.Windows.DragDropEffects]::None }
            $e.Handled = $true
        })

    $dropZone.Add_Drop({
            param($s, $e)
            if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
                $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
                if ($dropped.Count -gt 0 -and (Test-Path $dropped[0] -PathType Container)) {
                    Set-SelectedPath $dropped[0]
                }
                else {
                    [System.Windows.MessageBox]::Show("Please drop a folder, not a file.",
                        "Not a Folder", "OK", "Warning") | Out-Null
                }
            }
        })

    $scheduleBtn.Add_Click({
            if ($script:selectedPath) { Do-Schedule -FolderPath $script:selectedPath }
        })

    $undoBtn.Add_Click({
            if ($script:lastTaskId) {
                Stop-UndoTimer -UndoBannerControl $undoBanner
                Remove-MotivationTask -TaskId $script:lastTaskId
                $script:lastTaskId     = $null
                Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
                $scheduleBtn.IsEnabled = ($script:selectedPath -ne "")
            }
        })

    $taskList.Add_PreviewMouseLeftButtonUp({
            param($s, $e)
            $container = $e.OriginalSource
            while ($container -and $container -isnot [System.Windows.Controls.Button]) {
                $container = $container.Parent
                if (-not $container) { break }
            }
            if ($container -and $container.Tag) {
                $confirm = [System.Windows.MessageBox]::Show(
                    "Remove this scheduled task? This cannot be undone.",
                    "Confirm Delete", "YesNo", "Warning")
                if ($confirm -eq "Yes") {
                    Remove-MotivationTask -TaskId $container.Tag
                    Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
                }
            }
        })

    $historyToggleBtn.Add_Click({
            if ($historyPanel.Visibility -eq "Visible") {
                $historyPanel.Visibility  = "Collapsed"
                $historyToggleBtn.Content = "View History"
            }
            else {
                Update-HistoryUI -HistoryListControl $historyList
                $historyPanel.Visibility  = "Visible"
                $historyToggleBtn.Content = "Hide History"
            }
        })

    $clearHistoryBtn.Add_Click({
            $confirm = [System.Windows.MessageBox]::Show(
                "Clear all history entries? This cannot be undone.",
                "Clear History", "YesNo", "Question")
            if ($confirm -eq "Yes") {
                if (Test-Path $script:LogPath) { Clear-Content $script:LogPath }
                Update-HistoryUI -HistoryListControl $historyList
            }
        })

    # Reconcile task statuses with Windows Task Scheduler before displaying
    Sync-TaskStatuses
    Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
    $window.ShowDialog() | Out-Null
}

# ============================================================
# SECTION 8: Popup Window XAML (inline from DailyMotivation.ps1)
# ============================================================
[xml]$PopupXaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    WindowStyle="None"
    AllowsTransparency="True"
    Background="Transparent"
    Width="500"
    SizeToContent="Height"
    WindowStartupLocation="CenterScreen"
    Topmost="True"
    ShowInTaskbar="False"
    ResizeMode="NoResize"
    Opacity="0">

    <Border Background="#14141F" CornerRadius="14" Padding="32,28,32,28">
        <Border.Effect>
            <DropShadowEffect Color="Black" BlurRadius="48" ShadowDepth="0" Opacity="0.85"/>
        </Border.Effect>
        <StackPanel>
            <Border Background="#00BCD4" Height="3" CornerRadius="2" Margin="0,0,0,22"/>

            <!-- Normal mode -->
            <StackPanel x:Name="NormalPanel">
                <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                    <TextBlock x:Name="GlyphText" FontSize="26" Foreground="#00BCD4"
                               VerticalAlignment="Center" Margin="0,0,12,0"/>
                    <TextBlock x:Name="TitleText" FontSize="19" FontWeight="Bold"
                               Foreground="#E8E8F4" VerticalAlignment="Center"
                               TextWrapping="Wrap" MaxWidth="380"/>
                </StackPanel>
                <TextBlock x:Name="BodyText" FontSize="14" Foreground="#8888A8"
                           TextWrapping="Wrap" LineHeight="23" Margin="0,0,0,6"/>
                <!-- B-12: folder name subtitle -->
                <TextBlock x:Name="FolderNameText" FontSize="12" Foreground="#5A5A7A"
                           TextWrapping="Wrap" Margin="0,0,0,22" Visibility="Collapsed"/>
                <Border Background="#1F1F30" Height="1" Margin="0,0,0,18"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,22">
                    <TextBlock Text="Auto-opening in " FontSize="12" Foreground="#3E3E58" VerticalAlignment="Center"/>
                    <TextBlock x:Name="CountdownText" Text="20" FontSize="12" FontWeight="Bold"
                               Foreground="#00BCD4" VerticalAlignment="Center"/>
                    <TextBlock Text="s" FontSize="12" Foreground="#3E3E58" VerticalAlignment="Center"/>
                </StackPanel>
                <!-- Buttons -->
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <!-- B-11: Dismiss for Today -->
                    <Button x:Name="DismissBtn" Content="Dismiss for Today"
                            Width="130" Height="36" Foreground="#3E3E58" FontSize="11"
                            Background="#14141F" BorderBrush="#2A2A42" BorderThickness="1"
                            Cursor="Hand" Margin="0,0,8,0">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border Background="{TemplateBinding Background}"
                                        BorderBrush="{TemplateBinding BorderBrush}"
                                        BorderThickness="{TemplateBinding BorderThickness}"
                                        CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                    <!-- B-10: Snooze split-button -->
                    <StackPanel Orientation="Horizontal" Margin="0,0,8,0">
                        <Button x:Name="SnoozeBtn" Content="Snooze 5m" Height="36"
                                Foreground="#555570" FontSize="12" FontWeight="SemiBold"
                                Background="#1C1C2C" BorderBrush="#2A2A42"
                                BorderThickness="1,1,0,1" Cursor="Hand" Padding="10,0">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border Background="{TemplateBinding Background}"
                                            BorderBrush="{TemplateBinding BorderBrush}"
                                            BorderThickness="{TemplateBinding BorderThickness}"
                                            CornerRadius="7,0,0,7">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                </ControlTemplate>
                            </Button.Template>
                        </Button>
                        <Button x:Name="SnoozeDropBtn" Content="v" Width="26" Height="36"
                                Foreground="#555570" FontSize="10"
                                Background="#1C1C2C" BorderBrush="#2A2A42" BorderThickness="1"
                                Cursor="Hand">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border Background="{TemplateBinding Background}"
                                            BorderBrush="{TemplateBinding BorderBrush}"
                                            BorderThickness="{TemplateBinding BorderThickness}"
                                            CornerRadius="0,7,7,0">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                </ControlTemplate>
                            </Button.Template>
                            <Button.ContextMenu>
                                <ContextMenu Background="#1C1C2C" BorderBrush="#2A2A42">
                                    <MenuItem x:Name="Snooze5"  Header=" 5 minutes (default)" Foreground="#E8E8F4" FontSize="12"/>
                                    <MenuItem x:Name="Snooze15" Header=" 15 minutes"           Foreground="#E8E8F4" FontSize="12"/>
                                    <MenuItem x:Name="Snooze30" Header=" 30 minutes"           Foreground="#E8E8F4" FontSize="12"/>
                                    <MenuItem x:Name="Snooze60" Header=" 1 hour"               Foreground="#E8E8F4" FontSize="12"/>
                                </ContextMenu>
                            </Button.ContextMenu>
                        </Button>
                    </StackPanel>
                    <!-- Open Folder -->
                    <Button x:Name="LetsGoBtn" Content="Open Folder >" Width="130" Height="36"
                            Foreground="#0D1117" FontSize="13" FontWeight="Bold"
                            Background="#00BCD4" BorderThickness="0" Cursor="Hand">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border Background="{TemplateBinding Background}" CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
            </StackPanel>

            <!-- B-05: Path missing mode -->
            <StackPanel x:Name="PathMissingPanel" Visibility="Collapsed">
                <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                    <TextBlock Text="[!]" FontSize="26" Foreground="#F4A261"
                               VerticalAlignment="Center" Margin="0,0,12,0"/>
                    <TextBlock Text="Folder Not Found" FontSize="19" FontWeight="Bold"
                               Foreground="#E8E8F4" VerticalAlignment="Center"/>
                </StackPanel>
                <TextBlock Text="The folder you scheduled was moved or deleted."
                           FontSize="14" Foreground="#8888A8" TextWrapping="Wrap" Margin="0,0,0,6"/>
                <TextBlock x:Name="MissingPathLabel" FontSize="12" Foreground="#4A4A6A"
                           TextWrapping="Wrap" Margin="0,0,0,22"/>
                <Border Background="#1F1F30" Height="1" Margin="0,0,0,18"/>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="PathDismissBtn" Content="Dismiss" Width="100" Height="36"
                            Foreground="#555570" FontSize="12"
                            Background="#1C1C2C" BorderBrush="#2A2A42" BorderThickness="1"
                            Cursor="Hand" Margin="0,0,10,0">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border Background="{TemplateBinding Background}"
                                        BorderBrush="{TemplateBinding BorderBrush}"
                                        BorderThickness="{TemplateBinding BorderThickness}"
                                        CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                    <Button x:Name="RePickBtn" Content="Choose New Location" Width="160" Height="36"
                            Foreground="#0D1117" FontSize="12" FontWeight="Bold"
                            Background="#00BCD4" BorderThickness="0" Cursor="Hand">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border Background="{TemplateBinding Background}" CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
            </StackPanel>

        </StackPanel>
    </Border>
</Window>
'@

# ============================================================
# SECTION 9: Popup Window Logic
# ============================================================

function Show-PopupWindow {
    $configPath = $script:PopupCfgPath

    # Named mutex - one popup at a time (SSOT-006 / TASK-006)
    $mutexName  = "Global\DailyMotivationBrainHelperPopup"
    $mutexOwned = $false
    $mutex      = $null
    try {
        $mutex      = [System.Threading.Mutex]::new($false, $mutexName)
        $mutexOwned = $mutex.WaitOne(0)
        if (-not $mutexOwned) {
            Write-DLog "Mutex held - another popup running. Exiting." "WARN"
            return
        }
        Write-DLog "Mutex acquired"
    }
    catch [System.Threading.AbandonedMutexException] {
        $mutexOwned = $true
        Start-Sleep -Milliseconds 500
        $stale = Get-Process | Where-Object { $_.MainWindowTitle -like "*Daily Motivation*" -and $_.Id -ne $PID }
        if ($stale) {
            Write-DLog "Stale popup visible - exiting to avoid duplicate" "WARN"
            if ($mutex) { try { $mutex.ReleaseMutex() } catch {} }
            return
        }
    }
    catch { Write-DLog "Mutex error (non-fatal): $_" "WARN" }

    # Load popup config
    $config = [PSCustomObject]@{
        title         = "Time to Show Up"
        body          = "Every great outcome starts with showing up. Let's make this session count."
        glyph         = "[+]"
        explorer_path = ""
        folder_name   = ""
        task_id       = ""
    }
    if (Test-Path $configPath) {
        try {
            $loaded = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $config = $loaded
            Write-DLog "Popup config loaded. title='$($config.title)' folder='$($config.folder_name)'"
        }
        catch { Write-DLog "Config parse failed: $($_.Exception.Message)" "WARN" }
    }

    # Exit silently if no folder has been configured (GAP-003b)
    if (-not $config.explorer_path -or $config.explorer_path -eq "") {
        Write-DLog "No folder configured - exiting" "WARN"
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return
    }

    $script:pathMissing = -not (Test-Path $config.explorer_path -PathType Container)
    if ($script:pathMissing) { Write-DLog "Path missing: '$($config.explorer_path)'" "WARN" }

    # Build popup window
    $reader = [System.Xml.XmlNodeReader]::new($PopupXaml)
    try {
        $window = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        Write-DLog "FATAL: Popup XAML build failed - $_" "ERROR"
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return
    }
    if ($null -eq $window) {
        Write-DLog "FATAL: XamlReader returned null" "ERROR"
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return
    }

    function Find { param($n) $window.FindName($n) }

    $normalPanel      = Find "NormalPanel"
    $pathMissingPanel = Find "PathMissingPanel"
    $glyphText        = Find "GlyphText"
    $titleText        = Find "TitleText"
    $bodyText         = Find "BodyText"
    $folderNameText   = Find "FolderNameText"
    $countdownText    = Find "CountdownText"
    $letsGoBtn        = Find "LetsGoBtn"
    $snoozeBtn        = Find "SnoozeBtn"
    $snoozeDropBtn    = Find "SnoozeDropBtn"
    $snooze5          = Find "Snooze5"
    $snooze15         = Find "Snooze15"
    $snooze30         = Find "Snooze30"
    $snooze60         = Find "Snooze60"
    $dismissBtn       = Find "DismissBtn"
    $missingPathLabel = Find "MissingPathLabel"
    $pathDismissBtn   = Find "PathDismissBtn"
    $rePickBtn        = Find "RePickBtn"

    # Populate UI based on mode (normal vs path-missing)
    if ($script:pathMissing) {
        $normalPanel.Visibility      = "Collapsed"
        $pathMissingPanel.Visibility = "Visible"
        $missingPathLabel.Text       = "Was looking for: $($config.explorer_path)"
    }
    else {
        $glyphText.Text = $config.glyph
        $titleText.Text = $config.title
        $bodyText.Text  = $config.body
        if ($config.folder_name -and $config.folder_name -ne "") {
            # UB-004: UNC root shares show full path instead of leaf name
            $displayName = if ($config.explorer_path -match '^\\\\[^\\]+\\[^\\]+$') {
                $config.explorer_path
            }
            else { $config.folder_name }
            $folderNameText.Text       = "Opening: $displayName"
            $folderNameText.Visibility = "Visible"
        }
    }

    # State
    $script:openExplorer    = $true
    $script:remaining       = 20
    $script:snoozeMinutes   = 5
    $script:firstTick       = $true
    $script:snoozeCount     = 0
    $script:newExplorerPath = ""
    $script:windowClosed    = $false   # UB-002: guard against queued dispatcher tick

    # Fade-in animation
    $window.Add_Loaded({
            try {
                $anim = [System.Windows.Media.Animation.DoubleAnimation]::new(
                    0, 1, [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(300)))
                $window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
            }
            catch { Write-DLog "Fade-in failed: $_" "WARN" }
        })

    # Countdown timer (normal mode only)
    if (-not $script:pathMissing) {
        $timer = [System.Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [System.TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
                try {
                    if ($script:firstTick) { Write-DLog "Countdown running"; $script:firstTick = $false }
                    $script:remaining--
                    $countdownText.Text = $script:remaining
                    if ($script:remaining -le 0 -and -not $script:windowClosed) {
                        $timer.Stop()
                        $script:windowClosed = $true
                        $script:openExplorer = $true
                        $window.Close()
                    }
                }
                catch {
                    Write-DLog "Timer error: $_" "ERROR"
                    $timer.Stop()
                    if (-not $script:windowClosed -and $window.IsLoaded) {
                        $script:windowClosed = $true; $window.Close()
                    }
                }
            })
        $timer.Start()
        Write-DLog "Countdown timer started"
    }

    # Snooze duration helpers
    $snoozeDropBtn.Add_Click({ $snoozeDropBtn.ContextMenu.IsOpen = $true })

    $snooze5.Add_Click({  Set-SnoozeDuration -Minutes 5 -SnoozeBtnControl $snoozeBtn  })
    $snooze15.Add_Click({ Set-SnoozeDuration -Minutes 15 -SnoozeBtnControl $snoozeBtn })
    $snooze30.Add_Click({ Set-SnoozeDuration -Minutes 30 -SnoozeBtnControl $snoozeBtn })
    $snooze60.Add_Click({ Set-SnoozeDuration -Minutes 60 -SnoozeBtnControl $snoozeBtn })

    # Snooze button
    $snoozeBtn.Add_Click({
            try {
                Write-DLog "Snooze clicked ($($script:snoozeMinutes) min)"
                if (-not $script:pathMissing) { $timer.Stop() }
                $script:snoozeCount++
                $script:openExplorer = $false
                $snoozeTime = (Get-Date).AddMinutes($script:snoozeMinutes)
                New-MotivationTask -FolderPath $config.explorer_path -TriggerTime $snoozeTime -Force | Out-Null
                Write-DLog "Snooze task created for $snoozeTime"
                $window.Close()
            }
            catch { Write-DLog "Snooze error: $_" "ERROR"; $window.Close() }
        })

    # Dismiss for Today
    $dismissBtn.Add_Click({
            try {
                Write-DLog "Dismiss for Today clicked"
                if (-not $script:pathMissing) { $timer.Stop() }
                $script:openExplorer = $false
                if ($config.explorer_path) {
                    $pending = Get-MotivationTasks | Where-Object {
                        $_.folder_path -eq $config.explorer_path -and $_.status -eq "PENDING"
                    }
                    foreach ($t in $pending) { Remove-MotivationTask -TaskId $t.task_id }
                }
                $window.Close()
            }
            catch { Write-DLog "Dismiss error: $_" "ERROR"; $window.Close() }
        })

    # Open Folder button
    $letsGoBtn.Add_Click({
            try {
                Write-DLog "Open Folder clicked"
                if (-not $script:pathMissing) { $timer.Stop() }
                $script:openExplorer = $true
                $window.Close()
            }
            catch { Write-DLog "LetsGo error: $_" "ERROR" }
        })

    # Path missing - Dismiss
    $pathDismissBtn.Add_Click({
            Write-DLog "Path-missing Dismiss clicked"
            $script:openExplorer = $false
            $window.Close()
        })

    # Path missing - Re-pick folder
    $rePickBtn.Add_Click({
            Write-DLog "Re-pick clicked"
            $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
            $dialog.Description         = "Choose the new location for this folder"
            $dialog.ShowNewFolderButton = $false
            if ($dialog.ShowDialog() -eq "OK") {
                $newPath = $dialog.SelectedPath
                Write-DLog "Re-pick: $newPath"
                try {
                    $c = Get-Content $configPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
                    $c.explorer_path = $newPath
                    $c.folder_name   = Split-Path -Leaf $newPath
                    $c | ConvertTo-Json | Set-Content $configPath -Encoding UTF8 -ErrorAction Stop
                    # ERR-002: only update state if write succeeded
                    $script:newExplorerPath = $newPath
                    $script:openExplorer    = $true
                    $window.Close()
                }
                catch {
                    Write-DLog "Config update failed: $_" "ERROR"
                    [System.Windows.MessageBox]::Show(
                        "Could not save the new folder path.`n`n$($_.Exception.Message)",
                        "Save Failed", "OK", "Error") | Out-Null
                }
            }
        })

    # Show popup
    Write-DLog "Calling ShowDialog()"
    try {
        $window.ShowDialog() | Out-Null
        Write-DLog "ShowDialog returned. openExplorer=$($script:openExplorer)"
    }
    catch { Write-DLog "ShowDialog threw: $_" "ERROR" }
    finally {
        if ($mutexOwned -and $mutex) {
            try { $mutex.ReleaseMutex(); Write-DLog "Mutex released" }
            catch { Write-DLog "Mutex release error: $_" "WARN" }
        }
    }

    # Post-close: open Explorer (REQ-009)
    $effectivePath = if ($script:newExplorerPath) { $script:newExplorerPath } else { $config.explorer_path }
    if ($script:openExplorer -and $effectivePath -and $effectivePath -ne "") {
        Write-DLog "Launching Explorer: $effectivePath"
        try {
            Start-Process "explorer.exe" -ArgumentList $effectivePath -ErrorAction Stop
            Write-DLog "Explorer launched"
        }
        catch {
            Write-DLog "Explorer launch failed: $_" "ERROR"
            [System.Windows.MessageBox]::Show(
                "Could not open the folder:`n$effectivePath`n`n$($_.Exception.Message)",
                "Error Opening Folder", "OK", "Error") | Out-Null
        }
    }

    # Log outcome
    $outcome = if ($script:pathMissing -and -not $script:openExplorer) { "PathMissing" }
               elseif ($script:openExplorer) { "Opened" }
               elseif ($script:snoozeCount -gt 0) { "Snoozed" }
               else { "Dismissed" }
    Write-OutcomeLog -TaskId $config.task_id -FolderName $config.folder_name `
        -FolderPath $effectivePath -Outcome $outcome -SnoozeCount $script:snoozeCount

    Write-DLog "====== POPUP COMPLETE: $outcome ======"
}

# ============================================================
# SECTION 10: Embedded messages + Get-RandomMessage
# (replaces src/data/messages.json)
# ============================================================
$Messages = @(
    [PSCustomObject]@{ Glyph = "[+]"; Title = "Time to Show Up";     Body = "Every great outcome starts with showing up. You already did the hardest part - let's make this session count." }
    [PSCustomObject]@{ Glyph = "[>]"; Title = "One Step Forward";    Body = "You don't have to see the whole staircase. Just take the next step. This folder is that step." }
    [PSCustomObject]@{ Glyph = "[*]"; Title = "Small Progress Counts"; Body = "Small progress is still progress. Open the folder and do one thing. That's enough." }
    [PSCustomObject]@{ Glyph = "[-]"; Title = "Back in the Zone";    Body = "The hardest part of any work session is starting. You've already decided to start. Now let's go." }
    [PSCustomObject]@{ Glyph = "[o]"; Title = "Focus Time";          Body = "Set a timer for 25 minutes. Open the folder. Just start. Everything else can wait." }
    [PSCustomObject]@{ Glyph = "[^]"; Title = "You Planned This";    Body = "Yesterday-you knew today-you would need a nudge. Here it is. Don't let yesterday-you down." }
    [PSCustomObject]@{ Glyph = "[#]"; Title = "Build the Streak";    Body = "Consistency beats intensity every time. Show up today, and tomorrow gets easier." }
    [PSCustomObject]@{ Glyph = "[!]"; Title = "It Matters";          Body = "The work in this folder matters. Not to the whole world maybe - but to you, and to the people counting on you." }
    [PSCustomObject]@{ Glyph = "[~]"; Title = "Just Look";           Body = "You don't have to do everything today. Just open the folder and look. Momentum will follow." }
    [PSCustomObject]@{ Glyph = "[=]"; Title = "Steady Wins";         Body = "Slow, steady, and deliberate is how great work gets done. Today's session is a brick in something bigger." }
)

function Get-RandomMessage {
    return $Messages | Get-Random
}

# ============================================================
# SECTION 11: Entry Point
# (-NoRun switch skips this block; used when dot-sourcing in tests)
# ============================================================
if (-not $NoRun) {
    # Load Windows assemblies (WPF, WinForms) - required for UI modes
    if ($script:IsWindowsPlatform) {
        Initialize-WindowsAssemblies
    }

    # Use if-else for .NET Framework 4.x compatibility (ps2exe target)
    $platformName = if ($script:IsWindowsPlatform) { 'Windows' } else { 'Linux' }
    Write-DLog "====== STARTED Mode=$Mode PID=$PID PSVer=$($PSVersionTable.PSVersion) Platform=$platformName ======"

    # Capture exe path for Task Scheduler action and context menu registration.
    # PS2EXE sets $MyInvocation.MyCommand.Path to the compiled .exe path.
    # In tests: set $script:ExePath = "test-override.exe" before calling New-MotivationTask.
    $script:ExePath = $MyInvocation.MyCommand.Path

    Initialize-AppData

    switch ($Mode) {
        "/popup" {
            Show-PopupWindow
        }
        "/setfolder" {
            if ($FolderPath -and (Test-Path $FolderPath -PathType Container)) {
                $cfg         = Get-Config
                $triggerHour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { 14 }
                $triggerTime = (Get-Date).Date.AddDays(1).AddHours($triggerHour)
                $msg         = Get-RandomMessage
                $result      = New-MotivationTask -FolderPath $FolderPath -TriggerTime $triggerTime
                if ($result.Success) {
                    Set-PopupConfig -Glyph $msg.Glyph -Title $msg.Title -Body $msg.Body `
                        -ExplorerPath $FolderPath -TaskId $result.TaskId
                    [System.Windows.MessageBox]::Show(
                        "Scheduled! '$FolderPath' will open tomorrow at $($triggerHour):00.",
                        "Daily Motivation Brain Helper", "OK", "Information") | Out-Null
                }
            }
        }
        default {
            Show-MainWindow
        }
    }
}
