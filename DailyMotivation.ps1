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
    [ValidateSet("main", "/popup", "/setfolder")]
    [string]$Mode       = "main",
    [ValidateScript({
        if ($_ -eq "") { $true }
        elseif ($_ -match '^[*?<>|]') { throw "Path contains invalid characters" }
        else { $true }
    })]
    [string]$FolderPath = "",
    [switch]$NoRun      # When set, defines all functions but skips the entry point.
                        # Use when dot-sourcing in Pester tests: . .\DailyMotivation.ps1 -NoRun
)

# ============================================================
# SECTION 2: Platform detection
# ============================================================
# Cross-platform temp directory resolution
$script:TempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }

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

$script:ConfigCache = $null
$script:ConfigCacheMTime = $null

$script:ConfigDefaults = [PSCustomObject]@{
    default_trigger_hour   = 14
    task_warning_threshold = 5
}

# Assembly loading (deferred - only when NOT dot-sourcing with -NoRun)
$script:AssembliesLoaded = $false

function Initialize-WindowsAssemblies {
    # WPF and WinForms loads are split so WinForms can be used as a fallback
    # error-display mechanism when WPF fails, instead of a silent hard exit.
    if ($script:AssembliesLoaded) { return }
    $wpfErr = $null
    $script:WpfLoaded   = $false
    $script:FormsLoaded = $false

    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
        $script:WpfLoaded = $true
    }
    catch { $wpfErr = $_ }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        $script:FormsLoaded = $true
    }
    catch {}

    if (-not $script:WpfLoaded) {
        $errMsg = "Could not load WPF UI components (.NET Framework 4.x required). The application cannot display its interface.`n`nDetails: $wpfErr"
        if ($script:FormsLoaded) {
            [void][System.Windows.Forms.MessageBox]::Show($errMsg, "Daily Motivation Brain Helper",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        else {
            [Console]::Error.WriteLine($errMsg)
        }
        exit 1
    }

    $script:AssembliesLoaded = $true
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
        # Return Unix-style cross-platform path for testing
        # Simulates Linux XDG Base Directory spec even when running on Windows
        if ($env:HOME -and $env:HOME -notlike "C:\*") {
            return Join-Path $env:HOME ".local/share/DailyMotivationBrainHelper"
        }
        # Use /tmp as base to avoid Windows-specific paths (C:\, AppData, etc.)
        return "/tmp/.local/share/DailyMotivationBrainHelper"
    }

    [void] OpenFolder([string]$path) {
    }

    [hashtable] ScheduleTask([hashtable]$params) {
        return @{ Success = $true; TaskId = "headless-mock-" + [guid]::NewGuid().ToString("N").Substring(0, 16) }
    }

    [void] UnscheduleTask([string]$taskId) {
    }

    [void] RegisterContextMenu([string]$exePath) {
    }

    [string] ShowDialog([string]$message, [string]$title, [string]$buttons, [string]$icon) {
        return "OK"
    }
}

# ============================================================
# SECTION 3: Configuration functions
# ============================================================

function Initialize-AppData {
    [CmdletBinding()]
    param()
    <#
    Creates platform-specific app data directory and default config files.
    Uses platform adapter if available (for cross-platform testing).
    Falls back to %APPDATA% on Windows, $HOME/.local/share on Linux.
    Re-resolves all paths from current environment so test redirects work.
    #>
    # Use platform adapter if injected (for testing), otherwise use environment
    if ($script:Platform) {
        $script:AppDataDir = $script:Platform.GetAppDataPath()
    }
    elseif ($env:APPDATA) {
        # Guard: if APPDATA points to a file (test blocker pattern), go straight to TempDir fallback.
        if ((Test-Path $env:APPDATA -PathType Leaf)) {
            $script:AppDataDir = Join-Path $script:TempDir "DailyMotivationBrainHelper"
        } else {
            $script:AppDataDir = Join-Path $env:APPDATA "DailyMotivationBrainHelper"
        }
    }
    else {
        $baseDir = if ($env:HOME) { $env:HOME } else { "~" }
        $script:AppDataDir = Join-Path $baseDir ".local/share/DailyMotivationBrainHelper"
    }
    $script:ConfigPath   = Join-Path $script:AppDataDir "config.json"
    $script:PopupCfgPath = Join-Path $script:AppDataDir "popup_config.json"
    $script:TasksPath    = Join-Path $script:AppDataDir "tasks.json"
    $script:LogPath      = Join-Path $script:AppDataDir "popup_log.txt"

    if (-not (Test-Path $script:AppDataDir)) {
        try {
            [void](New-Item -ItemType Directory -Path $script:AppDataDir -Force -ErrorAction Stop)
        }
        catch {
            $fallback = Join-Path $script:TempDir "DailyMotivationBrainHelper"
            Write-Warning "Initialize-AppData: Could not create '$script:AppDataDir'. Falling back to '$fallback'."
            try {

                [void](New-Item -ItemType Directory -Path $fallback -Force -ErrorAction Stop)
                $script:AppDataDir   = $fallback
                $script:ConfigPath   = Join-Path $script:AppDataDir "config.json"
                $script:PopupCfgPath = Join-Path $script:AppDataDir "popup_config.json"
                $script:TasksPath    = Join-Path $script:AppDataDir "tasks.json"
                $script:LogPath      = Join-Path $script:AppDataDir "popup_log.txt"
            }
            catch {
                Write-Error "Initialize-AppData: Cannot create fallback directory '$fallback': $($_.Exception.Message)"
                throw
            }
        }
    }

    # Set restrictive explicit ACL on config directory (Windows only).
    # This ensures the current user owns the directory exclusively and
    # satisfies AG10-011 (file permissions must have at least one explicit rule).
    if ($IsWindows -and (Test-Path $script:AppDataDir)) {
        try {
            $acl = Get-Acl -Path $script:AppDataDir
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $currentUser,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $acl.AddAccessRule($rule)
            Set-Acl -Path $script:AppDataDir -AclObject $acl -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Initialize-AppData: Could not set explicit ACL on '$script:AppDataDir': $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path $script:ConfigPath)) {
        [ordered]@{
            default_trigger_hour   = 14
            task_warning_threshold = 5
        } | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
    }

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

    if (-not (Test-Path $script:TasksPath)) {
        Set-Content -Path $script:TasksPath -Value "[]" -Encoding UTF8 -NoNewline
    }
}

function Get-Config {
    [CmdletBinding()]
    param()
    try {
        $mtime = $null
        if (Test-Path $script:ConfigPath) {
            $mtime = (Get-Item $script:ConfigPath -ErrorAction SilentlyContinue).LastWriteTime
        }

        if ($null -ne $script:ConfigCache -and $null -ne $mtime -and $mtime -eq $script:ConfigCacheMTime) {
            return $script:ConfigCache
        }

        if (Test-Path $script:ConfigPath) {
            $fileSize = (Get-Item $script:ConfigPath).Length
            if ($fileSize -gt 50KB) {
                # File exceeds size limit  -  return schema-only defaults as hashtable.
                # Hashtable allows $cfg.unknownKey to return $null (not throw under StrictMode).
                return @{ default_trigger_hour = 14; task_warning_threshold = 5 }
            }
        }

        # AG18-005: strip Unicode BOM (U+FEFF) that some editors prepend to UTF-8 files
        $raw = Get-Content -Path "$script:ConfigPath" -Raw -Encoding UTF8
        $raw = $raw.TrimStart([char]0xFEFF)
        $cfg = $raw | ConvertFrom-Json

        # Ensure both schema fields exist on the PSCustomObject before accessing them.
        # ConvertFrom-Json omits keys that were absent in the file; accessing missing properties
        # throws PropertyNotFoundException under StrictMode (e.g., inside Pester test runs).
        # Add-Member is a no-op here for the happy path (property already exists).
        if ($cfg.PSObject.Properties.Match('default_trigger_hour').Count -eq 0) {
            $cfg | Add-Member -NotePropertyName 'default_trigger_hour' -NotePropertyValue $null
        }
        if ($cfg.PSObject.Properties.Match('task_warning_threshold').Count -eq 0) {
            $cfg | Add-Member -NotePropertyName 'task_warning_threshold' -NotePropertyValue $null
        }

        # Validate config properties to prevent downstream errors
        if ($null -eq $cfg.default_trigger_hour -or
            -not ($cfg.default_trigger_hour -is [int] -or $cfg.default_trigger_hour -is [long] -or $cfg.default_trigger_hour -is [double]) -or
            [int]$cfg.default_trigger_hour -lt 0 -or [int]$cfg.default_trigger_hour -gt 23) {
            $cfg.default_trigger_hour = 14
        }
        if ($null -eq $cfg.task_warning_threshold -or
            -not ($cfg.task_warning_threshold -is [int] -or $cfg.task_warning_threshold -is [long] -or $cfg.task_warning_threshold -is [double]) -or
            [int]$cfg.task_warning_threshold -lt 0 -or
            [int]$cfg.task_warning_threshold -gt 100) {  # AG18-025: upper bound
            $cfg.task_warning_threshold = 5
        }

        $script:ConfigCache = $cfg
        $script:ConfigCacheMTime = $mtime

        return $cfg
    }
    catch {
        $script:ConfigCache = $null
        $script:ConfigCacheMTime = $null
        return @{ default_trigger_hour = 14; task_warning_threshold = 5 }
    }
}

function Save-Config {
    [CmdletBinding()]
    param(
        [PSCustomObject]$Config,
        [Nullable[int]]$DefaultTriggerHour,
        [Nullable[int]]$TaskWarningThreshold
    )
    # If individual params provided, build a config object from current values
    if ($PSBoundParameters.ContainsKey('DefaultTriggerHour') -or $PSBoundParameters.ContainsKey('TaskWarningThreshold')) {
        $existing = Get-Config
        if ($PSBoundParameters.ContainsKey('DefaultTriggerHour')) {
            $existing.default_trigger_hour = $DefaultTriggerHour
        }
        if ($PSBoundParameters.ContainsKey('TaskWarningThreshold')) {
            $existing.task_warning_threshold = $TaskWarningThreshold
        }
        $Config = $existing
    }
    $tempPath  = $script:ConfigPath + ".tmp"
    # AG18-012: mutex prevents concurrent writes from two scheduling processes
    $cfgMutex     = $null
    $cfgAcquired  = $false
    try {
        $cfgMutex    = [System.Threading.Mutex]::new($false, "Global\DailyMotivationConfigLock")
        $cfgAcquired = $cfgMutex.WaitOne(5000)
    }
    catch {}
    try {
        $Config | ConvertTo-Json | Set-Content -Path $tempPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempPath -Destination $script:ConfigPath -Force -ErrorAction Stop

        $script:ConfigCache = $null
        $script:ConfigCacheMTime = $null
    }
    catch {
        if (Test-Path $tempPath) { Remove-Item $tempPath -ErrorAction SilentlyContinue }
        throw
    }
    finally {
        if ($cfgAcquired -and $cfgMutex) { try { $cfgMutex.ReleaseMutex() } catch {} }
        if ($cfgMutex) { $cfgMutex.Dispose() }
    }
}

function Get-PopupConfig {
    [CmdletBinding()]
    param()
    if (-not (Test-Path -Path "$script:PopupCfgPath" -PathType Leaf)) {
        return [PSCustomObject]@{
            glyph         = "[+]"
            title         = ""
            body          = ""
            explorer_path = ""
            folder_name   = ""
            task_id       = ""
        }
    }

    try {
        # Validate file size before parsing
        if (Test-Path $script:PopupCfgPath) {
            $fileSize = (Get-Item $script:PopupCfgPath).Length
            if ($fileSize -gt 50KB) {
                return [PSCustomObject]@{
                    glyph = "[+]"; title = ""; body = ""
                    explorer_path = ""; folder_name = ""; task_id = ""
                }
            }
        }
        return Get-Content -Path "$script:PopupCfgPath" -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return [PSCustomObject]@{
            glyph         = "[+]"
            title         = ""
            body          = ""
            explorer_path = ""
            folder_name   = ""
            task_id       = ""
        }
    }
}

function Set-PopupConfig {
    [CmdletBinding()]
    param(
        [string]$Glyph,
        [string]$Title,
        [string]$Body,
        [Alias('FolderPath')][string]$ExplorerPath,
        [string]$FolderName,
        [string]$TaskId
    )
    $tempPath    = $script:PopupCfgPath + ".tmp"
    $cfgMutex    = $null
    $cfgAcquired = $false
    try {
        $cfgMutex    = [System.Threading.Mutex]::new($false, "Global\DailyMotivationPopupConfigLock")
        $cfgAcquired = $cfgMutex.WaitOne(2000)
        $resolvedFolderName = if ($FolderName) {
            $FolderName
        } elseif ($ExplorerPath) {
            $leaf = Split-Path -Leaf $ExplorerPath
            if ($leaf) { $leaf } else { "Unknown Folder" }
        } else { "Unknown Folder" }
        [ordered]@{
            glyph         = $Glyph
            title         = $Title
            body          = $Body
            explorer_path = $ExplorerPath
            folder_path   = $ExplorerPath
            folder_name   = $resolvedFolderName
            task_id       = $TaskId
            message_glyph = $Glyph
            message_title = $Title
            message_body  = $Body
        } | ConvertTo-Json | Set-Content -Path $tempPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempPath -Destination $script:PopupCfgPath -Force -ErrorAction Stop
    }
    catch {
        if (Test-Path $tempPath) { Remove-Item $tempPath -ErrorAction SilentlyContinue }
        throw
    }
    finally {
        if ($null -ne $cfgMutex) {
            try { if ($cfgAcquired) { $cfgMutex.ReleaseMutex() } } catch {}
            $cfgMutex.Dispose()
        }
    }
}

function Write-OutcomeLog {
    [CmdletBinding()]
    param(
        [string]$TaskId,
        [string]$FolderName,
        [string]$FolderPath,
        [string]$Outcome,
        [int]$SnoozeCount = 0
    )
    # AG15-013: millisecond precision so rapid snooze cycles are distinguishable
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

    # Hash folder path instead of storing plaintext
    $pathHash = if ($FolderPath) {
        $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($FolderPath))
        ($hashBytes | ForEach-Object { $_.ToString("X2") }) -join ''
    } else {
        "NO_PATH"
    }

    # AG15-017: escape pipe characters so folder names don't corrupt the delimited format
    $safeFolderName = $FolderName -replace '\|', '[PIPE]'

    # Store only hash in log, not full path
    $entry = "[$ts] | $TaskId | $safeFolderName | HASH:$pathHash | $Outcome | $SnoozeCount"

    # AG15-006: acquire mutex before appending to prevent interleaved entries from concurrent runs
    $logMutex     = $null
    $logAcquired  = $false
    try {
        $logMutex    = [System.Threading.Mutex]::new($false, "Global\DailyMotivationLogLock")
        $logAcquired = $logMutex.WaitOne(2000)
    }
    catch {}

    try {
        # AG15-007: create log directory if missing (Initialize-AppData may have failed)
        $logDir = Split-Path $script:LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Add-Content -Path "$script:LogPath" -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    finally {
        if ($logAcquired -and $logMutex) { try { $logMutex.ReleaseMutex() } catch {} }
        if ($logMutex) { $logMutex.Dispose() }
    }

    # Implement log rotation to prevent indefinite accumulation
    if (Test-Path $script:LogPath) {
        try {
            $logFile = Get-Item $script:LogPath
            if ($logFile.Length -gt 1MB) {
                # Rotate log if over 1MB
                $archiveName = "$($script:LogPath).archive_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item -Path $script:LogPath -Destination $archiveName -Force -ErrorAction Stop
                Clear-Content -Path $script:LogPath -ErrorAction Stop

                # Delete archives older than 30 days
                Get-ChildItem -Path (Split-Path $script:LogPath -Parent) -Filter "popup_log.txt.archive_*" -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
                    ForEach-Object {
                        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                    }
            }
        }
        catch {}
    }
}

function Get-SafeErrorMessage {
    # Sanitize error messages to prevent path exposure
    # Also strip raw stack trace lines so users never see internal script paths
    param([Parameter(Mandatory)][string]$ErrorMessage)

    # Remove file paths (Windows and UNC)
    $safe = $ErrorMessage -replace '[A-Z]:\\[^\s"]*', '[PATH]'
    $safe = $safe -replace '\\\\[^\s"]*', '[UNC_PATH]'

    # Remove sensitive keywords with context
    $safe = $safe -replace '(password|secret|token|key|credential)[^\s]*', '[REDACTED]'

    # Remove $env: variable references that might contain paths
    $safe = $safe -replace '\$env:[A-Z_]+\\[^\s"]*', '[ENV_PATH]'

    # Strip PowerShell/dotnet stack trace lines (e.g. "at DailyMotivation.ps1:line 123")
    $safe = $safe -replace '(?m)\r?\n\s+at\s+[^\r\n]+', ''

    return $safe
}

function Show-ErrorDialog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = "Daily Motivation Brain Helper"
    )

    # Sanitize error message (strips paths, credentials, stack traces)
    $safeMessage = Get-SafeErrorMessage -ErrorMessage $Message

    # Try WPF custom scrollable dialog first
    # Check if WpfLoaded variable exists and is true
    if ((Get-Variable -Name 'WpfLoaded' -Scope Script -ErrorAction SilentlyContinue) -and $script:WpfLoaded) {
        try {
            $errXamlStr = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" WindowStyle="ToolWindow" ResizeMode="NoResize" Width="480" SizeToContent="Height" MaxHeight="440" WindowStartupLocation="CenterScreen" Background="#0D1117" FontFamily="Segoe UI"><Border Padding="24,20"><StackPanel><ScrollViewer MaxHeight="280" VerticalScrollBarVisibility="Auto" Margin="0,0,0,16" Background="#111B22" Padding="10,8"><TextBlock x:Name="MsgText" TextWrapping="Wrap" FontSize="13" Foreground="#E8E8F4" LineHeight="22"/></ScrollViewer><Button x:Name="OkBtn" Content="OK" Width="80" HorizontalAlignment="Right" Background="#00BCD4" Foreground="#0D1117" FontWeight="Bold" Padding="0,8" Cursor="Hand" BorderThickness="0"/></StackPanel></Border></Window>'
            $errXml    = [xml]$errXamlStr
            $errReader = [System.Xml.XmlNodeReader]::new($errXml)
            $errWin    = [Windows.Markup.XamlReader]::Load($errReader)
            $errReader.Dispose()
            $errWin.Title = $Title
            $errWin.FindName("MsgText").Text = $safeMessage
            $errOkBtn = $errWin.FindName("OkBtn")
            $errOkBtn.Add_Click({ $errWin.Close() })
            $errWin.Add_KeyDown({
                param($ks, $ke)
                if ($ke.Key -eq [System.Windows.Input.Key]::Escape -or
                    $ke.Key -eq [System.Windows.Input.Key]::Return) {
                    $errWin.Close()
                }
            })
            [void]$errWin.ShowDialog()
            return
        }
        catch { <# fall through to MessageBox fallback #> }
    }

    # Fallback: plain MessageBox (WPF not available)
    try {

        [void][System.Windows.MessageBox]::Show($safeMessage, $Title, "OK", "Error")
    }
    catch {
        try {
            [void][System.Windows.Forms.MessageBox]::Show($safeMessage, $Title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        catch { [Console]::Error.WriteLine("ERROR [$Title]: $safeMessage") }
    }
}

function Show-InfoDialog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = "Daily Motivation Brain Helper"
    )
    try {

        [void][System.Windows.MessageBox]::Show($Message, $Title, "OK", "Information")
    }
    catch {
        try {
            [void][System.Windows.Forms.MessageBox]::Show($Message, $Title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        catch { [Console]::Out.WriteLine("INFO [$Title]: $Message") }
    }
}

# ============================================================
# SECTION 4: Task Scheduler functions
# ============================================================

function Get-TasksJson {
    # Valid task status values
    $script:ValidTaskStatuses = @('PENDING', 'DELETED', 'COMPLETED', 'FAILED')

    $path = $script:TasksPath
    if (-not (Test-Path $path)) { return @() }
    try {
        $result = Get-Content -Path "$path" -Raw -Encoding UTF8 | ConvertFrom-Json
        # Ensure consistent array handling for empty JSON arrays
        if ($null -eq $result) { return @() }

        # AG18-018: strip null elements that may survive a corrupt or partial load
        $tasks = @($result | Where-Object { $null -ne $_ })

        # Validate and normalize task status values
        foreach ($task in $tasks) {
            if ($task.PSObject.Properties['status']) {
                if ($task.status -notin $script:ValidTaskStatuses) {
                    $task.status = 'UNKNOWN'
                }
            }
        }

        # AG18-010: filter out tasks missing task_id (corrupt entries) and UNKNOWN status
        $tasks = @($tasks | Where-Object {
            -not [string]::IsNullOrEmpty($_.task_id) -and $_.status -ne 'UNKNOWN'
        })

        return $tasks
    }
    catch { return @() }
}

function Save-TasksJson {
    param([object[]]$Tasks)
    $path     = $script:TasksPath
    $tempPath = $path + ".tmp"
    # AG18-018: strip nulls before serialising so JSON never contains a null literal
    $Tasks = @($Tasks | Where-Object { $null -ne $_ })
    # AG18-012: mutex prevents concurrent writes from two scheduling processes
    $tasksMutex     = $null
    $tasksAcquired  = $false
    try {
        $tasksMutex    = [System.Threading.Mutex]::new($false, "Global\DailyMotivationTasksLock")
        $tasksAcquired = $tasksMutex.WaitOne(5000)
    }
    catch {}
    try {
        if ($Tasks.Count -eq 0) {
            Set-Content -Path $tempPath -Value '[]' -Encoding UTF8 -NoNewline -ErrorAction Stop
        }
        else {
            ConvertTo-Json -InputObject $Tasks -Depth 4 | Set-Content -Path $tempPath -Encoding UTF8 -ErrorAction Stop
        }
        Move-Item -Path $tempPath -Destination $path -Force -ErrorAction Stop
    }
    catch {
        if (Test-Path $tempPath) { Remove-Item $tempPath -ErrorAction SilentlyContinue }
        throw
    }
    finally {
        if ($tasksAcquired -and $tasksMutex) { try { $tasksMutex.ReleaseMutex() } catch {} }
        if ($tasksMutex) { $tasksMutex.Dispose() }
    }
}

function New-MotivationTask {
    <#
    .SYNOPSIS
    Creates a Windows Scheduled Task and records it in tasks.json.
    The task action calls this same exe with /popup argument (-STA baked in by build).
    #>
    param(
        [AllowEmptyString()][Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)][datetime]$TriggerTime,
        [switch]$Force
    )

    if ([string]::IsNullOrEmpty($FolderPath)) {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "FolderPath cannot be null or empty" }
    }

    # Validate folder path before storage in Task Scheduler/Registry
    if ($FolderPath -match '\.\.' -or $FolderPath -match '\.\.\\' -or $FolderPath -match '\.\./') {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid path: path traversal sequences (..) are not allowed" }
    }

    if ($FolderPath -match '[<>*?]') {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid path: contains invalid characters (<>*?)" }
    }

    # Validate path can be normalized
    try {
        [void][System.IO.Path]::GetFullPath($FolderPath)
    }
    catch {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid path format: $_" }
    }

    # Duplicate check - case-insensitive path, same date
    # Read tasks directly from JSON WITHOUT syncing first to avoid false positives
    # where Sync-TaskStatuses marks tasks as DELETED due to temporary lookup failures
    $normalizedInput = [System.IO.Path]::GetFullPath($FolderPath).ToLowerInvariant()
    if (-not $Force) {
        $existing = Get-MotivationTasks | Where-Object {
            # Check property exists first (guard against malformed/legacy task objects)
            if ($null -eq $_ -or -not $_.PSObject.Properties['folder_path']) { return $false }
            if (-not $_.folder_path) { return $false }
            if ([System.IO.Path]::GetFullPath($_.folder_path).ToLowerInvariant() -ne $normalizedInput) { return $false }
            if ($_.status -ne "PENDING") { return $false }
            $dateMatch = $false
            try { $dateMatch = ([datetime]$_.scheduled_time).Date -eq $TriggerTime.Date } catch {}
            return $dateMatch
        }
        if ($existing) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $true }
        }
    }

    # Compute sanitized description (SHA-256 hash of path)  -  used in both Platform and Windows paths.
    $descHashParts = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($FolderPath)) | ForEach-Object { $_.ToString("X2") }
    $safeDescription = "Daily Motivation Brain Helper - Task $(($descHashParts -join '').Substring(0, 16))"

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

        # Validate executable path BEFORE the retry loop so invalid ExePath
        # returns the proper validation error rather than "retry exhausted".
        # Use $null check (not falsy) so an intentionally empty "" stays empty and triggers the error below.
        $exeForTask = if ($null -ne $script:ExePath) { $script:ExePath } else { "DailyMotivation.exe" }
        if ([string]::IsNullOrEmpty($exeForTask)) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid executable path: executable path is empty" }
        }
        if ($exeForTask -notmatch '\.exe$') {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid executable path: must be a .exe file, got: $exeForTask" }
        }
        if (-not [System.IO.Path]::IsPathRooted($exeForTask)) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid executable path: must be absolute path, got: $exeForTask" }
        }

        # Validate trigger time BEFORE the retry loop so past/far-future times
        # return proper validation errors rather than "retry exhausted".
        if ($TriggerTime -le (Get-Date)) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid trigger time: must be in the future, got: $TriggerTime" }
        }
        if ($TriggerTime -gt (Get-Date).AddYears(4)) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid trigger time: cannot be more than 4 years in the future" }
        }

        # Generate task ID with collision retry and exponential backoff.
        # The Pester mock returns $null for a non-existent task name; on real Windows
        # Get-ScheduledTask throws CimJobException. In both cases $null/$exception = no collision.
        $maxRetries = 10
        $backoffMs = 50
        $taskId = $null
        $taskName = $null
        $collisionResolved = $false

        for ($attempts = 0; $attempts -lt $maxRetries; $attempts++) {
            $taskId = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
            $taskName = "DailyMotivation_$taskId"

            $existingTask = $null
            try {
                $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            }
            catch {
                # Any exception means task not found  -  no collision
                $existingTask = $null
            }

            if ($null -eq $existingTask) {
                $collisionResolved = $true
                break
            }

            # Collision  -  back off and retry
            Start-Sleep -Milliseconds $backoffMs
            $backoffMs = [Math]::Min($backoffMs * 2, 5000)
        }

        if (-not $collisionResolved) {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Could not generate unique task ID after $maxRetries attempts (collision retry exhausted)" }
        }

        try {
            $action = New-ScheduledTaskAction -Execute $exeForTask -Argument "/popup"
        }
        catch {
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $_.Exception.Message }
        }

        $trigger  = New-ScheduledTaskTrigger -Once -At $TriggerTime
        # EndBoundary is required by Task Scheduler XML schema when DeleteExpiredTaskAfter is set.
        # Without it, Register-ScheduledTask emits a non-terminating "(49,4):EndBoundary:" XML error
        # that ps2exe surfaces as a dialog. Set it to trigger time + execution limit + buffer.
        $executionTimeLimit = New-TimeSpan -Minutes 30
        $trigger.EndBoundary = $TriggerTime.Add($executionTimeLimit).AddMinutes(1).ToString('yyyy-MM-ddTHH:mm:ss')
        $settingsParams = @{
            StartWhenAvailable      = $true
            ExecutionTimeLimit      = $executionTimeLimit
            MultipleInstances       = 'IgnoreNew'
            DeleteExpiredTaskAfter  = New-TimeSpan -Seconds 30
        }
        $settings = New-ScheduledTaskSettingsSet @settingsParams

        # Network path detection
        $isUncPath     = $FolderPath -match '^\\\\[^\\]'
        $isMappedDrive = $false
        if ($FolderPath -and $FolderPath.Length -ge 2 -and $FolderPath[1] -eq ':') {
            try {
                $driveInfo     = [System.IO.DriveInfo]::new($FolderPath.Substring(0, 1))
                $isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
            }
            catch { $isMappedDrive = $false }
        }
        $isNetworkPath = $isUncPath -or $isMappedDrive

        # CRITICAL - Never use 'Highest' RunLevel for security
        $runLevel = 'Limited'

        # Use Interactive LogonType for per-user interactive desktop session
        $principalParams = @{
            UserId    = $env:USERNAME
            LogonType = 'Interactive'
            RunLevel  = $runLevel
        }
        $principal = New-ScheduledTaskPrincipal @principalParams

        try {
            $registerParams = @{
                TaskName    = $taskName
                Action      = $action
                Trigger     = $trigger
                Settings    = $settings
                Principal   = $principal
                Description = $safeDescription
                Force       = $true
            }
            Register-ScheduledTask @registerParams -ErrorAction Stop | Out-Null
        }
        catch {
            $errorMsg = $_.Exception.Message
            if ($errorMsg -match 'already exists') {
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Task name collision: $errorMsg" }
            }
            elseif ($errorMsg -match 'Access Denied|not have permission') {
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Access denied: $errorMsg" }
            }
            else {
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $errorMsg }
            }
        }
    }

    # Persist to tasks.json - atomic: rollback OS task if JSON save fails
    # AG18-024: K specifier emits UTC offset for Local/Utc but empty string for Unspecified.
    # Pre-compute a normalised trigger so callers using [datetime]::new() (Unspecified)
    # get the same local-offset behaviour as production Get-Date calls (Local).
    $triggerForStorage = if ($TriggerTime.Kind -eq [System.DateTimeKind]::Unspecified) {
        [DateTime]::SpecifyKind($TriggerTime, [System.DateTimeKind]::Local)
    } else { $TriggerTime }

    $tasks   = @(Get-TasksJson)
    $newTask = [PSCustomObject]@{
        task_id        = $taskId
        task_name      = $taskName
        folder_path    = $FolderPath
        folder_name    = if ($FolderPath) { $leaf = Split-Path -Leaf $FolderPath; if ($leaf) { $leaf } else { "Unknown Folder" } } else { "Unknown Folder" }
        scheduled_time = $triggerForStorage.ToString("yyyy-MM-ddTHH:mm:ssK")
        created_at     = (Get-Date -Format "o")
        status         = "PENDING"
        snooze_count   = 0
        description    = $safeDescription
    }
    $tasks = $tasks + $newTask
    try {
        Save-TasksJson $tasks
    }
    catch {
        # Rollback: unregister the OS task to keep Task Scheduler and tasks.json in sync
        if (-not $script:Platform) {
            try {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            }
            catch {
                # Log and report unregister failure - creates inconsistent state
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Failed to save task record AND failed to rollback: Task may remain in Task Scheduler. Error: $($_.Exception.Message)" }
            }
        }
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Failed to save task record: $($_.Exception.Message)" }
    }

    return @{ Success = $true; TaskId = $taskId; IsDuplicate = $false; IsNetworkPath = $isNetworkPath }
}

function Sync-TaskStatuses {
    # Explicit reconciliation: check Windows Task Scheduler and update task statuses
    # Call this function when you need up-to-date status from the OS
    # Skip reconciliation if platform adapter is active (tests/headless mode)
    if ($script:Platform) { return }

    $tasks = @(Get-TasksJson)
    $changed = $false

    # Direction 1: JSON → OS Scheduler  -  mark tasks DELETED if OS task is gone
    foreach ($t in $tasks) {
        if ($null -eq $t -or -not $t.PSObject.Properties) { continue }
        if ($t.status -eq "PENDING") {
            try {

                [void](Get-ScheduledTask -TaskName $t.task_name -ErrorAction Stop)
            }
            catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
                $t.status = "DELETED"   # task genuinely gone
                $changed = $true
            }
            catch [System.UnauthorizedAccessException] {
                Write-Warning "Sync-TaskStatuses: access denied reading '$($t.task_name)'"
            }
            catch {
                # If the error indicates the task is not found, mark it DELETED
                $errMsg = "$_"
                if ($errMsg -match 'cannot find' -or $errMsg -match 'not found' -or $errMsg -match 'No MSFT_ScheduledTask') {
                    $t.status = "DELETED"
                    $changed = $true
                }
                else {
                    Write-Warning "Sync-TaskStatuses: unexpected error for '$($t.task_name)': $_"
                }
            }
        }
    }

    # Direction 2: OS Scheduler → JSON  -  recover orphaned OS tasks missing from tasks.json
    # This handles the case where Register-ScheduledTask succeeded but Save-TasksJson failed,
    # leaving an OS task with no corresponding record in tasks.json.
    $knownNames = @($tasks | Where-Object { $null -ne $_ -and $_.PSObject.Properties['task_name'] } | ForEach-Object { $_.task_name })
    try {
        $osTasks = @(Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue)
    }
    catch { $osTasks = @() }

    foreach ($osTask in $osTasks) {
        if ($null -eq $osTask -or -not $osTask.TaskName) { continue }
        if ($knownNames -contains $osTask.TaskName) { continue }

        # Parse folder_path from Description: "Daily Motivation Brain Helper - {FolderPath}"
        $folderPath = ''
        $taskDescription = if ($osTask.PSObject.Properties['Description']) { $osTask.Description } else { '' }
        if ($taskDescription -match '^Daily Motivation Brain Helper - (.+)$') {
            $folderPath = $Matches[1].Trim()
        }

        # Parse scheduled time from the first trigger
        $scheduledTime = ''
        try {
            $trigger = $osTask.Triggers | Select-Object -First 1
            if ($trigger -and $trigger.StartBoundary) {
                $scheduledTime = ([datetime]$trigger.StartBoundary).ToString("yyyy-MM-ddTHH:mm:ss")
            }
        }
        catch {}

        $recoveredId = $osTask.TaskName -replace '^DailyMotivation_', ''
        $recovered = [PSCustomObject]@{
            task_id        = $recoveredId
            task_name      = $osTask.TaskName
            folder_path    = $folderPath
            folder_name    = if ($folderPath) { Split-Path -Leaf $folderPath } else { '' }
            scheduled_time = $scheduledTime
            created_at     = (Get-Date -Format "o")
            status         = "PENDING"
            snooze_count   = 0
        }
        $tasks = $tasks + $recovered
        $changed = $true
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

    # If task is already marked DELETED, skip OS unregister
    if ($target.status -eq 'DELETED') {
        $tasks = $tasks | Where-Object { $_.task_id -ne $TaskId }
        Save-TasksJson $tasks
        return $true
    }

    # Use platform adapter if available (for cross-platform testing)
    if ($script:Platform) {
        $script:Platform.UnscheduleTask($TaskId)
    }
    else {
        # Windows-specific Task Scheduler logic
        # Verify unregister succeeded and handle failures properly
        try {
            Unregister-ScheduledTask -TaskName $target.task_name -Confirm:$false -ErrorAction Stop
        }
        catch {
            # Don't remove from tasks.json if unregister failed (maintain consistency)
            return $false
        }
        # Verify task was actually removed  -  use its own try/catch because
        # Get-ScheduledTask throws for not-found tasks (which is the success case).
        $stillExists = $null
        try {
            $stillExists = Get-ScheduledTask -TaskName $target.task_name -ErrorAction Stop
        }
        catch { $stillExists = $null }
        if ($stillExists) {
            return $false
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
    $hour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { $script:ConfigDefaults.default_trigger_hour }
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
    # AG18-016: sort ascending by scheduled_time for consistent display order
    $pending = @($tasks | Where-Object { $_.status -eq "PENDING" } |
        Sort-Object { try { [datetime]$_.scheduled_time } catch { [datetime]::MinValue } })
    $displayTasks = @($pending | ForEach-Object {
        $t = $_
        $displayTime = $t.scheduled_time
        try { $displayTime = ([datetime]$t.scheduled_time).ToString("ddd, MMM d 'at' h:mm tt") } catch {}
        $displayName = if ($t.folder_name) {
            # Replace hyphens/underscores with spaces and title-case
            $n = ($t.folder_name -replace '[-_]', ' ')
            [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($n.ToLower())
        } else { '' }
        [PSCustomObject]@{
            task_id      = $t.task_id
            folder_name  = $displayName
            display_time = $displayTime
            status       = $t.status
        }
    })
    $TaskListControl.ItemsSource          = $displayTasks
    $NoTasksLabelControl.Visibility       = if ($pending.Count -eq 0) { "Visible" } else { "Collapsed" }
}

function Get-HistoryData {
    if (-not (Test-Path -Path "$script:LogPath" -PathType Leaf)) { return @() }
    $lines = @(Get-Content -Path "$script:LogPath" -Encoding UTF8 |
        Where-Object { $_ -match '^\[' } |
        Select-Object -Last 30)
    if (-not $lines) { return @() }

    $items = foreach ($line in $lines) {
        $parts = $line -split '\s*\|\s*'
        if ($parts.Count -ge 5) {
            $outcome        = $parts[4]
            $outcomeDisplay = if ($outcome -eq "PathMissing") { "Path Missing" } else { $outcome }
            [PSCustomObject]@{
                Timestamp      = $parts[0].Trim('[', ']')
                FolderName     = $parts[2]
                OutcomeDisplay = $outcomeDisplay
                OutcomeColor   = switch ($outcome) {
                    "Opened"      { "#52B788" }
                    "Dismissed"   { "#E07A5F" }
                    "Snoozed"     { "#F4A261" }
                    "PathMissing" { "#E07A5F" }
                    default       { "#8888A8" }
                }
            }
        }
    }
    return @($items)
}

function Update-HistoryUI {
    param(
        [Parameter(Mandatory)]
        [object]$HistoryListControl,
        [string]$SortOrder = "newest"
    )
    $items = @(Get-HistoryData)
    if ($items.Count -gt 0) {
        if ($SortOrder -eq "newest") {
            $items = @($items | Sort-Object { $_.Timestamp } -Descending)
        }
        else {
            $items = @($items | Sort-Object { $_.Timestamp })
        }
    }
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
    # Store controls at script scope for timer callback access
    $script:undoLabelCtrl    = $UndoLabelControl
    $script:undoProgressCtrl = $UndoProgressControl
    $script:undoBannerCtrl   = $UndoBannerControl

    $script:lastTaskId       = $TaskId
    $script:undoSeconds      = 30
    $script:undoScheduledFor = $ScheduledFor
    $UndoLabelControl.Text        = "✓ Scheduled for $ScheduledFor - undo in 30s"
    $UndoProgressControl.Value    = 30
    $UndoBannerControl.Visibility = "Visible"
    $script:undoTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $interval = [System.TimeSpan]::FromSeconds(1)
    $script:undoTimer.Interval = $interval
    $script:undoTimer.Add_Tick({
            $script:undoSeconds--
            $script:undoProgressCtrl.Value = $script:undoSeconds
            $script:undoLabelCtrl.Text     = "✓ Scheduled for $script:undoScheduledFor - undo in $($script:undoSeconds)s"
            if ($script:undoSeconds -le 0) {
                $script:undoTimer.Stop()
                $script:undoBannerCtrl.Visibility = "Collapsed"
                $script:lastTaskId       = $null
                $script:undoScheduledFor = $null
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
        [ValidateRange(1, 1440)][int]$Minutes,
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
        [AllowEmptyString()][Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)][datetime]$TriggerTime,
        [switch]$Force
    )

    if ([string]::IsNullOrEmpty($FolderPath)) {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; IsNetworkPath = $false; Error = "FolderPath cannot be null or empty" }
    }

    # Detect network paths (UNC or mapped drives)
    $isUncPath = $FolderPath -match '^\\\\[^\\]'
    $isMappedDrive = $false
    if ($FolderPath -and $FolderPath.Length -ge 2 -and $FolderPath[1] -eq ':') {
        try {
            $driveInfo = [System.IO.DriveInfo]::new($FolderPath.Substring(0, 1))
            $isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
        }
        catch { $isMappedDrive = $false }
        # Note: DriveInfo is a value type and does not implement IDisposable
    }
    $isNetworkPath = $isUncPath -or $isMappedDrive

    # Validate folder path (skip for UNC paths which might not be accessible)
    # Also skip when platform adapter is injected (HeadlessPlatform for cross-platform testing)
    if (-not $script:Platform -and -not $isUncPath -and -not (Test-Path $FolderPath -PathType Container)) {
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

    # Defensive null check: fallback to default message if Get-RandomMessage fails
    if (-not $msg -or -not $msg.PSObject.Properties['Glyph'] -or -not $msg.PSObject.Properties['Title'] -or -not $msg.PSObject.Properties['Body']) {
        $msg = [PSCustomObject]@{
            Glyph = '[•]'
            Title = 'Daily Motivation'
            Body = 'Time to work on your scheduled task!'
        }
    }

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
    $popupConfigParams = @{
        Glyph        = $msg.Glyph
        Title        = $msg.Title
        Body         = $msg.Body
        ExplorerPath = $FolderPath
        TaskId       = $result.TaskId
    }
    Set-PopupConfig @popupConfigParams

    # REQ-010: Register context menu on successful scheduling
    if ($script:ExePath) {
        $regResult = Register-ContextMenu -ExePath $script:ExePath
        if (-not $regResult.Success) {
            Write-Warning "Context menu registration failed: $($regResult.Reason)"
        }
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
    # Guard: only register when invoked from a compiled .exe, not the source .ps1.
    # If the script is run directly (pwsh .\DailyMotivation.ps1), $MyInvocation.MyCommand.Path
    # is the .ps1 path. Storing that in the registry causes "This app can't run on your PC"
    # when Explorer invokes the verb, because Windows tries to execute a text file as a PE.
    if (-not $ExePath -or $ExePath -notmatch '\.exe$') {
        return @{ Success = $false; Reason = "ExePath is not a compiled exe" }
    }
    # Reject paths pointing at system directories to prevent privilege abuse
    if ($ExePath -match '\\Windows\\(System32|SysWOW64)\\') {
        return @{ Success = $false; Reason = "ExePath must not be in System32 or SysWOW64" }
    }
    $verbKey = "HKCU:\Software\Classes\Directory\shell\ScheduleMotivation"
    $cmdKey  = "$verbKey\command"
    try {

        [void](New-Item -Path $verbKey -Force)
        Set-ItemProperty -Path $verbKey -Name "(Default)" -Value "Set as tomorrow's folder (Daily Motivation)"

        [void](New-Item -Path $cmdKey -Force)
        # Escape embedded double-quotes using PowerShell backtick escape
        $escapedPath = $ExePath -replace '"', '`"'
        Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value ('"' + $escapedPath + '" /setfolder "%1"')

        if (-not (Test-Path $verbKey)) {
            return @{ Success = $false; Reason = "Registry verb key verification failed" }
        }
        if (-not (Test-Path $cmdKey)) {
            return @{ Success = $false; Reason = "Registry command key verification failed" }
        }

        return @{ Success = $true; Reason = "" }
    }
    catch {
        return @{ Success = $false; Reason = $_.Exception.Message }
    }
}

function Unregister-ContextMenu {
    Remove-Item "HKCU:\Software\Classes\Directory\shell\ScheduleMotivation" -Recurse -Force -ErrorAction SilentlyContinue
}

# ============================================================
# SECTION 6: Main Window XAML (inline from MainWindow.xaml)
# ============================================================
[xml]$MainXaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="MainWin"
    Title="Daily Motivation Brain Helper  -  Folder Scheduler"
    Width="520" SizeToContent="Height"
    WindowStartupLocation="CenterScreen"
    ResizeMode="CanMinimize"
    Background="#0D1117"
    FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Base button style -->
        <Style x:Key="PrimaryBtn" TargetType="Button">
            <Setter Property="Background"   Value="#00BCD4"/>
            <Setter Property="Foreground"   Value="#FFFFFF"/>
            <Setter Property="FontSize"     Value="13"/>
            <Setter Property="FontWeight"   Value="SemiBold"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding"      Value="20,10"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#00D4EE"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#2A2D36"/>
                    <Setter Property="Foreground" Value="#5A5F6E"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryBtn" TargetType="Button">
            <Setter Property="Background"   Value="#1C1C2C"/>
            <Setter Property="Foreground"   Value="#A0A0C0"/>
            <Setter Property="FontSize"     Value="12"/>
            <Setter Property="BorderBrush"  Value="#5A5A7A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"      Value="15,7"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#252538"/>
                                <Setter TargetName="Bd" Property="BorderBrush" Value="#7A7AAA"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Dark-aware RadioButton  -  replaces system BulletChrome -->
        <Style TargetType="RadioButton">
            <Setter Property="Foreground"       Value="#E8E8F4"/>
            <Setter Property="FontSize"         Value="12"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Grid Width="16" Height="16" Margin="0,0,8,0" VerticalAlignment="Center">
                                <Ellipse Width="16" Height="16"
                                         Stroke="#5A5A7A" StrokeThickness="1.5"
                                         Fill="#1C1C2C"/>
                                <Ellipse x:Name="Dot" Width="8" Height="8"
                                         Fill="#00BCD4"
                                         HorizontalAlignment="Center" VerticalAlignment="Center"
                                         Visibility="Collapsed"/>
                            </Grid>
                            <ContentPresenter VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Dot" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border Background="#0D1117" Padding="28,0,28,24">
        <StackPanel>

            <!-- Header accent bar  -  edge-to-edge, no top dead zone -->
            <Border Background="#00BCD4" Height="3" Margin="-28,0,-28,16"/>

            <!-- Context label  -  replaces duplicated OS title -->
            <TextBlock Text="Schedule a Folder Reminder"
                       FontSize="15" FontWeight="SemiBold" Foreground="#C8C8E8"
                       Margin="0,16,0,16"/>

            <!-- Last Folder Banner (B-01) - hidden until reimplemented -->
            <Border x:Name="LastFolderBanner"
                    Background="#111B22" BorderBrush="#00BCD4" BorderThickness="1"
                    CornerRadius="7" Padding="18,14" Margin="0,0,0,16"
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
                                   FontSize="11" Foreground="#8888A8"
                                   TextTrimming="CharacterEllipsis" MaxWidth="280"/>
                    </StackPanel>
                    <Button x:Name="LastFolderYesBtn" Grid.Column="1"
                            Content="Yes, Schedule" Style="{StaticResource PrimaryBtn}"
                            FontSize="11" Padding="10,5" Margin="10,0,6,0"
                            ToolTip="Schedule the same folder you used last time"/>
                    <Button x:Name="LastFolderDismissBtn" Grid.Column="2"
                            Content="&#x2715;" Style="{StaticResource SecondaryBtn}"
                            FontSize="11" Padding="0" Width="32"
                            ToolTip="Dismiss this suggestion"/>
                </Grid>
            </Border>

            <!-- Drop Zone + Select Folder (visible border, left-aligned) -->
            <Border x:Name="DropZone"
                    Background="#111B22" BorderBrush="#3A4A5A" BorderThickness="1.5"
                    CornerRadius="8" Padding="20,18" Margin="0,0,0,16"
                    MinHeight="140"
                    AllowDrop="True">
                <StackPanel>
                    <TextBlock Text="Drop a folder here, or use the button below"
                               FontSize="12" Foreground="#8888A8"
                               HorizontalAlignment="Left" Margin="0,0,0,10"
                               ToolTip="Drag any folder from Windows Explorer and drop it here"/>
                    <Button x:Name="SelectFolderBtn"
                            Content="Select Folder"
                            Style="{StaticResource SecondaryBtn}"
                            HorizontalAlignment="Left" Padding="20,8"
                            TabIndex="1"
                            AutomationProperties.Name="Open folder browser dialog"
                            ToolTip="Choose the folder you want to open at the scheduled time (Alt+O)"/>
                    <TextBlock x:Name="SelectedPathLabel"
                               Text="No folder selected"
                               FontSize="11" Foreground="#8888A8"
                               HorizontalAlignment="Left" Margin="0,8,0,0"
                               TextTrimming="CharacterEllipsis" MaxWidth="420"/>
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
                                 TabIndex="2"
                                 ToolTip="Schedule this folder to open today at 2:00 PM"/>
                    <RadioButton x:Name="TomorrowRadio"
                                 Content="Tomorrow at 2:00 PM"
                                 FontSize="12" Foreground="#E8E8F4"
                                 IsChecked="True"
                                 TabIndex="3"
                                 ToolTip="Schedule this folder to open tomorrow at 2:00 PM"/>
                </StackPanel>
            </StackPanel>

            <!-- Schedule Button -->
            <Button x:Name="ScheduleBtn"
                    Content="Schedule Reminder"
                    Style="{StaticResource PrimaryBtn}"
                    IsEnabled="False"
                    HorizontalAlignment="Stretch"
                    Padding="20,10"
                    TabIndex="4"
                    AutomationProperties.Name="Schedule folder reminder"
                    ToolTip="Create a reminder to open this folder at the scheduled time (Enter)"/>

            <TextBlock x:Name="ScheduleHintLabel"
                       Text="Select a folder above to enable scheduling"
                       FontSize="11" Foreground="#5A6A7A"
                       HorizontalAlignment="Center" Margin="0,6,0,0"
                       Visibility="Visible"/>

            <TextBlock x:Name="OperationStatusLabel"
                       Text="" FontSize="11" Foreground="#00BCD4"
                       HorizontalAlignment="Center" Margin="0,4,0,0"
                       Visibility="Collapsed"/>

            <!-- Undo Banner (B-04) -->
            <Border x:Name="UndoBanner"
                    Background="#0E2A1A" BorderBrush="#2D6A4F" BorderThickness="1"
                    CornerRadius="7" Padding="14,10" Margin="0,14,0,14"
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
                            TabIndex="5"
                            ToolTip="Cancel the schedule you just created"/>
                </Grid>
            </Border>

            <!-- Divider (raised to 3:1 contrast) -->
            <Border Background="#3A3A5A" Height="1" Margin="0,20,0,20"/>

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
                                    <TextBlock Text="{Binding FolderPath}" FontSize="10" Foreground="#8888A8"
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
                       FontSize="13" FontWeight="Bold" Foreground="#C8C8E8" Margin="0,0,0,6"/>
            <TextBlock x:Name="TaskLoadingLabel"
                       Text="Syncing tasks..."
                       FontSize="11" Foreground="#8888A8" FontStyle="Italic"
                       Margin="0,0,0,6" Visibility="Collapsed"/>
            <ScrollViewer MaxHeight="220" VerticalScrollBarVisibility="Auto">
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
                                    <TextBlock Text="{Binding display_time}" FontSize="10" Foreground="#8888A8"/>
                                </StackPanel>
                                <!-- PENDING badge (neutral color) -->
                                <Border Grid.Column="1"
                                        Background="#1F1F30" CornerRadius="4" Padding="6,2" Margin="8,0">
                                    <TextBlock Text="{Binding status}" FontSize="10" Foreground="#7A7A9A"/>
                                </Border>
                                <Button Grid.Column="2" Tag="{Binding task_id}"
                                        Content="&#x2715;"
                                        Style="{StaticResource SecondaryBtn}"
                                        Width="28" Padding="0"
                                        AutomationProperties.Name="Delete scheduled task"
                                        ToolTip="Delete this scheduled reminder (confirms before removing)"/>
                            </Grid>
                        </DataTemplate>
                    </ItemsControl.ItemTemplate>
                </ItemsControl>
            </ScrollViewer>
            <Border x:Name="NoTasksLabel"
                    Background="#0D1520" BorderBrush="#2A3A4A" BorderThickness="1"
                    CornerRadius="6" Padding="16,12" Margin="0,8,0,0"
                    Visibility="Collapsed">
                <StackPanel HorizontalAlignment="Center">
                    <TextBlock Text="No reminders scheduled yet."
                               FontSize="12" Foreground="#5A7A9A"
                               HorizontalAlignment="Center" FontWeight="SemiBold"/>
                    <TextBlock Text="Select a folder and click Schedule Reminder to get started."
                               FontSize="11" Foreground="#4A5A6A"
                               HorizontalAlignment="Center" Margin="0,4,0,0"
                               TextWrapping="Wrap" TextAlignment="Center"/>
                </StackPanel>
            </Border>

            <!-- History Toggle -->
            <Button x:Name="HistoryToggleBtn"
                    Content="View History"
                    Style="{StaticResource SecondaryBtn}"
                    HorizontalAlignment="Stretch"
                    Margin="0,16,0,0" Padding="12,8"
                    AutomationProperties.Name="Toggle history panel"
                    ToolTip="Show or hide your past folder reminder log (H)"/>

            <!-- History panel -->
            <Border x:Name="HistoryPanel"
                    Background="#0A0A14" BorderBrush="#2A2A42" BorderThickness="1"
                    CornerRadius="7" Padding="14,12" Margin="0,8,0,8"
                    Visibility="Collapsed">
                <StackPanel>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="History" FontSize="12" FontWeight="SemiBold"
                                   Foreground="#8888A8" VerticalAlignment="Center"/>
                        <Button x:Name="SortHistoryBtn" Grid.Column="1"
                                Content="Sort: Newest" Margin="0,0,6,0"
                                Style="{StaticResource SecondaryBtn}"
                                FontSize="10" Padding="8,3"
                                AutomationProperties.Name="Toggle history sort order"
                                ToolTip="Toggle sort order between newest-first and oldest-first"/>
                        <Button x:Name="ClearHistoryBtn" Grid.Column="2"
                                Content="Clear"
                                Style="{StaticResource SecondaryBtn}"
                                FontSize="10" Padding="8,3"
                                AutomationProperties.Name="Clear history log"
                                ToolTip="Clear all history entries"/>
                    </Grid>
                    <ScrollViewer MaxHeight="220" VerticalScrollBarVisibility="Auto" Margin="0,8,0,0">
                        <ItemsControl x:Name="HistoryList">
                            <ItemsControl.ItemTemplate>
                                <DataTemplate>
                                    <Grid Margin="0,3">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="150"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="80"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="{Binding Timestamp}" FontSize="10" Foreground="#8888A8" VerticalAlignment="Center"/>
                                        <TextBlock Grid.Column="1" Text="{Binding FolderName}" FontSize="11" Foreground="#C8C8E8" VerticalAlignment="Center"
                                                   TextTrimming="CharacterEllipsis" ToolTip="{Binding FolderName}"/>
                                        <TextBlock Grid.Column="2" Text="{Binding OutcomeDisplay}" FontSize="11" VerticalAlignment="Center"
                                                   Foreground="{Binding OutcomeColor}"/>
                                    </Grid>
                                </DataTemplate>
                            </ItemsControl.ItemTemplate>
                        </ItemsControl>
                    </ScrollViewer>
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
    if (-not $script:AssembliesLoaded) {
        [Console]::Error.WriteLine("UI cannot display: .NET Framework WPF assemblies not available.")
        return
    }

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
    try {
        $window = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        Show-ErrorDialog "UI failed to load: $($_.Exception.Message)`n`nPlease reinstall the application."
        return
    }
    finally {
        if ($reader) { $reader.Dispose() }
    }
    if ($null -eq $window -or $window -isnot [System.Windows.Window]) {
        Show-ErrorDialog "UI failed to load. Please reinstall the application."
        return
    }

    function Find {
        param($n)
        $control = $window.FindName($n)
        if ($null -eq $control) {
            throw "XAML element not found: $n"
        }
        return $control
    }

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
    $sortHistoryBtn    = Find "SortHistoryBtn"
    $scheduleHintLabel    = Find "ScheduleHintLabel"
    $operationStatusLabel = Find "OperationStatusLabel"
    $taskLoadingLabel     = Find "TaskLoadingLabel"

    $firstRunPath = Join-Path $script:AppDataDir "first_run.done"
    if (-not (Test-Path $firstRunPath)) {
        try {
            $cfgDir = $script:AppDataDir
            [void][System.Windows.MessageBox]::Show(
                "Welcome to Daily Motivation Brain Helper!`n`n" +
                "Getting Started:`n" +
                "  1. Drop a folder into the zone, or click Select Folder`n" +
                "  2. Choose Today or Tomorrow as the schedule time`n" +
                "  3. Click Schedule Reminder  -  a popup will open the folder at that time`n`n" +
                "Keyboard Shortcuts:`n" +
                "  Enter       Schedule the selected folder`n" +
                "  Escape      Close this window`n" +
                "  F1          Show this help again`n" +
                "  H           Toggle history panel`n`n" +
                "Settings Info:`n" +
                "  Trigger hour and thresholds are configured in:`n" +
                "  $cfgDir\config.json`n" +
                "  Changes take effect the next time you open this window.",
                "Welcome!  -  Daily Motivation Brain Helper", "OK", "Information")
            Set-Content -Path $firstRunPath -Value (Get-Date -Format "yyyy-MM-dd") -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {}
    }

    # State
    $script:selectedPath = ""
    $script:lastTaskId   = $null
    $script:undoTimer    = $null
    $script:undoSeconds  = 30

    function Set-SelectedPath {
        param([string]$Path)
        if (-not (Test-Path $Path -PathType Container)) {
            [void][System.Windows.MessageBox]::Show(
                "That path does not exist or is not a folder:`n$Path",
                "Invalid Folder", "OK", "Warning")
            return
        }
        $script:selectedPath          = $Path
        $selectedPathLabel.Text       = $Path
        $selectedPathLabel.Foreground = "#C8C8E8"
        $scheduleBtn.IsEnabled        = $true
        $scheduleHintLabel.Visibility = "Collapsed"
    }

    function Do-Schedule {
        param([string]$FolderPath)
        # Re-evaluate Today radio visibility at schedule time
        if ($todayRadio.Visibility -eq "Visible" -and (Get-Date).Hour -ge $hour) {
            $todayRadio.Visibility  = "Collapsed"
            $todayRadio.IsChecked   = $false
            $tomorrowRadio.IsChecked = $true
        }
        $triggerTime = Get-ScheduleTime -TodayRadioControl $todayRadio

        $scheduleBtn.IsEnabled        = $false
        $operationStatusLabel.Text    = "Creating reminder..."
        $operationStatusLabel.Visibility = "Visible"
        # Force a render pass so the label is visible before the blocking call
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Render, [System.Action]{})

        # Attempt to schedule the folder (business logic extracted to Invoke-FolderScheduling)
        $result = Invoke-FolderScheduling -FolderPath $FolderPath -TriggerTime $triggerTime

        $operationStatusLabel.Visibility = "Collapsed"
        $scheduleBtn.IsEnabled = ($script:selectedPath -ne "")

        # Handle validation errors
        if (-not $result.Success -and -not $result.IsDuplicate) {
            if ($result.Error) {
                [void][System.Windows.MessageBox]::Show(
                    "Could not schedule reminder for this folder.`n`n$(Get-SafeErrorMessage $result.Error)",
                    "Schedule Failed", "OK", "Warning")
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
                Show-ErrorDialog "Could not create the scheduled task.`n$(Get-SafeErrorMessage $result.Error)"
                return
            }
        }

        # Show network path warning if applicable
        if ($result.IsNetworkPath) {
            [void][System.Windows.MessageBox]::Show(
                "Scheduled, but '$FolderPath' is a network location. The popup may fail if the share is unavailable at trigger time.`n`nTip: Use a UNC path instead of a mapped drive letter.",
                "Network Path Warning", "OK", "Warning")
        }

        # Update UI
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
        $dateLabel = $triggerTime.ToString("dddd 'at' h:mm tt")
        Start-UndoTimer -TaskId $result.TaskId -ScheduledFor $dateLabel -UndoLabelControl $undoLabel -UndoProgressControl $undoProgress -UndoBannerControl $undoBanner
    }

    # Show Today radio only before trigger hour; set dynamic labels from config
    $cfg  = Get-Config
    $hour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { $script:ConfigDefaults.default_trigger_hour }
    $timeLabel = [datetime]::Today.AddHours($hour).ToString("h:mm tt")
    $todayRadio.Content    = "Today at $timeLabel"
    $tomorrowRadio         = Find "TomorrowRadio"
    $tomorrowRadio.Content = "Tomorrow at $timeLabel"
    if ((Get-Date).Hour -lt $hour) { $todayRadio.Visibility = "Visible" }

    # --- Event handlers ---
    $selectFolderBtn.Add_Click({
            $dialog = $null
            try {
                $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
                $dialog.Description         = "Select the folder you want to open tomorrow"
                $dialog.ShowNewFolderButton = $false
                if ($dialog.ShowDialog() -eq "OK") { Set-SelectedPath $dialog.SelectedPath }
            }
            finally {
                if ($dialog) { $dialog.Dispose() }
            }
        })

    $converter = [System.Windows.Media.BrushConverter]::new() # AG14-006: Reuse single BrushConverter
    $script:dropZoneBrushNormal = $converter.ConvertFrom("#3A4A5A")
    $script:dropZoneBrushHover  = $converter.ConvertFrom("#00BCD4")
    $script:dropZoneBgNormal    = $converter.ConvertFrom("#111B22")
    $script:dropZoneBgHover     = $converter.ConvertFrom("#162028")

    $dropZone.Add_DragEnter({
            param($s, $e)
            if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
                $dropZone.BorderBrush  = $script:dropZoneBrushHover
                $dropZone.Background   = $script:dropZoneBgHover
                $dropZone.BorderThickness = [System.Windows.Thickness]::new(2)
            }
            $e.Handled = $true
        })

    $dropZone.Add_DragLeave({
            $dropZone.BorderBrush  = $script:dropZoneBrushNormal
            $dropZone.Background   = $script:dropZoneBgNormal
            $dropZone.BorderThickness = [System.Windows.Thickness]::new(1.5)
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
            # Reset drag-over visual state
            $dropZone.BorderBrush     = $script:dropZoneBrushNormal
            $dropZone.Background      = $script:dropZoneBgNormal
            $dropZone.BorderThickness = [System.Windows.Thickness]::new(1.5)
            if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
                $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
                if ($dropped.Count -gt 0 -and (Test-Path $dropped[0] -PathType Container)) {
                    Set-SelectedPath $dropped[0]
                }
                else {
            [void][System.Windows.MessageBox]::Show("Please drop a folder, not a file.",
                        "Not a Folder", "OK", "Warning")
                }
            }
        })

    $scheduleBtn.Add_Click({
            if ($script:selectedPath) { Do-Schedule -FolderPath $script:selectedPath }
        })

    $undoBtn.Add_Click({
            if ($script:lastTaskId) {
                $removedId = $script:lastTaskId
                Stop-UndoTimer -UndoBannerControl $undoBanner
                Remove-MotivationTask -TaskId $removedId
                $script:lastTaskId       = $null
                $script:undoScheduledFor = $null
                Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
                $scheduleBtn.IsEnabled = ($script:selectedPath -ne "")
                $undoLabel.Text        = "Reminder cancelled successfully. Your folder was not scheduled."
                $undoBanner.Visibility = "Visible"
                $undoFeedbackTimer = [System.Windows.Threading.DispatcherTimer]::new()
                $undoFeedbackTimer.Interval = [System.TimeSpan]::FromMilliseconds(2500)
                $undoFeedbackTimer.Add_Tick({
                    $undoFeedbackTimer.Stop()
                    try { $undoFeedbackTimer.Dispose() } catch {}
                    $undoBanner.Visibility = "Collapsed"
                })
                $undoFeedbackTimer.Start()
            }
        })

    $taskList.Add_PreviewMouseLeftButtonUp({
            param($s, $e)
            # Block deletions while an undo grace period is active
            if ($script:lastTaskId) {

            [void][System.Windows.MessageBox]::Show(
                    "Please wait until the undo period completes before deleting tasks.",
                    "Undo in Progress", "OK", "Information")
                return
            }
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

    $script:historySortOrder = "newest"

    $historyToggleBtn.Add_Click({
            if ($historyPanel.Visibility -eq "Visible") {
                $historyPanel.Visibility  = "Collapsed"
                $historyToggleBtn.Content = "View History"   # matches new Content attribute
            }
            else {
                Update-HistoryUI -HistoryListControl $historyList -SortOrder $script:historySortOrder
                $historyPanel.Visibility  = "Visible"
                $historyToggleBtn.Content = "Hide History"
            }
        })

    $clearHistoryBtn.Add_Click({
            $confirm = [System.Windows.MessageBox]::Show(
                "Clear all history entries? This cannot be undone.",
                "Clear History", "YesNo", "Question")
            if ($confirm -eq "Yes") {
                if (Test-Path -Path "$script:LogPath" -PathType Leaf) { Clear-Content $script:LogPath }
                Update-HistoryUI -HistoryListControl $historyList -SortOrder $script:historySortOrder
            }
        })

    $sortHistoryBtn.Add_Click({
        if ($script:historySortOrder -eq "newest") {
            $script:historySortOrder = "oldest"
            $sortHistoryBtn.Content  = "Sort: Oldest"
        }
        else {
            $script:historySortOrder = "newest"
            $sortHistoryBtn.Content  = "Sort: Newest"
        }
        if ($historyPanel.Visibility -eq "Visible") {
            Update-HistoryUI -HistoryListControl $historyList -SortOrder $script:historySortOrder
        }
    })

    $window.Add_KeyDown({
        param($ks, $ke)
        switch ($ke.Key) {
            ([System.Windows.Input.Key]::Return) {
                if ($scheduleBtn.IsEnabled -and $script:selectedPath) {
                    Do-Schedule -FolderPath $script:selectedPath
                    $ke.Handled = $true
                }
            }
            ([System.Windows.Input.Key]::Escape) {
                $window.Close()
                $ke.Handled = $true
            }
            ([System.Windows.Input.Key]::F1) {
                [void][System.Windows.MessageBox]::Show(
                    "Keyboard Shortcuts:`n`n" +
                    "  Enter    Schedule the selected folder`n" +
                    "  Escape   Close this window`n" +
                    "  F1       Show this help`n" +
                    "  H        Toggle history panel`n`n" +
                    "Settings file: $($script:AppDataDir)\config.json",
                    "Help  -  Keyboard Shortcuts", "OK", "Information")
                $ke.Handled = $true
            }
            ([System.Windows.Input.Key]::H) {
                $historyToggleBtn.RaiseEvent(
                    [System.Windows.RoutedEventArgs]::new(
                        [System.Windows.Controls.Button]::ClickEvent))
                $ke.Handled = $true
            }
        }
    })

    $window.Add_Closed({
        try {
            # Stop and dispose undo timer if still running
            if ($script:undoTimer) {
                $script:undoTimer.Stop()
                try { $script:undoTimer.Dispose() } catch {}
                $script:undoTimer = $null
            }
            foreach ($brush in @($script:dropZoneBrushNormal, $script:dropZoneBrushHover, 
                                 $script:dropZoneBgNormal, $script:dropZoneBgHover)) {
                if ($brush -is [System.IDisposable]) {
                    try { $brush.Dispose() } catch {}
                }
            }
            # Reset state variables to prevent leakage across window instances
            $script:lastTaskId = $null
            $script:undoScheduledFor = $null
            $script:selectedPath = ""
        }
        catch {}
    })

    $window.Add_Closing({
        if ($script:undoTimer) {
            $script:undoTimer.Stop()
            $script:undoTimer = $null
        }
        if ($script:undoFeedbackTimer) {
            $script:undoFeedbackTimer.Stop()
            $script:undoFeedbackTimer = $null
        }
    })

    $taskLoadingLabel.Visibility = "Visible"
    $initSyncTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $initSyncTimer.Interval = [System.TimeSpan]::FromMilliseconds(80)
    $initSyncTimer.Add_Tick({
        $initSyncTimer.Stop()
        try { $initSyncTimer.Dispose() } catch {}
        Sync-TaskStatuses
        Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
        $taskLoadingLabel.Visibility = "Collapsed"
    })
    $initSyncTimer.Start()

    try {

        [void]$window.ShowDialog()
    }
    finally {
        if ($window) {
            $window.Close()
        }
    }
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
            <DropShadowEffect Color="Black" BlurRadius="24" ShadowDepth="0" Opacity="0.40"/>
        </Border.Effect>
        <StackPanel>
            <Border Background="#00BCD4" Height="3" CornerRadius="2" Margin="0,0,0,22"/>

            <!-- Normal mode -->
            <StackPanel x:Name="NormalPanel">
                <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                    <TextBlock x:Name="GlyphText" FontSize="26" Foreground="#00BCD4"
                               VerticalAlignment="Center" Margin="0,0,12,0"/>
                    <TextBlock x:Name="TitleText" FontSize="19" FontWeight="Bold" MaxHeight="60"
                               Foreground="#E8E8F4" VerticalAlignment="Center"
                               TextWrapping="Wrap" MaxWidth="380"/>
                </StackPanel>
                <TextBlock x:Name="BodyText" FontSize="14" Foreground="#8888A8" MaxWidth="400" MaxHeight="150"
                           TextWrapping="Wrap" LineHeight="23" Margin="0,0,0,6"/>
                <TextBlock x:Name="FolderNameText" FontSize="12" Foreground="#8888A8"
                           TextWrapping="Wrap" Margin="0,0,0,22" Visibility="Collapsed"/>
                <Border Background="#303050" Height="1" Margin="0,0,0,18"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,22" VerticalAlignment="Center">
                    <TextBlock Text="Auto-opening in " FontSize="12" Foreground="#8888A8" VerticalAlignment="Center"/>
                    <TextBlock x:Name="CountdownText" Text="20" FontSize="12" FontWeight="Bold"
                               Foreground="#00BCD4" VerticalAlignment="Center"/>
                    <TextBlock Text="s" FontSize="12" Foreground="#8888A8" VerticalAlignment="Center"/>
                    <Button x:Name="PauseBtn" Content="Pause" Margin="12,0,0,0"
                            FontSize="11" Height="22" Padding="8,0"
                            Foreground="#8888A8" Background="#1C1C2C"
                            BorderBrush="#3A3A5A" BorderThickness="1" Cursor="Hand"
                            AutomationProperties.Name="Pause or resume countdown timer"
                            ToolTip="Pause or resume the auto-open countdown">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                        BorderBrush="{TemplateBinding BorderBrush}"
                                        BorderThickness="{TemplateBinding BorderThickness}"
                                        CornerRadius="4">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#252538"/>
                                        <Setter TargetName="Bd" Property="BorderBrush" Value="#5A5A7A"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
                <!-- Buttons -->
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="DismissBtn" Content="Dismiss for Today"
                            Width="148" Height="36" Foreground="#7878A0" FontSize="11"
                            Background="#14141F" BorderBrush="#555580" BorderThickness="1"
                            Cursor="Hand" Margin="0,0,8,0" TabIndex="3"
                            AutomationProperties.Name="Dismiss this notification for today"
                            ToolTip="Close this popup and remove the scheduled task for today">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                        BorderBrush="{TemplateBinding BorderBrush}"
                                        BorderThickness="{TemplateBinding BorderThickness}"
                                        CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#1E1E30"/>
                                        <Setter TargetName="Bd" Property="BorderBrush" Value="#7878A0"/>
                                    </Trigger>
                                    <Trigger Property="IsPressed" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#28283A"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                    <StackPanel Orientation="Horizontal" Margin="0,0,8,0">
                        <Button x:Name="SnoozeBtn" Content="Snooze 5m" Height="36"
                                Foreground="#8585A5" FontSize="12" FontWeight="SemiBold"
                                Background="#1C1C2C" BorderBrush="#3A3A5A"
                                BorderThickness="1,1,0,1" Cursor="Hand" Padding="10,0" TabIndex="1"
                                AutomationProperties.Name="Snooze reminder"
                                ToolTip="Snooze this reminder (use dropdown to change duration)">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                            BorderBrush="{TemplateBinding BorderBrush}"
                                            BorderThickness="{TemplateBinding BorderThickness}"
                                            CornerRadius="7,0,0,7">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="Bd" Property="Background" Value="#252538"/>
                                            <Setter TargetName="Bd" Property="BorderBrush" Value="#5A5A7A"/>
                                        </Trigger>
                                        <Trigger Property="IsPressed" Value="True">
                                            <Setter TargetName="Bd" Property="Background" Value="#1A1A28"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Button.Template>
                        </Button>
                        <Button x:Name="SnoozeDropBtn" Content="&#x25BE;" Width="28" Height="36"
                                Foreground="#8585A5" FontSize="13"
                                Background="#1C1C2C" BorderBrush="#3A3A5A" BorderThickness="1"
                                Cursor="Hand" TabIndex="2">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                            BorderBrush="{TemplateBinding BorderBrush}"
                                            BorderThickness="{TemplateBinding BorderThickness}"
                                            CornerRadius="0,7,7,0">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="Bd" Property="Background" Value="#252538"/>
                                        </Trigger>
                                        <Trigger Property="IsPressed" Value="True">
                                            <Setter TargetName="Bd" Property="Background" Value="#1A1A28"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Button.Template>
                            <Button.ContextMenu>
                                <ContextMenu Background="#1C1C2C" BorderBrush="#2A2A42">
                                    <MenuItem x:Name="Snooze5"  Header=" 5 minutes (default)" Foreground="#E8E8F4" FontSize="12"/>
                                    <MenuItem x:Name="Snooze15" Header=" 15 minutes"           Foreground="#E8E8F4" FontSize="12"/>
                                    <MenuItem x:Name="Snooze30" Header=" 30 minutes"           Foreground="#E8E8F4" FontSize="12"/>
                                    <MenuItem x:Name="Snooze60" Header=" 1 hour"               Foreground="#E8E8F4" FontSize="12"/>
                                    <Separator/>
                                    <MenuItem x:Name="ExitItem" Header=" Exit"                 Foreground="#7878A0" FontSize="12"/>
                                </ContextMenu>
                            </Button.ContextMenu>
                        </Button>
                    </StackPanel>
                    <!-- Open Folder  -  TabIndex=0 (primary action) -->
                    <Button x:Name="LetsGoBtn" Content="Open Folder &#x2192;" Width="150" Height="36"
                            Foreground="#0D1117" FontSize="13" FontWeight="Bold"
                            Background="#00BCD4" BorderThickness="0" Cursor="Hand" TabIndex="0"
                            AutomationProperties.Name="Open scheduled folder now">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#00D4EE"/>
                                    </Trigger>
                                    <Trigger Property="IsPressed" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#00A8BE"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
            </StackPanel>

            <StackPanel x:Name="PathMissingPanel" Visibility="Collapsed">
                <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                    <TextBlock Text="[!]" FontSize="26" Foreground="#F4A261"
                               VerticalAlignment="Center" Margin="0,0,12,0"/>
                    <TextBlock Text="Folder Not Found" FontSize="19" FontWeight="Bold"
                               Foreground="#E8E8F4" VerticalAlignment="Center"/>
                </StackPanel>
                <TextBlock Text="The folder you scheduled was moved or deleted."
                           FontSize="14" Foreground="#8888A8" TextWrapping="Wrap" Margin="0,0,0,6"/>
                <TextBlock x:Name="MissingPathLabel" FontSize="12" Foreground="#9090B8"
                           TextWrapping="Wrap" Margin="0,0,0,22"/>
                <Border Background="#303050" Height="1" Margin="0,0,0,18"/>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="PathDismissBtn" Content="Close" Width="100" Height="36"
                            Foreground="#8585A5" FontSize="12"
                            Background="#1C1C2C" BorderBrush="#3A3A5A" BorderThickness="1"
                            Cursor="Hand" Margin="0,0,10,0">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="Bd" Background="{TemplateBinding Background}"
                                        BorderBrush="{TemplateBinding BorderBrush}"
                                        BorderThickness="{TemplateBinding BorderThickness}"
                                        CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#252538"/>
                                        <Setter TargetName="Bd" Property="BorderBrush" Value="#5A5A7A"/>
                                    </Trigger>
                                    <Trigger Property="IsPressed" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#1A1A28"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                    <Button x:Name="RePickBtn" Content="Choose New Location" Width="170" Height="36"
                            Foreground="#0D1117" FontSize="12" FontWeight="Bold"
                            Background="#00BCD4" BorderThickness="0" Cursor="Hand">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="7">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#00D4EE"/>
                                    </Trigger>
                                    <Trigger Property="IsPressed" Value="True">
                                        <Setter TargetName="Bd" Property="Background" Value="#00A8BE"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
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

function Get-PopupOutcome {
    <#
    .SYNOPSIS
        Maps the popup's end-of-session state to the canonical Outcome string.
    .DESCRIPTION
        Pure (stateless) function kept out of Show-PopupWindow so the outcome
        mapping is independently unit-testable. The Outcome written to the
        Outcome Log must reflect the action the user actually took (or the
        countdown auto-open) -- never a fixed default.
        Precedence:
          1. PathMissing -- the folder is gone AND the user did not open/re-pick
          2. Opened      -- the user opened the folder, the countdown auto-opened,
                            or the user re-picked a new folder
          3. Snoozed     -- the user snoozed at least once before closing
          4. Dismissed   -- default: closed without opening (Dismiss / Exit)
    .PARAMETER PathMissing
        $true when the FolderPath no longer exists at popup display time.
    .PARAMETER OpenExplorer
        $true when the user's final action requires Explorer to open.
    .PARAMETER SnoozeCount
        Number of times the user snoozed during this popup session.
    .OUTPUTS
        [string] One of: Opened, Snoozed, Dismissed, PathMissing.
    #>
    param(
        [bool]$PathMissing,
        [bool]$OpenExplorer,
        [int]$SnoozeCount = 0
    )
    if ($PathMissing -and -not $OpenExplorer) { return "PathMissing" }
    if ($OpenExplorer)                       { return "Opened" }
    if ($SnoozeCount -gt 0)                  { return "Snoozed" }
    return "Dismissed"
}

function Show-PopupWindow {
    $configPath = $script:PopupCfgPath

    # Named mutex - one popup at a time, with user and session isolation to prevent DoS between users
    $sessionId = 0
    try { $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId } catch {}
    $mutexName  = "Global\DailyMotivationBrainHelperPopup_$env:USERNAME`_$sessionId"
    # Expose mutex name at script scope so tests can verify user-isolation naming convention
    $script:PopupMutexName = $mutexName
    $mutexOwned = $false
    $mutex      = $null
    try {
        $mutex      = [System.Threading.Mutex]::new($false, $mutexName)
        $mutexOwned = $mutex.WaitOne(0)
        if (-not $mutexOwned) {
            # Dispose the mutex handle even when we did not acquire ownership,
            # to release the kernel object reference and prevent a handle leak.
            if ($mutex) { $mutex.Dispose() }
            return
        }
    }
    catch [System.Threading.AbandonedMutexException] {
        $mutexOwned = $true
        Start-Sleep -Milliseconds 500
        $stale = Get-Process | Where-Object { $_.MainWindowTitle -like "*Daily Motivation*" -and $_.Id -ne $PID }
        if ($stale) {
            if ($mutex) { try { $mutex.ReleaseMutex() } catch {} }
            if ($mutex) { $mutex.Dispose() }
            return
        }
    }
    catch {
        if ($mutex) { $mutex.Dispose() }
        return  # Exit safely rather than proceed with undefined state
    }

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
            $config = Get-Content -Path "$configPath" -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            # Log parse failure; do not swallow silently (AG15-014)
            $debugLog = Join-Path $script:AppDataDir 'popup_debug.txt'
            Add-Content -Path $debugLog `
                -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] popup_config.json parse failed: $($_.Exception.Message)" `
                -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }

    # Exit silently if no folder has been configured
    if (-not $config.explorer_path) {
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return
    }

    $script:pathMissing = -not (Test-Path $config.explorer_path -PathType Container)

    # Build popup window
    $reader = $null
    try {
        $reader = [System.Xml.XmlNodeReader]::new($PopupXaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
        if ($null -eq $window) {
            Write-Warning "Show-PopupWindow: XamlReader returned null  -  popup window could not be created."
            if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
            return
        }
    }
    catch {
        Write-Warning "Show-PopupWindow: Failed to load popup XAML  -  $_"
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
    }

    # Validate FindName() returns non-null to prevent "member on null" errors
    function Find {
        param($n)
        $control = $window.FindName($n)
        if ($null -eq $control) {
            throw "XAML element not found: $n"
        }
        return $control
    }

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
    $exitItem         = Find "ExitItem"
    $dismissBtn       = Find "DismissBtn"
    $missingPathLabel = Find "MissingPathLabel"
    $pathDismissBtn   = Find "PathDismissBtn"
    $rePickBtn        = Find "RePickBtn"
    # Pause button (only in normal mode; path-missing panel doesn't have countdown)
    $pauseBtn         = if (-not $script:pathMissing) { Find "PauseBtn" } else { $null }

    # Populate UI based on mode (normal vs path-missing)
    if ($script:pathMissing) {
        $normalPanel.Visibility      = "Collapsed"
        $pathMissingPanel.Visibility = "Visible"
        $folderName = if ($config.explorer_path) { Split-Path -Leaf $config.explorer_path } else { "Unknown" }
        if (-not $folderName) { $folderName = "Unknown" }
        $missingPathLabel.Text = "This folder can't be found: $(Escape-XmlText $folderName)"
        $missingPathLabel.ToolTip    = $config.explorer_path
    }
    else {
        $glyphText.Text = Escape-XmlText $config.glyph
        $titleText.Text = Escape-XmlText (Strip-MarkupText $config.title)
        $bodyText.Text  = Truncate-TextForDisplay (Escape-XmlText (Strip-MarkupText $config.body)) -MaxLength 150
        if ($config.folder_name) {
            # UNC root shares show full path instead of leaf name
            $displayName = if ($config.explorer_path -match '^\\\\[^\\]+\\[^\\]+$') {
                $config.explorer_path
            }
            else { $config.folder_name }
            $folderNameText.Text       = "Folder: $(Escape-XmlText $displayName)"
            $folderNameText.Visibility = "Visible"
        }
    }

    # State
    $script:openExplorer    = $true
    $script:remaining       = 20
    $script:snoozeMinutes   = 5
    $script:snoozeCount     = 0
    $script:newExplorerPath = ""
    $script:windowClosed    = $false   # Guard against queued dispatcher tick
    $script:timerPaused     = $false   # Pause/resume support

    # Fade-in animation with recovery fallback
    $window.Add_Loaded({
            try {
                $anim = [System.Windows.Media.Animation.DoubleAnimation]::new(
                    0, 1, [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(300)))
                $window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
            }
            catch {
                $window.Opacity = 1  # ensure visible if animation fails
            }
            # Fallback: if opacity is still 0 after 500ms, force it visible
            $fallbackTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $fallbackInterval = [System.TimeSpan]::FromMilliseconds(500)
            if ($fallbackInterval.TotalMilliseconds -gt 0) {
                $fallbackTimer.Interval = $fallbackInterval
            }
            $fallbackTimer.Add_Tick({
                $fallbackTimer.Stop()
                if ($window.Opacity -lt 0.5) { $window.Opacity = 1 }
            })
            $fallbackTimer.Start()
        })

    # Race condition fix: stop countdown on ANY button press before click handler fires
    # PreviewMouseDown fires before Click, so this safely cancels the timer first.
    $cancelCountdown = {
        param($s, $e)
        if ($null -ne $timer -and $timer.IsEnabled) {
            $timer.Stop()
        }
    }
    $letsGoBtn.Add_PreviewMouseDown($cancelCountdown)
    $dismissBtn.Add_PreviewMouseDown($cancelCountdown)
    $snoozeBtn.Add_PreviewMouseDown($cancelCountdown)
    $snoozeDropBtn.Add_PreviewMouseDown($cancelCountdown)

    # Countdown timer (normal mode only)
    if (-not $script:pathMissing) {
        $timer = [System.Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [System.TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            try {
                if ($null -eq $window -or -not $window.IsLoaded) {
                    $script:windowClosed = $true
                    $timer.Stop()
                    return
                }
                if ($script:windowClosed) {
                    $timer.Stop()
                    return
                }
                $script:remaining--
                $countdownText.Text = $script:remaining
                if ($script:remaining -le 0 -and -not $script:windowClosed) {
                    $script:windowClosed = $true
                    $timer.Stop()
                    $script:openExplorer = $true
                    $window.Close()
                }
            }
            catch {
                $script:windowClosed = $true
                $timer.Stop()
            }
            finally {
                if ($script:remaining -le 0 -or $script:windowClosed) {
                    $timer.Stop()
                }
            }
        })
        $timer.Start()

        if ($null -ne $pauseBtn) {
            $pauseBtn.Add_Click({
                if ($script:timerPaused) {
                    $timer.Start()
                    $pauseBtn.Content       = "Pause"
                    $script:timerPaused     = $false
                }
                else {
                    $timer.Stop()
                    $pauseBtn.Content       = "Resume"
                    $script:timerPaused     = $true
                }
            })
        }
    }

    # Snooze duration helpers
    $snoozeDropBtn.Add_Click({
        if ($null -eq $snoozeDropBtn.ContextMenu) {
            return
        }
        $snoozeDropBtn.ContextMenu.PlacementTarget = $snoozeDropBtn
        $snoozeDropBtn.ContextMenu.Placement = 'Bottom'
        $snoozeDropBtn.ContextMenu.IsOpen = $true
    })

    $snooze5.Add_Click({  Set-SnoozeDuration -Minutes 5 -SnoozeBtnControl $snoozeBtn  })
    $snooze15.Add_Click({ Set-SnoozeDuration -Minutes 15 -SnoozeBtnControl $snoozeBtn })
    $snooze30.Add_Click({ Set-SnoozeDuration -Minutes 30 -SnoozeBtnControl $snoozeBtn })
    $snooze60.Add_Click({ Set-SnoozeDuration -Minutes 60 -SnoozeBtnControl $snoozeBtn })

    # Exit item closes the popup without opening explorer (equivalent to Dismiss)
    if ($exitItem) {
        $exitItem.Add_Click({
            if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) { $timer.Stop() }
            $script:openExplorer = $false
            $script:windowClosed = $true
            $window.Close()
        })
    }

    # Snooze button
    $snoozeBtn.Add_Click({
        try {
            if (-not $script:pathMissing) { $timer.Stop() }
            $script:snoozeCount++
            $script:openExplorer = $false
            if ($script:snoozeMinutes -lt 1 -or $script:snoozeMinutes -gt 1440) {

                [void][System.Windows.MessageBox]::Show(
                    "Snooze duration must be between 1 minute and 24 hours.",
                    "Invalid Snooze", "OK", "Error")
                return
            }
            # AG18-017: verify originating task still exists before creating snooze replacement.
            # Another process may have removed the task between popup-load and snooze-click.
            if (-not [string]::IsNullOrEmpty($config.task_id)) {
                $originTask = Get-MotivationTasks | Where-Object {
                    $_.task_id -eq $config.task_id -and $_.status -eq 'PENDING'
                }
                if (-not $originTask) {
                    $script:openExplorer = $false
                    $script:windowClosed = $true
                    $window.Close()
                    return
                }
            }
            # If system processing takes time, this ensures TriggerTime validation won't fail
            $bufferMinutes = 1
            $snoozeTime = (Get-Date).AddMinutes($script:snoozeMinutes + $bufferMinutes)
            $snoozeResult = New-MotivationTask -FolderPath $config.explorer_path -TriggerTime $snoozeTime -Force
            if (-not $snoozeResult.Success) {

                [void][System.Windows.MessageBox]::Show(
                    "Could not snooze the task.`n`n$($snoozeResult.Error)",
                    "Snooze Failed", "OK", "Error")
                return
            }
            # Refresh popup_config.json with the NEW TaskId. The snooze creates a fresh
            # MotivationTask; without this, popup_config.json still holds the original
            # task id, so when the snoozed task fires its post-close Remove-MotivationTask
            # targets an already-removed id (a no-op) and the snoozed OS task is never
            # deleted (BUG-B, issue #183). Preserve the existing message/folder.
            Set-PopupConfig -Glyph ([string]$config.glyph) -Title ([string]$config.title) `
                            -Body ([string]$config.body) -ExplorerPath $config.explorer_path `
                            -TaskId $snoozeResult.TaskId
            $window.Close()
        }
        catch {
            if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) {
                $timer.Stop()
            }
            $window.Close()
        }
    })

    # Dismiss for Today
    $dismissBtn.Add_Click({
        try {
            if (-not $script:pathMissing) { $timer.Stop() }
            $script:openExplorer = $false
            if ($config.explorer_path) {
                $pending = Get-MotivationTasks | Where-Object {
                    $_.folder_path -eq $config.explorer_path -and $_.status -eq "PENDING"
                }
                foreach ($t in $pending) {
                    Remove-MotivationTask -TaskId $t.task_id | Out-Null
                }
            }
            $window.Close()
        }
        catch {
            if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) {
                $timer.Stop()
            }
            $window.Close()
        }
    })

    # Open Folder button
    $letsGoBtn.Add_Click({
        try {
            if (-not $script:pathMissing) { $timer.Stop() }
            $script:openExplorer = $true
            $window.Close()
        }
        catch {
            if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) {
                $timer.Stop()
            }
        }
    })

    # Path missing - Dismiss
    $pathDismissBtn.Add_Click({
        $script:openExplorer = $false
        $window.Close()
    })

    # Path missing - Re-pick folder
    $rePickBtn.Add_Click({
        $dialog = $null
        try {
            $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
            $dialog.Description         = "Choose the new location for this folder"
            $dialog.ShowNewFolderButton = $false
            if ($dialog.ShowDialog() -eq "OK") {
                $newPath = $dialog.SelectedPath
                try {
                    $c = Get-PopupConfig
                    $popupParams = @{
                        Glyph        = $c.glyph
                        Title        = $c.title
                        Body         = $c.body
                        ExplorerPath = $newPath
                        TaskId       = $c.task_id
                    }
                    Set-PopupConfig @popupParams
                    $script:newExplorerPath = $newPath
                    $script:openExplorer    = $true
                    $window.Close()
                }
                catch {
                    [void][System.Windows.MessageBox]::Show(
                        "Could not save the new folder path.`n`n$($_.Exception.Message)",
                        "Save Failed", "OK", "Error")
                }
            }
        }
        finally {
            if ($dialog) { $dialog.Dispose() } # AG14-001
        }
    })

    # AG6-010: Stop timers when window is closing to prevent resource leaks
    $window.Add_Closing({
        if ($null -ne $timer -and $timer.IsEnabled) { $timer.Stop() }
        if ($null -ne $fallbackTimer -and $fallbackTimer.IsEnabled) { $fallbackTimer.Stop() }
    })

    # Add window cleanup handler for timers
    $window.Add_Closed({
        try {
            # Stop and dispose fallback timer if it exists
            if ($null -ne $fallbackTimer) {
                try {
                    $fallbackTimer.Stop()
                    $fallbackTimer.Dispose()
                } catch {}
            }
            # Stop and dispose countdown timer if it exists
            if ($null -ne $timer) {
                try {
                    $timer.Stop()
                    $timer.Dispose()
                } catch {}
            }
        }
        catch {}
    })

    # BUG-A diagnostics (issue #183): record entry time + task_id before showing so
    # the gap to the close timestamp in popup_log.txt reveals whether the window stayed
    # up the full 20s countdown or closed early. popup_debug.txt is separate from the
    # outcome log, so history parsing is unaffected. Safe to remove once confirmed.
    try {
        Add-Content -Path (Join-Path $script:AppDataDir 'popup_debug.txt') `
                    -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Show-PopupWindow: entered, task_id=$($config.task_id) path_exists=$(-not $script:pathMissing)" `
                    -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {}

    # Show popup
    try {
        [void]$window.ShowDialog()
    }
    catch {
        # BUG-A diagnostics (issue #183): a swallowed exception here is the leading
        # suspect for the popup "appearing then closing within seconds." If ShowDialog
        # throws, the window never stays up; post-close then runs with the default open
        # flag still set from the State block, so the outcome is logged "Opened."
        # Written to a dedicated debug file (not popup_log.txt) so the outcome log
        # and history parser are unaffected. Safe to remove once BUG-A is confirmed.
        try {
            Add-Content -Path (Join-Path $script:AppDataDir 'popup_debug.txt') `
                        -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Show-PopupWindow: ShowDialog threw: $($_.Exception.Message)" `
                        -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {}
    }
    finally {
        # Close WPF window to release resources
        if ($window) {
            try {
                $window.Close()
            }
            catch {}
        }

        # DO NOT reset $script:openExplorer / $script:snoozeCount / $script:pathMissing /
        # $script:newExplorerPath here. This finally block runs before the post-close
        # cleanup and outcome-logging below, which read those values to decide the Outcome
        # and the effective folder path. Resetting them here forces every outcome to
        # "Opened" (BUG-1) and reverts a RePick folder to the stale path.
        # State is initialised once at the top of this function (the "# State" block),
        # which is the single reset point between popup instances.

        if ($mutexOwned -and $mutex) {
            try { $mutex.ReleaseMutex() }
            catch {}
        }
        if ($null -ne $mutex) {
            try { $mutex.Dispose() }
            catch {}
        }
    }

    # Post-close: remove the originating task from Task Scheduler and tasks.json.
    # This must happen for ALL outcomes (Open, Countdown, Snooze, Dismiss, PathMissing).
    # Cannot rely on DeleteExpiredTaskAfter alone  -  it only fires when the scheduled
    # trigger expires naturally; manually-run tasks are never considered "expired".
    if ($config.task_id) {
        Remove-MotivationTask -TaskId $config.task_id | Out-Null
    }

    # Post-close: open Explorer (REQ-009)
    $effectivePath = if ($script:newExplorerPath) { $script:newExplorerPath } else { $config.explorer_path }
    if ($script:openExplorer -and $effectivePath) {
        try {
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$effectivePath`"" -ErrorAction Stop
        }
        catch {
            [void][System.Windows.MessageBox]::Show(
                "Could not open the folder:`n$effectivePath`n`n$($_.Exception.Message)",
                "Error Opening Folder", "OK", "Error")
        }
    }

    # Log outcome
    $outcome = Get-PopupOutcome -PathMissing $script:pathMissing -OpenExplorer $script:openExplorer -SnoozeCount $script:snoozeCount
    Write-OutcomeLog -TaskId $config.task_id -FolderName $config.folder_name -FolderPath $effectivePath -Outcome $outcome -SnoozeCount $script:snoozeCount
}

# ============================================================
# SECTION 10: Embedded messages + Get-RandomMessage
# (replaces src/data/messages.json)
# ============================================================
$Messages = @(
    [PSCustomObject]@{ Glyph = "[+]"; Title = "Time to Show Up";     Body = "Every great outcome starts with showing up. You already did the hardest part - let's make this session count." }
    [PSCustomObject]@{ Glyph = "[♦]"; Title = "One Step Forward";    Body = "You don't have to see the whole staircase. Just take the next step. This folder is that step." }
    [PSCustomObject]@{ Glyph = "[●]"; Title = "Small Progress Counts"; Body = "Small progress is still progress. Open the folder and do one thing. That's enough." }
    [PSCustomObject]@{ Glyph = "[■]"; Title = "Back in the Zone";    Body = "The hardest part of any work session is starting. You've already decided to start. Now let's go." }
    [PSCustomObject]@{ Glyph = "[▲]"; Title = "Focus Time";          Body = "Set a timer for 25 minutes. Open the folder. Just start. Everything else can wait." }
    [PSCustomObject]@{ Glyph = "[★]"; Title = "You Planned This";    Body = "Yesterday-you knew today-you would need a nudge. Here it is. Don't let yesterday-you down." }
    [PSCustomObject]@{ Glyph = "[◆]"; Title = "Build the Streak";    Body = "Consistency beats intensity every time. Show up today, and tomorrow gets easier." }
    [PSCustomObject]@{ Glyph = "[○]"; Title = "It Matters";          Body = "The work in this folder matters. Not to the whole world maybe - but to you, and to the people counting on you." }
    [PSCustomObject]@{ Glyph = "[□]"; Title = "Just Look";           Body = "You don't have to do everything today. Just open the folder and look. Momentum will follow." }
    [PSCustomObject]@{ Glyph = "[☼]"; Title = "Steady Wins";         Body = "Slow, steady, and deliberate is how great work gets done. Today's session is a brick in something bigger." }
)


# ============================================================
# SECTION 10.5: Text Escaping and Sanitization
# ============================================================

function Escape-XmlText {
    <#
    .SYNOPSIS
    Escapes XML special characters for safe display in WPF TextBlock elements.

    .DESCRIPTION
    Folder names and user-provided text containing XML special
    characters (<, >, &, ", ') must be escaped before assignment to WPF
    TextBlock.Text properties to prevent rendering errors and UI corruption.

    .PARAMETER Text
    The text string to escape. Null or empty strings are handled gracefully.

    .EXAMPLE
    $safe = Escape-XmlText 'Project <Q4> & "Marketing"'
    # Returns: 'Project &lt;Q4&gt; &amp; &quot;Marketing&quot;'
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    # Handle null or empty input
    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    # Use .NET SecurityElement.Escape for standard XML entity escaping
    # This handles: < > & " '
    return [System.Security.SecurityElement]::Escape($Text)
}

function Truncate-TextForDisplay {
    <#
    .SYNOPSIS
    Truncates text to a maximum length with ellipsis for popup display.

    .DESCRIPTION
    Body text must be limited to prevent overflow in WPF popup.
    TextBlock with TextWrapping="Wrap" but no MaxHeight can grow beyond screen
    bounds. This function ensures text stays within visible limits.

    .PARAMETER Text
    The text string to truncate.

    .PARAMETER MaxLength
    Maximum allowed length (default: 150 characters)

    .EXAMPLE
    $safe = Truncate-TextForDisplay -Text $longMessage -MaxLength 150
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,
        [int]$MaxLength = 150
    )

    # Handle null or empty input
    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    # Return as-is if within limit
    if ($Text.Length -le $MaxLength) {
        return $Text
    }

    # Truncate and add ellipsis
    # Reserve 3 characters for "..."
    $truncated = $Text.Substring(0, $MaxLength - 3) + "..."
    return $truncated
}

function Strip-MarkupText {
    <#
    .SYNOPSIS
    Strips markdown and HTML markup from text for plain display.

    .DESCRIPTION
    Title and body text must not contain markdown or HTML
    formatting when displayed in WPF TextBlock. Markup would render as
    literal text (e.g., **bold** instead of bold).

    .PARAMETER Text
    The text string to strip markup from.

    .EXAMPLE
    $plain = Strip-MarkupText '**Bold** and *italic*'
    # Returns: 'Bold and italic'
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    # Handle null or empty input
    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    # Strip markdown and HTML formatting
    # Order matters: do links first, then other formats

    # Markdown links: [text](url) -> text
    $result = $Text -replace '\[([^\]]+)\]\([^\)]+\)', '$1'
    
    # HTML tags: <tag>content</tag> -> content
    $result = $result -replace '<[^>]+>', ''
    
    # Markdown bold/underline: **text** or __text__ -> text
    $result = $result -replace '\*\*([^\*]+)\*\*', '$1'
    $result = $result -replace '__([^_]+)__', '$1'
    
    # Markdown italic: *text* or _text_ -> text
    $result = $result -replace '\*([^\*]+)\*', '$1'
    $result = $result -replace '_([^_]+)_', '$1'
    
    # Markdown strikethrough: ~~text~~ -> text
    $result = $result -replace '~~([^~]+)~~', '$1'

    return $result
}
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

    # Capture exe path for Task Scheduler action and context menu registration.
    # PS2EXE sets $MyInvocation.MyCommand.Path to the compiled .exe path.
    # In tests: set $script:ExePath = "test-override.exe" before calling New-MotivationTask.
    # Fallback to process module path in case ps2exe leaves MyCommand.Path empty.
    $script:ExePath = $MyInvocation.MyCommand.Path
    if (-not $script:ExePath -or $script:ExePath -notmatch '\.exe$') {
        $script:ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }

    try {
        Initialize-AppData
    }
    catch {
        Show-ErrorDialog -Message "Failed to initialize application data: $($_.Exception.Message)" `
                         -Title "Startup Error"
        exit 1
    }

    switch ($Mode) {
        "/popup" {
            Show-PopupWindow
        }
        "/setfolder" {
            if ($FolderPath -and (Test-Path $FolderPath -PathType Container)) {
                $cfg         = Get-Config
                $triggerHour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { $script:ConfigDefaults.default_trigger_hour }
                $triggerTime = (Get-Date).Date.AddDays(1).AddHours($triggerHour)
                $msg         = Get-RandomMessage
                $result      = New-MotivationTask -FolderPath $FolderPath -TriggerTime $triggerTime
                if ($result.Success) {
                    Set-PopupConfig -Glyph $msg.Glyph -Title $msg.Title -Body $msg.Body -ExplorerPath $FolderPath -TaskId $result.TaskId
                    $folderLeaf = Split-Path -Leaf $FolderPath; if (-not $folderLeaf -or $folderLeaf.Length -eq 0) { $folderLeaf = "Unknown Folder" }
                    $schedDisplay = $triggerTime.ToString("dddd 'at' h:mm tt")
                    Show-InfoDialog -Message "'$folderLeaf' scheduled for $schedDisplay." -Title "Folder Scheduled"
                }
                elseif ($result.IsDuplicate) {
                    Show-InfoDialog -Message "'$FolderPath' is already scheduled for tomorrow." -Title "Already Scheduled"
                }
                else {
                    Show-ErrorDialog -Message "Could not schedule '$FolderPath'.`n`n$(Get-SafeErrorMessage $result.Error)" -Title "Schedule Failed"
                }
            }
        }
        default {
            # REQ-010: Ensure context menu is registered every time the exe launches.
            # This self-heals if the user manually deleted the registry key.
            Register-ContextMenu -ExePath $script:ExePath | Out-Null
            Show-MainWindow
        }
    }
}
