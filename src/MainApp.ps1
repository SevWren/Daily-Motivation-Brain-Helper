# =============================================================================
# MainApp.ps1 - Daily Motivation Brain Helper
# Main application entry point. Run with:
#   powershell.exe -STA -ExecutionPolicy Bypass -File MainApp.ps1
#
# TASK-001: Main Application Window + First-Run Welcome (B-07) + Tooltips (B-19)
# TASK-002: Folder Picker + Drag-and-Drop (B-09)
# TASK-003: Schedule Today/Tomorrow (B-03) + Duplicate Warning (B-16)
# TASK-004: Writes popup_config.json + Last Folder (B-01) + Folder Name (B-12)
# TASK-NEW-01: Undo Banner (B-04)
# TASK-008: Task List + Recent Folders (B-02)
# TASK-009: Task Deletion
# TASK-NEW-03: History Viewer (B-18)
# TASK-012: Task Scheduler health check at startup
# =============================================================================

#Requires -Version 5.1
Set-StrictMode -Version Latest

# --- Load WPF + WinForms ---
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
}
catch {
    [System.Windows.MessageBox]::Show(
        "Could not load UI components (.NET Framework required):`n$_",
        "Daily Motivation Brain Helper", "OK", "Error")
    exit 1
}

# --- Module paths ---
# $PSScriptRoot is an empty string when compiled with PS2EXE; it is only populated
# when the script is run directly via powershell.exe -File.  Fall back to the
# directory that contains the running executable so all relative paths still resolve.
$scriptDir = if ($PSScriptRoot -and $PSScriptRoot.Length -gt 0) {
    $PSScriptRoot
}
else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
$modulesDir = Join-Path $scriptDir "Modules"
try {
    Import-Module (Join-Path $modulesDir "ConfigManager.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $modulesDir "TaskScheduler.psm1") -Force -ErrorAction Stop
}
catch {
    # ERR-034: use shared Show-ErrorDialog once modules are available; fall back inline here
    # because Show-ErrorDialog itself lives in ConfigManager which hasn't loaded yet.
    [System.Windows.MessageBox]::Show(
        "Required modules failed to load. Please reinstall the application.`n`n$($_.Exception.Message)",
        "Startup Error", "OK", "Error")
    exit 1
}

# --- Initialize app data directory and default files ---
Initialize-AppData

# =============================================================================
# TASK-012: Check that Windows Task Scheduler service is running
# =============================================================================
$schedSvc = Get-Service -Name Schedule -ErrorAction SilentlyContinue
if ($schedSvc.Status -ne "Running") {
    $fix = [System.Windows.MessageBox]::Show(
        "Windows Task Scheduler is not running.`n`nThis app requires it to schedule folder openings.`n`nWould you like to start the service now?",
        "Task Scheduler Required", "YesNo", "Warning")
    if ($fix -eq "Yes") {
        try {
            Start-Service Schedule -ErrorAction Stop
        }
        catch {
            Show-ErrorDialog "Could not start Task Scheduler. Please run Services.msc and start 'Task Scheduler' manually." "Error"
            exit 1
        }
    }
    else { exit 0 }
}

# --- Load and parse XAML ---
$xamlPath = Join-Path $scriptDir "MainWindow.xaml"
try {
    [xml]$xaml = Get-Content $xamlPath -Raw -Encoding UTF8 -ErrorAction Stop
}
catch {
    Show-ErrorDialog "UI file missing. Please reinstall the application.`n`n$($_.Exception.Message)" "Startup Error"
    exit 1
}

# Strip x:Class if present (PowerShell loader doesn't support it)
$xaml.Window.RemoveAttribute("x:Class")

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
# GAP-005: validate the loaded object is actually a Window
if ($null -eq $window -or $window -isnot [System.Windows.Window]) {
    Show-ErrorDialog "UI failed to load (unexpected root element type). Please reinstall the application." "Startup Error"
    exit 1
}

# --- Get named controls ---
function Find { param($n) $window.FindName($n) }

$dropZone = Find "DropZone"
$selectFolderBtn = Find "SelectFolderBtn"
$selectedPathLabel = Find "SelectedPathLabel"
$todayRadio = Find "TodayRadio"
$tomorrowRadio = Find "TomorrowRadio"
$scheduleBtn = Find "ScheduleBtn"
$lastFolderBanner = Find "LastFolderBanner"
$lastFolderPath = Find "LastFolderPath"
$lastFolderYesBtn = Find "LastFolderYesBtn"
$lastFolderDismiss = Find "LastFolderDismissBtn"
$undoBanner = Find "UndoBanner"
$undoLabel = Find "UndoLabel"
$undoProgress = Find "UndoProgress"
$undoBtn = Find "UndoBtn"
$recentFoldersPanel = Find "RecentFoldersPanel"
$recentFoldersList = Find "RecentFoldersList"
$taskList = Find "TaskList"
$noTasksLabel = Find "NoTasksLabel"
$historyToggleBtn = Find "HistoryToggleBtn"
$historyPanel = Find "HistoryPanel"
$historyList = Find "HistoryList"
$clearHistoryBtn = Find "ClearHistoryBtn"

# --- State ---
$script:selectedPath = ""
$script:lastTaskId = $null
$script:undoTimer = $null
$script:undoSeconds = 30

# =============================================================================
# Helpers
# =============================================================================
function Set-SelectedPath {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Container)) {
        [System.Windows.MessageBox]::Show(
            "That path does not exist or is not a folder:`n$Path",
            "Invalid Folder", "OK", "Warning")
        return
    }
    $script:selectedPath = $Path
    $leafName = Split-Path -Leaf $Path
    $selectedPathLabel.Text = $Path
    $selectedPathLabel.Foreground = "#C8C8E8"
    $scheduleBtn.IsEnabled = $true
}

function Get-ScheduleTime {
    if ($todayRadio.IsVisible -and $todayRadio.IsChecked) {
        $today = (Get-Date).Date.AddHours(14)
        return $today
    }
    return (Get-Date).Date.AddDays(1).AddHours(14)
}

function Refresh-TaskList {
    $tasks = Get-MotivationTasks | Where-Object { $_.status -ne "DELETED" }
    $pending = $tasks | Where-Object { $_.status -eq "PENDING" }
    $taskList.ItemsSource = $pending
    $noTasksLabel.Visibility = if ($pending.Count -eq 0) { "Visible" } else { "Collapsed" }
}

function Refresh-RecentFolders {
    $recent = Get-RecentFolders
    if ($recent.Count -gt 0) {
        $items = $recent | ForEach-Object {
            [PSCustomObject]@{ FolderPath = $_; FolderName = (Split-Path -Leaf $_) }
        }
        $recentFoldersList.ItemsSource = $items
        $recentFoldersPanel.Visibility = "Visible"
    }
    else {
        $recentFoldersPanel.Visibility = "Collapsed"
    }
}

function Refresh-History {
    $entries = Get-OutcomeLog -Limit 30
    $items = $entries | ForEach-Object {
        $display = switch ($_.Outcome) {
            "Opened" { "✅ Opened" }
            "Snoozed" { "💤 Snoozed $($_.SnoozeCount)x" }
            "Dismissed" { "✖ Dismissed" }
            "PathMissing" { "⚠ Path Missing" }
            default { $_.Outcome }
        }
        $color = switch ($_.Outcome) {
            "Opened" { "#52B788" }
            "Dismissed" { "#E07A5F" }
            default { "#8888A8" }
        }
        [PSCustomObject]@{
            Timestamp      = $_.Timestamp
            FolderName     = $_.FolderName
            OutcomeDisplay = $display
            OutcomeColor   = $color
        }
    }
    $historyList.ItemsSource = $items
}

function Start-UndoTimer {
    param([string]$TaskId, [string]$ScheduledFor)
    $script:lastTaskId = $TaskId
    $script:undoSeconds = 30
    $undoLabel.Text = "✓ Scheduled for $ScheduledFor - take effect in 30s"
    $undoProgress.Value = 30
    $undoBanner.Visibility = "Visible"

    $script:undoTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:undoTimer.Interval = [System.TimeSpan]::FromSeconds(1)
    $script:undoTimer.Add_Tick({
            $script:undoSeconds--
            $undoProgress.Value = $script:undoSeconds
            $undoLabel.Text = "✓ Scheduled - undo in $($script:undoSeconds)s"
            if ($script:undoSeconds -le 0) {
                $script:undoTimer.Stop()
                $undoBanner.Visibility = "Collapsed"
                $script:lastTaskId = $null
            }
        })
    $script:undoTimer.Start()
}

function Stop-UndoTimer {
    if ($script:undoTimer) { $script:undoTimer.Stop(); $script:undoTimer = $null }
    $undoBanner.Visibility = "Collapsed"
}

function Do-Schedule {
    param([string]$FolderPath)
    if (-not (Test-Path $FolderPath -PathType Container)) {
        [System.Windows.MessageBox]::Show(
            "Folder not found: $FolderPath",
            "Invalid Folder", "OK", "Warning")
        return
    }

    $triggerTime = Get-ScheduleTime

    # --- Select a random motivational message ---
    $msg = Get-RandomMessage

    # --- Create the task (duplicate check inside New-MotivationTask) ---
    $result = New-MotivationTask -FolderPath $FolderPath -TriggerTime $triggerTime

    if ($result.IsDuplicate) {
        # B-16 warning
        $dateLabel = $triggerTime.ToString("dddd, MMMM d")
        $confirm = [System.Windows.MessageBox]::Show(
            "This folder is already scheduled for $dateLabel.`n`nSchedule again anyway?",
            "Already Scheduled", "YesNo", "Question")
        if ($confirm -eq "No") { return }
        $result = New-MotivationTask -FolderPath $FolderPath -TriggerTime $triggerTime -Force
    }

    if (-not $result.Success) {
        [System.Windows.MessageBox]::Show(
            "Could not create the scheduled task.`n$($result.Error)",
            "Scheduling Failed", "OK", "Error")
        return
    }

    # GAP-010: Warn if the scheduled folder is on a network path.
    # Mapped drives may not be available when Task Scheduler fires; UNC paths are safer.
    if ($result.IsNetworkPath) {
        [System.Windows.MessageBox]::Show(
            "Scheduled successfully, but '$FolderPath' appears to be a network location.`n`n" +
            "The popup may fail to open the folder if the network share is unavailable or the drive is not mapped at 2 PM.`n`n" +
            "Tip: Use the full UNC path (\\\\server\\share\\...) instead of a mapped drive letter for best reliability.",
            "Network Path Warning", "OK", "Warning")
    }

    # --- Write popup_config.json (TASK-004) ---
    Set-PopupConfig -Glyph $msg.glyph -Title $msg.title -Body $msg.body `
        -ExplorerPath $FolderPath -TaskId $result.TaskId

    # --- Persist last folder + recent folders (B-01, B-02) ---
    Set-LastFolder -FolderPath $FolderPath
    Add-RecentFolder -FolderPath $FolderPath

    # --- Update UI ---
    Refresh-TaskList
    Refresh-RecentFolders
    $dateLabel = $triggerTime.ToString("dddd 'at' h:mm tt")
    Start-UndoTimer -TaskId $result.TaskId -ScheduledFor $dateLabel
}

# =============================================================================
# TASK-010: Random message selection from messages.json
# =============================================================================
function Get-RandomMessage {
    $messagesPath = Join-Path $env:APPDATA "DailyMotivationBrainHelper\messages.json"
    $srcPath = if (-not [string]::IsNullOrEmpty($scriptDir)) { Join-Path $scriptDir "data\messages.json" } else { $null }

    # Copy bundled messages on first run (ERR-005b: ensure dest dir exists first)
    if (-not (Test-Path $messagesPath) -and (Test-Path $srcPath)) {
        $destDir = Split-Path $messagesPath
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item $srcPath $messagesPath -Force
    }

    if (Test-Path $messagesPath) {
        try {
            $msgs = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($msgs.Count -gt 0) {
                return $msgs | Get-Random
            }
        }
        catch {}
    }

    # Fallback
    return [PSCustomObject]@{
        glyph = "[+]"
        title = "Time to Show Up"
        body  = "Every great outcome starts with showing up. Let's make this session count."
    }
}

# =============================================================================
# Event: Select Folder button
# =============================================================================
$selectFolderBtn.Add_Click({
        $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
        $dialog.Description = "Select the folder you want to open tomorrow"
        $dialog.ShowNewFolderButton = $false
        if ($dialog.ShowDialog() -eq "OK") {
            Set-SelectedPath $dialog.SelectedPath
            $lastFolderBanner.Visibility = "Collapsed"
        }
    })

# =============================================================================
# TASK-002: Drag-and-Drop (B-09)
# =============================================================================
$dropZone.Add_PreviewDragOver({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
        }
        else {
            $e.Effects = [System.Windows.DragDropEffects]::None
        }
        $e.Handled = $true
    })

$dropZone.Add_Drop({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            if ($dropped.Count -gt 0) {
                $path = $dropped[0]
                if (Test-Path $path -PathType Container) {
                    Set-SelectedPath $path
                    $lastFolderBanner.Visibility = "Collapsed"
                }
                else {
                    [System.Windows.MessageBox]::Show(
                        "Please drop a folder, not a file.",
                        "Not a Folder", "OK", "Warning")
                }
            }
        }
    })

# =============================================================================
# TASK-003: Schedule For Today radio (B-03) - show only before 14:00
# =============================================================================
if ((Get-Date).Hour -lt 14) {
    $todayRadio.Visibility = "Visible"
}

# =============================================================================
# Schedule button click
# =============================================================================
$scheduleBtn.Add_Click({
        if ($script:selectedPath) {
            Do-Schedule -FolderPath $script:selectedPath
        }
    })

# =============================================================================
# TASK-NEW-01: Undo button (B-04)
# =============================================================================
$undoBtn.Add_Click({
        if ($script:lastTaskId) {
            Stop-UndoTimer
            Remove-MotivationTask -TaskId $script:lastTaskId
            $script:lastTaskId = $null
            Refresh-TaskList
            $scheduleBtn.IsEnabled = ($script:selectedPath -ne "")
        }
    })

# =============================================================================
# B-01: Last folder banner
# =============================================================================
$lastFolder = Get-LastFolder
if ($lastFolder -and (Test-Path $lastFolder -PathType Container)) {
    $lastFolderPath.Text = $lastFolder
    $lastFolderBanner.Visibility = "Visible"
}

$lastFolderYesBtn.Add_Click({
        $lf = Get-LastFolder
        if ($lf -and (Test-Path $lf -PathType Container)) {
            Set-SelectedPath $lf
            $lastFolderBanner.Visibility = "Collapsed"
            Do-Schedule -FolderPath $lf
        }
    })

$lastFolderDismiss.Add_Click({
        $lastFolderBanner.Visibility = "Collapsed"
    })

# =============================================================================
# B-02: Recent folders - Schedule Again buttons
# =============================================================================
$recentFoldersList.Add_PreviewMouseLeftButtonUp({
        param($s, $e)
        $btn = [System.Windows.Media.VisualTreeHelper]::HitTest($s, $e.GetPosition($s))
        if ($btn -and $btn.VisualHit) {
            $container = $btn.VisualHit
            while ($container -and $container -isnot [System.Windows.Controls.Button]) {
                $container = [System.Windows.Media.VisualTreeHelper]::GetParent($container)
            }
            if ($container -and $container.Tag) {
                $fp = $container.Tag
                if (Test-Path $fp -PathType Container) {
                    Set-SelectedPath $fp
                    Do-Schedule -FolderPath $fp
                }
                else {
                    [System.Windows.MessageBox]::Show(
                        "That folder no longer exists: $fp",
                        "Folder Not Found", "OK", "Warning")
                }
            }
        }
    })

# =============================================================================
# TASK-009: Task deletion - × buttons in task list
# =============================================================================
$taskList.Add_PreviewMouseLeftButtonUp({
        param($s, $e)
        $container = $e.OriginalSource
        while ($container -and $container -isnot [System.Windows.Controls.Button]) {
            $container = $container.Parent
            if (-not $container) { break }
        }
        if ($container -and $container.Tag) {
            $tid = $container.Tag
            $confirm = [System.Windows.MessageBox]::Show(
                "Remove this scheduled task? This cannot be undone.",
                "Confirm Delete", "YesNo", "Warning")
            if ($confirm -eq "Yes") {
                Remove-MotivationTask -TaskId $tid
                Refresh-TaskList
            }
        }
    })

# =============================================================================
# TASK-NEW-03: History toggle (B-18)
# =============================================================================
$historyToggleBtn.Add_Click({
        if ($historyPanel.Visibility -eq "Visible") {
            $historyPanel.Visibility = "Collapsed"
            $historyToggleBtn.Content = "📋  View History"
        }
        else {
            Refresh-History
            $historyPanel.Visibility = "Visible"
            $historyToggleBtn.Content = "📋  Hide History"
        }
    })

$clearHistoryBtn.Add_Click({
        $confirm = [System.Windows.MessageBox]::Show(
            "Clear all history entries? This cannot be undone.",
            "Clear History", "YesNo", "Question")
        if ($confirm -eq "Yes") {
            Clear-OutcomeLog
            Refresh-History
        }
    })

# =============================================================================
# B-07: First-run welcome overlay - show on first launch
# =============================================================================
if (Get-IsFirstRun) {
    $window.Add_ContentRendered({
            $overlay = [System.Windows.Window]::new()
            $overlay.Owner = $window
            $overlay.WindowStyle = "None"
            $overlay.AllowsTransparency = $true
            $overlay.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.Color]::FromArgb(230, 13, 17, 23))
            $overlay.Width = $window.ActualWidth
            $overlay.Height = $window.ActualHeight
            $overlay.WindowStartupLocation = "CenterOwner"
            $overlay.Topmost = $true

            $panel = [System.Windows.Controls.StackPanel]::new()
            $panel.VerticalAlignment = "Center"
            $panel.HorizontalAlignment = "Center"
            $panel.Margin = [System.Windows.Thickness]::new(40)

            $addText = {
                param($text, $size, $color, $margin)
                $tb = [System.Windows.Controls.TextBlock]::new()
                $tb.Text = $text
                $tb.FontSize = $size
                $tb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($color)
                $tb.TextWrapping = "Wrap"
                $tb.TextAlignment = "Center"
                $tb.Margin = [System.Windows.Thickness]::new(0, $margin, 0, 0)
                $panel.Children.Add($tb) | Out-Null
            }

            & $addText "👋  Welcome to" 16 "#8888A8" 0
            & $addText "Daily Motivation Brain Helper" 22 "#E8E8F4" 4
            & $addText "" 6 "#00BCD4" 20
            & $addText "📁  Pick your working folder" 14 "#C8C8E8" 0
            & $addText "⏰  Schedule it - takes 2 clicks" 14 "#C8C8E8" 6
            & $addText "🚀  At 2 PM, a popup opens it for you" 14 "#C8C8E8" 6
            & $addText "" 6 "#00BCD4" 14
            & $addText "That's it. No settings. No code." 13 "#6666A0" 0

            $gotItBtn = [System.Windows.Controls.Button]::new()
            $gotItBtn.Content = "Got it - Let's Go!"
            $gotItBtn.FontSize = 14
            $gotItBtn.FontWeight = "Bold"
            $gotItBtn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0D1117")
            $gotItBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00BCD4")
            $gotItBtn.Padding = [System.Windows.Thickness]::new(32, 12, 32, 12)
            $gotItBtn.Margin = [System.Windows.Thickness]::new(0, 28, 0, 0)
            $gotItBtn.Cursor = [System.Windows.Input.Cursors]::Hand
            $gotItBtn.Add_Click({ $overlay.Close(); Set-FirstRunComplete })
            $panel.Children.Add($gotItBtn) | Out-Null

            $overlay.Content = $panel
            $overlay.ShowDialog() | Out-Null
        })
}

# =============================================================================
# Initial data load
# =============================================================================
Refresh-TaskList
Refresh-RecentFolders

# =============================================================================
# Show window
# =============================================================================
$window.ShowDialog() | Out-Null
