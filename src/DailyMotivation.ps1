# =============================================================================
# DailyMotivation.ps1 -- Daily Motivation Brain Helper
# Motivational popup fired by Windows Task Scheduler at scheduled time.
#
# TASK-005: Snooze Engine -- duration-parameterised re-trigger (B-10), Dismiss for Today (B-11)
# TASK-006: Named mutex -- one popup at a time (SSOT-006)
# TASK-007: Path validation + Moved Folder Re-Pick Prompt (B-05)
# TASK-004: Reads folder_name for subtitle (B-12)
#
# Launch via LaunchMotivation.bat (which passes -STA and -ExecutionPolicy Bypass)
# Config:    %APPDATA%\DailyMotivationBrainHelper\popup_config.json
# Debug log: %TEMP%\DailyMotivation_debug.log
# NOTE: ASCII-only -- no smart quotes or em dashes (PowerShell 5.1 / Windows-1252 safety)
# =============================================================================

#Requires -Version 5.1

# --- Step 0: Debug log ---
$debugLog     = Join-Path $env:TEMP "DailyMotivation_debug.log"
$errorLogPath = Join-Path $env:TEMP "DailyMotivation_error.log"

function Write-DLog {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Add-Content -Path $debugLog -Value $line -ErrorAction SilentlyContinue
}

Write-DLog "====== SCRIPT STARTED ======"
Write-DLog "User=$env:USERNAME | PID=$PID | PSVersion=$($PSVersionTable.PSVersion)"

# --- Step 1: Load WPF + WinForms ---
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
    Write-DLog "Assemblies loaded OK"
} catch {
    Write-DLog "FATAL: Assembly load failed - $_" "ERROR"
    exit 1
}

# =============================================================================
# TASK-006: Named mutex -- enforce SSOT-006 (one popup at a time)
# =============================================================================
$mutexName  = "Global\DailyMotivationBrainHelperPopup"
$mutexOwned = $false
$mutex      = $null
try {
    $mutex      = [System.Threading.Mutex]::new($false, $mutexName)
    $mutexOwned = $mutex.WaitOne(0)
    if (-not $mutexOwned) {
        Write-DLog "Mutex already held -- another popup is running. Exiting." "WARN"
        exit 0
    }
    Write-DLog "Mutex acquired"
} catch [System.Threading.AbandonedMutexException] {
    $mutexOwned = $true
    Write-DLog "Acquired abandoned mutex" "WARN"
} catch {
    Write-DLog "Mutex error (non-fatal): $_" "WARN"
}

trap {
    Write-DLog "UNCAUGHT EXCEPTION: $_" "ERROR"
    Add-Content -Path $errorLogPath -Value "[$(Get-Date -Format 'o')] ERROR: $_" -ErrorAction SilentlyContinue
    if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
    break
}

# --- Step 2: Paths ---
$appDataDir = Join-Path $env:APPDATA "DailyMotivationBrainHelper"
$configPath = Join-Path $appDataDir "popup_config.json"
$logPath    = Join-Path $appDataDir "popup_log.txt"

Write-DLog "Config path: $configPath"

# --- Step 3: Load config ---
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
        Write-DLog "Config loaded. title='$($config.title)' folder='$($config.folder_name)'"
    } catch {
        Write-DLog "Config parse failed - using defaults" "WARN"
    }
} else {
    Write-DLog "Config file not found - using defaults" "WARN"
}

# =============================================================================
# TASK-007 / B-05: Path validation
# =============================================================================
$script:pathMissing = $false
if ($config.explorer_path -and $config.explorer_path -ne "") {
    if (-not (Test-Path $config.explorer_path -PathType Container)) {
        $script:pathMissing = $true
        Write-DLog "Path missing: '$($config.explorer_path)'" "WARN"
    }
}

# --- Step 4: XAML ---
[xml]$xaml = @'
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

# --- Step 5: Build window ---
Write-DLog "Parsing XAML..."
try {
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-DLog "FATAL: XAML build failed - $_" "ERROR"; exit 1
}
if ($null -eq $window) { Write-DLog "FATAL: XamlReader returned null" "ERROR"; exit 1 }
Write-DLog "Window built OK"

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

# --- Populate UI ---
if ($script:pathMissing) {
    $normalPanel.Visibility      = "Collapsed"
    $pathMissingPanel.Visibility = "Visible"
    $missingPathLabel.Text       = "Was looking for: $($config.explorer_path)"
} else {
    $glyphText.Text = $config.glyph
    $titleText.Text = $config.title
    $bodyText.Text  = $config.body
    if ($config.folder_name -and $config.folder_name -ne "") {
        $folderNameText.Text       = "Opening: $($config.folder_name)"
        $folderNameText.Visibility = "Visible"
    }
}

# --- State ---
$script:openExplorer    = $true
$script:remaining       = 20
$script:snoozeMinutes   = 5
$script:firstTick       = $true
$script:snoozeCount     = 0
$script:newExplorerPath = ""

# --- Fade-in ---
$window.Add_Loaded({
    try {
        $anim = [System.Windows.Media.Animation.DoubleAnimation]::new(
            0, 1, [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(300)))
        $window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
    } catch { Write-DLog "Fade-in failed: $_" "WARN" }
})

# --- Countdown (normal mode only) ---
if (-not $script:pathMissing) {
    $timer          = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [System.TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        try {
            if ($script:firstTick) { Write-DLog "Countdown running"; $script:firstTick = $false }
            $script:remaining--
            $countdownText.Text = $script:remaining
            if ($script:remaining -le 0) { $timer.Stop(); $script:openExplorer = $true; $window.Close() }
        } catch { Write-DLog "Timer error: $_" "ERROR"; $timer.Stop(); $window.Close() }
    })
    $timer.Start()
    Write-DLog "Countdown timer started"
}

# --- B-10: Snooze duration selection ---
$snoozeDropBtn.Add_Click({
    $snoozeDropBtn.ContextMenu.IsOpen = $true
})

function Set-SnoozeDuration {
    param([int]$Minutes)
    $script:snoozeMinutes = $Minutes
    $label = if ($Minutes -lt 60) { "${Minutes}m" } else { "1h" }
    $snoozeBtn.Content = "Snooze $label"
    Write-DLog "Snooze duration: $Minutes min"
}
$snooze5.Add_Click({  Set-SnoozeDuration 5  })
$snooze15.Add_Click({ Set-SnoozeDuration 15 })
$snooze30.Add_Click({ Set-SnoozeDuration 30 })
$snooze60.Add_Click({ Set-SnoozeDuration 60 })

# --- Snooze click ---
$snoozeBtn.Add_Click({
    try {
        Write-DLog "Snooze clicked ($($script:snoozeMinutes) min)"
        if (-not $script:pathMissing) { $timer.Stop() }
        $script:snoozeCount++
        $script:openExplorer = $false
        # Register re-trigger task
        $modulePath = Join-Path $PSScriptRoot "Modules\TaskScheduler.psm1"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
            $snoozeTime = (Get-Date).AddMinutes($script:snoozeMinutes)
            New-MotivationTask -FolderPath $config.explorer_path -TriggerTime $snoozeTime -Force | Out-Null
            Write-DLog "Snooze re-trigger task created for $snoozeTime"
        }
        $window.Close()
    } catch { Write-DLog "Snooze error: $_" "ERROR"; $window.Close() }
})

# --- B-11: Dismiss for Today ---
$dismissBtn.Add_Click({
    try {
        Write-DLog "Dismiss for Today clicked"
        if (-not $script:pathMissing) { $timer.Stop() }
        $script:openExplorer = $false
        $modulePath = Join-Path $PSScriptRoot "Modules\TaskScheduler.psm1"
        if (Test-Path $modulePath -and $config.explorer_path) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
            $pending = Get-MotivationTasks | Where-Object {
                $_.folder_path -eq $config.explorer_path -and $_.status -eq "PENDING"
            }
            foreach ($t in $pending) {
                Remove-MotivationTask -TaskId $t.task_id
                Write-DLog "Removed pending task $($t.task_id)"
            }
        }
        $window.Close()
    } catch { Write-DLog "Dismiss error: $_" "ERROR"; $window.Close() }
})

# --- Open Folder ---
$letsGoBtn.Add_Click({
    try {
        Write-DLog "Open Folder clicked"
        if (-not $script:pathMissing) { $timer.Stop() }
        $script:openExplorer = $true
        $window.Close()
    } catch { Write-DLog "LetsGo error: $_" "ERROR" }
})

# --- B-05: Path missing handlers ---
$pathDismissBtn.Add_Click({
    Write-DLog "Path-missing Dismiss clicked"
    $script:openExplorer = $false
    $window.Close()
})

$rePickBtn.Add_Click({
    Write-DLog "Re-pick clicked"
    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = "Choose the new location for this folder"
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -eq "OK") {
        $newPath = $dialog.SelectedPath
        Write-DLog "Re-pick: $newPath"
        try {
            $c = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $c.explorer_path = $newPath
            $c.folder_name   = Split-Path -Leaf $newPath
            $c | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
        } catch { Write-DLog "Config update failed: $_" "WARN" }
        $script:newExplorerPath = $newPath
        $script:openExplorer    = $true
        $window.Close()
    }
})

# --- Show ---
Write-DLog "Calling ShowDialog()"
try {
    $window.ShowDialog() | Out-Null
    Write-DLog "ShowDialog returned. openExplorer=$($script:openExplorer)"
} catch {
    Write-DLog "ShowDialog threw: $_" "ERROR"; exit 1
} finally {
    if ($mutexOwned -and $mutex) {
        try { $mutex.ReleaseMutex(); Write-DLog "Mutex released" }
        catch { Write-DLog "Mutex release error: $_" "WARN" }
    }
}

# --- Post-close: open Explorer ---
$effectivePath = if ($script:newExplorerPath) { $script:newExplorerPath } else { $config.explorer_path }
if ($script:openExplorer -and $effectivePath -and $effectivePath -ne "") {
    Write-DLog "Launching Explorer: $effectivePath"
    try { Start-Process "explorer.exe" -ArgumentList $effectivePath -ErrorAction Stop; Write-DLog "Explorer launched" }
    catch { Write-DLog "Explorer launch failed: $_" "ERROR" }
}

# --- Write structured log ---
$outcome = if     ($script:pathMissing -and -not $script:openExplorer) { "PathMissing" }
           elseif ($script:openExplorer)                               { "Opened"      }
           elseif ($script:snoozeCount -gt 0)                          { "Snoozed"     }
           else                                                         { "Dismissed"   }

$logLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] | $($config.task_id) | $($config.folder_name) | $effectivePath | $outcome | $($script:snoozeCount)"
try { Add-Content -Path $logPath -Value $logLine -Encoding UTF8 -ErrorAction Stop }
catch { Write-DLog "Log write failed: $_" "WARN" }

Write-DLog "====== SCRIPT COMPLETE ======"
