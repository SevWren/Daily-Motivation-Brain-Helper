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
# SECTION 2: Debug logging + platform detection
# ============================================================
# Cross-platform temp directory resolution
$script:TempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }

# FIX AG10-005: Use unique log name to prevent symlink attacks and collisions
$uniqueId = [System.Diagnostics.Process]::GetCurrentProcess().Id
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$script:DebugLog = Join-Path $script:TempDir "DailyMotivation_debug_${uniqueId}_${timestamp}.log"

function Write-DLog {
    [CmdletBinding()]
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

# AG7-004: Config caching variables (improves performance, prevents inconsistency)
$script:ConfigCache = $null

# AG7-023: Centralized config defaults (single source of truth)
$script:ConfigDefaults = [PSCustomObject]@{
    default_trigger_hour   = 14
    task_warning_threshold = 5
}
$script:ConfigCacheMTime = $null

# Assembly loading (deferred - only when NOT dot-sourcing with -NoRun)
$script:AssembliesLoaded = $false

function Initialize-WindowsAssemblies {
    # AG12-006: Split WPF and WinForms loads so WinForms can be used as a fallback
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
    catch { Write-DLog "WinForms assembly load failed: $_" "WARN" }

    if (-not $script:WpfLoaded) {
        $errMsg = "Could not load WPF UI components (.NET Framework 4.x required). The application cannot display its interface.`n`nDetails: $wpfErr"
        Write-DLog "WPF assembly load failed: $wpfErr" "ERROR"
        if ($script:FormsLoaded) {
            [System.Windows.Forms.MessageBox]::Show($errMsg, "Daily Motivation Brain Helper",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
        else {
            [Console]::Error.WriteLine($errMsg)
        }
        exit 1
    }

    $script:AssembliesLoaded = $true
    Write-DLog "Assemblies loaded OK (WPF=$($script:WpfLoaded) WinForms=$($script:FormsLoaded))"
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
    [CmdletBinding()]
    param()
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
            try {
                New-Item -ItemType Directory -Path $fallback -Force -ErrorAction Stop | Out-Null
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
    [CmdletBinding()]
    param()
    # AG7-004: Check cache first, reload only if file has changed
    try {
        $mtime = $null
        if (Test-Path $script:ConfigPath) {
            $mtime = (Get-Item $script:ConfigPath -ErrorAction SilentlyContinue).LastWriteTime
        }

        # Return cached config if valid and file hasn't changed
        if ($null -ne $script:ConfigCache -and $null -ne $mtime -and $mtime -eq $script:ConfigCacheMTime) {
            return $script:ConfigCache
        }

        # FIX AG10-017: Validate file size before parsing to prevent DoS via large JSON
        if (Test-Path $script:ConfigPath) {
            $fileSize = (Get-Item $script:ConfigPath).Length
            if ($fileSize -gt 50KB) {
                Write-DLog "Config file exceeds maximum size (50KB): $fileSize bytes - using defaults" "ERROR"
                return [PSCustomObject]@{ default_trigger_hour = 14; task_warning_threshold = 5 }
            }
        }

        # Load from disk
        $cfg = Get-Content -Path "$script:ConfigPath" -Raw -Encoding UTF8 | ConvertFrom-Json

        # AG7-006: Validate config properties — reject out-of-range values to prevent downstream errors
        if ($null -eq $cfg.default_trigger_hour -or
            -not ($cfg.default_trigger_hour -is [int] -or $cfg.default_trigger_hour -is [long] -or $cfg.default_trigger_hour -is [double]) -or
            [int]$cfg.default_trigger_hour -lt 0 -or [int]$cfg.default_trigger_hour -gt 23) {
            Write-DLog "Get-Config: invalid default_trigger_hour '$($cfg.default_trigger_hour)' — resetting to 14" "WARN"
            $cfg.default_trigger_hour = 14
        }
        if ($null -eq $cfg.task_warning_threshold -or
            -not ($cfg.task_warning_threshold -is [int] -or $cfg.task_warning_threshold -is [long] -or $cfg.task_warning_threshold -is [double]) -or
            [int]$cfg.task_warning_threshold -lt 0) {
            Write-DLog "Get-Config: invalid task_warning_threshold '$($cfg.task_warning_threshold)' — resetting to 5" "WARN"
            $cfg.task_warning_threshold = 5
        }

        # Cache the loaded config
        $script:ConfigCache = $cfg
        $script:ConfigCacheMTime = $mtime

        return $cfg
    }
    catch {
        # Clear cache on error
        $script:ConfigCache = $null
        $script:ConfigCacheMTime = $null
        return [PSCustomObject]@{ default_trigger_hour = 14; task_warning_threshold = 5 }
    }
}

function Save-Config {
    # AG3-016 / AG7-002 / AG7-010: Atomic write — write to .tmp then rename to prevent
    # partial-write corruption if the process is killed mid-write.
    # AG7-004: Invalidate cache after save to force reload on next Get-Config.
    [CmdletBinding()]
    param([PSCustomObject]$Config)
    $tempPath = $script:ConfigPath + ".tmp"
    try {
        $Config | ConvertTo-Json | Set-Content -Path $tempPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -Path $tempPath -Destination $script:ConfigPath -Force -ErrorAction Stop

        # Invalidate cache
        $script:ConfigCache = $null
        $script:ConfigCacheMTime = $null
    }
    catch {
        if (Test-Path $tempPath) { Remove-Item $tempPath -ErrorAction SilentlyContinue }
        throw
    }
}

function Get-PopupConfig {
    [CmdletBinding()]
    param()
    # AG4-010: Check if file exists before attempting to read
    # This distinguishes between "file not found" (expected) vs "file corrupted" (error)
    if (-not (Test-Path -Path "$script:PopupCfgPath" -PathType Leaf)) {
        Write-DLog "Get-PopupConfig: file does not exist — returning defaults" "INFO"
        return [PSCustomObject]@{
            glyph         = "[+]"
            title         = ""
            body          = ""
            explorer_path = ""
            folder_name   = ""
            task_id       = ""
        }
    }

    # AG7-015: Return a default PSCustomObject on error instead of $null to prevent
    # null-reference crashes in callers that access properties without null checks.
    try {
        # FIX AG10-017: Validate file size before parsing
        if (Test-Path $script:PopupCfgPath) {
            $fileSize = (Get-Item $script:PopupCfgPath).Length
            if ($fileSize -gt 50KB) {
                Write-DLog "Popup config file exceeds maximum size (50KB): $fileSize bytes - using defaults" "ERROR"
                return [PSCustomObject]@{
                    glyph = "[+]"; title = ""; body = ""
                    explorer_path = ""; folder_name = ""; task_id = ""
                }
            }
        }
        return Get-Content -Path "$script:PopupCfgPath" -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-DLog "Get-PopupConfig: failed to parse config (file exists but corrupted) — returning defaults: $_" "ERROR"
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
    # AG3-008 / AG3-016: Use named mutex + atomic write (temp file + rename) to prevent
    # file corruption when /setfolder and /popup modes run concurrently.
    [CmdletBinding()]
    param(
        [string]$Glyph,
        [string]$Title,
        [string]$Body,
        [string]$ExplorerPath,
        [string]$TaskId
    )
    $tempPath    = $script:PopupCfgPath + ".tmp"
    $cfgMutex    = $null
    $cfgAcquired = $false
    try {
        $cfgMutex    = [System.Threading.Mutex]::new($false, "Global\DailyMotivationPopupConfigLock")
        $cfgAcquired = $cfgMutex.WaitOne(2000)
        if (-not $cfgAcquired) {
            Write-DLog "Set-PopupConfig: could not acquire config mutex within 2s — proceeding without lock" "WARN"
        }
        [ordered]@{
            glyph         = $Glyph
            title         = $Title
            body          = $Body
            explorer_path = $ExplorerPath
            folder_name   = if ($ExplorerPath) { $leaf = Split-Path -Leaf $ExplorerPath; if ($leaf) { $leaf } else { "Unknown Folder" } } else { "Unknown Folder" }
            task_id       = $TaskId
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
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # FIX AG10-016: Hash folder path instead of storing plaintext (HIGH severity)
    # Prevents information disclosure in persistent log files
    $pathHash = if ($FolderPath -and $FolderPath.Length -gt 0) {
        $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($FolderPath))
        ($hashBytes | ForEach-Object { $_.ToString("X2") }) -join ''
    } else {
        "NO_PATH"
    }

    # Store only hash in log, not full path
    $entry = "[$ts] | $TaskId | $FolderName | HASH:$pathHash | $Outcome | $SnoozeCount"
    Add-Content -Path "$script:LogPath" -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue

    # FIX AG10-016: Implement log rotation to prevent indefinite accumulation
    if (Test-Path $script:LogPath) {
        try {
            $logFile = Get-Item $script:LogPath
            if ($logFile.Length -gt 1MB) {
                # Rotate log if over 1MB
                $archiveName = "$($script:LogPath).archive_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item -Path $script:LogPath -Destination $archiveName -Force -ErrorAction Stop
                Clear-Content -Path $script:LogPath -ErrorAction Stop
                Write-DLog "Log rotated to $archiveName (size was $($logFile.Length) bytes)"

                # Delete archives older than 30 days
                $archivePattern = "$($script:LogPath).archive_*"
                Get-ChildItem -Path (Split-Path $script:LogPath -Parent) -Filter "popup_log.txt.archive_*" -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
                    ForEach-Object {
                        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                        Write-DLog "Deleted old log archive: $($_.Name)"
                    }
            }
        }
        catch {
            Write-DLog "Log rotation failed: $_" "WARN"
        }
    }
}

function Get-SafeErrorMessage {
    # FIX AG10-013: Sanitize error messages to prevent path exposure
    param([Parameter(Mandatory)][string]$ErrorMessage)

    # Remove file paths (Windows and UNC)
    $safe = $ErrorMessage -replace '[A-Z]:\\[^\s"]*', '[PATH]'
    $safe = $safe -replace '\\\\[^\s"]*', '[UNC_PATH]'

    # Remove sensitive keywords with context
    $safe = $safe -replace '(password|secret|token|key|credential)[^\s]*', '[REDACTED]'

    # Remove $env: variable references that might contain paths
    $safe = $safe -replace '\$env:[A-Z_]+\\[^\s"]*', '[ENV_PATH]'

    return $safe
}

function Show-ErrorDialog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = "Daily Motivation Brain Helper"
    )

    # FIX AG10-013: Sanitize error message before displaying
    $safeMessage = Get-SafeErrorMessage -ErrorMessage $Message

    try {
        [System.Windows.MessageBox]::Show($safeMessage, $Title, "OK", "Error") | Out-Null
    }
    catch {
        try {
            [System.Windows.Forms.MessageBox]::Show($safeMessage, $Title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
        catch { [Console]::Error.WriteLine("ERROR [$Title]: $safeMessage") }
    }
}

function Show-InfoDialog {
    # AG6-019: Centralised informational dialog with WPF→WinForms→Console fallback.
    # Use this instead of direct [System.Windows.MessageBox] calls in code paths
    # that may run before/without WPF assemblies (e.g. /setfolder on non-WPF systems).
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = "Daily Motivation Brain Helper"
    )
    try {
        [System.Windows.MessageBox]::Show($Message, $Title, "OK", "Information") | Out-Null
    }
    catch {
        try {
            [System.Windows.Forms.MessageBox]::Show($Message, $Title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
        catch { [Console]::Out.WriteLine("INFO [$Title]: $Message") }
    }
}

# ============================================================
# SECTION 4: Task Scheduler functions
# ============================================================

function Get-TasksJson {
    # AG5-022: Valid task status values
    $script:ValidTaskStatuses = @('PENDING', 'DELETED', 'COMPLETED', 'FAILED')

    $path = $script:TasksPath
    if (-not (Test-Path $path)) { return @() }
    try {
        $result = Get-Content -Path "$path" -Raw -Encoding UTF8 | ConvertFrom-Json
        # FIX-003: Ensure consistent array handling for empty JSON arrays
        if ($null -eq $result) { return @() }

        # AG5-022: Validate and normalize task status values
        $tasks = @($result)
        foreach ($task in $tasks) {
            if ($null -ne $task -and $task.PSObject.Properties['status']) {
                if ($task.status -notin $script:ValidTaskStatuses) {
                    Write-DLog "Invalid task status '$($task.status)' for task $($task.task_id) - setting to UNKNOWN" "WARN"
                    $task.status = 'UNKNOWN'
                }
            }
        }

        return $tasks
    }
    catch { return @() }
}

function Save-TasksJson {
    # AG3-009 / AG18-001: Atomic write — write to .tmp then rename to prevent partial-write
    # corruption if the process is killed mid-write. FIX-003 null/empty handling preserved.
    param([object[]]$Tasks)
    $path     = $script:TasksPath
    $tempPath = $path + ".tmp"
    try {
        if ($null -eq $Tasks -or $Tasks.Count -eq 0) {
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
}

function New-MotivationTask {
    <#
    .SYNOPSIS
    Creates a Windows Scheduled Task and records it in tasks.json.
    The task action calls this same exe with /popup argument (-STA baked in by build).
    #>
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FolderPath,
        [Parameter(Mandatory)][datetime]$TriggerTime,
        [switch]$Force
    )

    # FIX AG10-003: Validate folder path before storage in Task Scheduler/Registry
    # Prevent path traversal, command injection, and malicious UNC paths
    if ($FolderPath -match '\.\.' -or $FolderPath -match '\.\.\\' -or $FolderPath -match '\.\./') {
        Write-DLog "Path validation failed: path traversal detected in '$FolderPath'" "ERROR"
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid path: path traversal sequences (..) are not allowed" }
    }

    if ($FolderPath -match '[<>|*?]') {
        Write-DLog "Path validation failed: invalid characters in '$FolderPath'" "ERROR"
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid path: contains invalid characters (<>|*?)" }
    }

    # Validate path can be normalized
    try {
        $normalized = [System.IO.Path]::GetFullPath($FolderPath)
        Write-DLog "Path normalized successfully: $FolderPath -> $normalized"
    }
    catch {
        Write-DLog "Path validation failed: cannot normalize path '$FolderPath' - $($_.Exception.Message)" "ERROR"
        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid path format: $_" }
    }

    # Log warning for UNC paths (security consideration)
    if ($FolderPath -match '^\\\\') {
        Write-DLog "UNC path scheduling: $FolderPath - user responsibility for security" "WARN"
    }

    # Sync OS task states before duplicate check so stale ghost entries (tasks that were
    # written to tasks.json but never actually registered in Task Scheduler due to a
    # non-terminating error) are marked DELETED and don't block rescheduling.
    if (-not $script:Platform) { Sync-TaskStatuses }

    # Duplicate check (B-16) - case-insensitive path, same date (GAP-006)
    $normalizedInput = [System.IO.Path]::GetFullPath($FolderPath).ToLowerInvariant()
    if (-not $Force) {
        $existing = Get-MotivationTasks | Where-Object {
            # Check property exists first (guard against malformed/legacy task objects)
            ($null -ne $_ -and $_.PSObject.Properties['folder_path']) -and
            $_.folder_path -and $_.folder_path.Length -gt 0 -and
            [System.IO.Path]::GetFullPath($_.folder_path).ToLowerInvariant() -eq $normalizedInput -and
            (try { ([datetime]$_.scheduled_time).Date -eq $TriggerTime.Date } catch { $false }) -and
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
        # FIX AG10-022: Generate task ID with exponential backoff collision retry
        $maxRetries = 10
        $backoffMs = 50
        $taskId = $null
        $taskName = $null
        $attempts = 0

        for ($attempts = 0; $attempts -lt $maxRetries; $attempts++) {
            $taskId = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
            $taskName = "DailyMotivation_$taskId"

            try {
                $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
                # Task exists, retry with exponential backoff
                Write-DLog "Task name collision on attempt $($attempts + 1): $taskName" "WARN"
                Start-Sleep -Milliseconds $backoffMs
                $backoffMs = [Math]::Min($backoffMs * 2, 5000)  # Cap at 5 seconds
            }
            catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
                # Task doesn't exist - collision resolved
                Write-DLog "Unique task name generated: $taskName (attempt $($attempts + 1))"
                break
            }
            catch {
                # Other error - log and retry
                Write-DLog "Task name check error: $_" "WARN"
                Start-Sleep -Milliseconds $backoffMs
                $backoffMs = [Math]::Min($backoffMs * 2, 5000)
            }
        }

        # Check if we exhausted retries
        if ($attempts -ge $maxRetries) {
            Write-DLog "Could not generate unique task name after $maxRetries attempts" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Could not generate unique task ID after $maxRetries attempts (collision retry exhausted)" }
        }

        # Task Scheduler action: call this exe directly with /popup
        # $script:ExePath is set at entry point to $MyInvocation.MyCommand.Path
        # Tests override $script:ExePath before calling this function
        $exeForTask = if ($script:ExePath) { $script:ExePath } else { "DailyMotivation.exe" }

        # AG5-005: Validate executable path before creating task action
        if ([string]::IsNullOrWhiteSpace($exeForTask)) {
            Write-DLog "Task action executable path is empty or null" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid executable path: path cannot be empty" }
        }
        if ($exeForTask -notmatch '\.exe$') {
            Write-DLog "Task action path must be an .exe file: $exeForTask" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid executable path: must be a .exe file, got: $exeForTask" }
        }
        # AG5-023: Verify path is absolute (not relative)
        if (-not [System.IO.Path]::IsPathRooted($exeForTask)) {
            Write-DLog "Task action path must be absolute: $exeForTask" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid executable path: must be absolute path, got: $exeForTask" }
        }

        try {
            $action = New-ScheduledTaskAction -Execute $exeForTask -Argument "/popup"
            if ($null -eq $action) {
                throw [System.Exception]::new("New-ScheduledTaskAction returned null")
            }
        }
        catch {
            Write-DLog "Failed to create scheduled task action: $($_.Exception.Message)" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $_.Exception.Message }
        }

        # AG5-007: Validate trigger time before creating trigger
        if ($null -eq $TriggerTime -or $TriggerTime -isnot [datetime]) {
            Write-DLog "TriggerTime must be a valid DateTime object" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid trigger time: must be a DateTime object" }
        }
        if ($TriggerTime -le (Get-Date)) {
            Write-DLog "TriggerTime must be in the future: $TriggerTime" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid trigger time: must be in the future, got: $TriggerTime" }
        }
        if ($TriggerTime -gt (Get-Date).AddYears(4)) {
            Write-DLog "TriggerTime is too far in the future: $TriggerTime" "ERROR"
            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid trigger time: cannot be more than 4 years in the future" }
        }

        $trigger  = New-ScheduledTaskTrigger -Once -At $TriggerTime
        # EndBoundary is required by Task Scheduler XML schema when DeleteExpiredTaskAfter is set.
        # Without it, Register-ScheduledTask emits a non-terminating "(49,4):EndBoundary:" XML error
        # that ps2exe surfaces as a dialog. Set it to trigger time + execution limit + buffer.
        # AG5-012: Increased ExecutionTimeLimit from 10 to 30 minutes to allow adequate time
        # for user interaction with popup window and folder opening
        $executionTimeLimit = New-TimeSpan -Minutes 30
        # AG5-014: EndBoundary should account for the execution time limit
        $trigger.EndBoundary = $TriggerTime.Add($executionTimeLimit).AddMinutes(1).ToString('yyyy-MM-ddTHH:mm:ss')
        Write-DLog "Trigger EndBoundary set to $($trigger.EndBoundary)"
        $settings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -ExecutionTimeLimit  $executionTimeLimit `
            -MultipleInstances   IgnoreNew `
            -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 30)

        # GAP-010: network path detection for RunLevel assignment
        $isUncPath     = $FolderPath -match '^\\\\[^\\]'
        $isMappedDrive = $false
        if ($FolderPath -and $FolderPath.Length -ge 2 -and $FolderPath[1] -eq ':') {
            $driveInfo = $null
            try {
                $driveInfo     = [System.IO.DriveInfo]::new($FolderPath.Substring(0, 1))
                $isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
            }
            catch { $isMappedDrive = $false }
            finally {
                if ($driveInfo) { $driveInfo.Dispose() }  # AG14-007: Dispose DriveInfo
            }
        }
        $isNetworkPath = $isUncPath -or $isMappedDrive

        # FIX AG10-004: CRITICAL - Never use 'Highest' RunLevel for security
        # Network paths do NOT require admin elevation. Using 'Limited' for all tasks
        # prevents privilege escalation attacks where attacker controls network path.
        $runLevel = 'Limited'

        # Log warning for network paths (AG10-004)
        if ($isNetworkPath) {
            Write-DLog "SECURITY: Network path detected: $FolderPath - using Limited RunLevel to prevent privilege escalation" "WARN"
        }

        # AG5-010: Use S4U (Service for User) LogonType instead of Interactive
        # so tasks can fire even when user is not actively logged in (e.g., workstation locked)
        $principal = New-ScheduledTaskPrincipal `
            -UserId    $env:USERNAME `
            -LogonType S4U   `
            -RunLevel  $runLevel

        # FIX AG10-001 & AG10-010: Sanitize Description - use hash instead of raw path
        # Prevents information leakage via Task Scheduler description field
        $pathHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($FolderPath)) |
            ForEach-Object { $_.ToString("X2") } | Join-String -Separator """"
        $safeDescription = "Daily Motivation Brain Helper - Task $($pathHash.Substring(0, 16))"

        try {
            # AG5-001: Capture return value to verify task was actually created
            $registeredTask = Register-ScheduledTask `
                -TaskName    $taskName  `
                -Action      $action    `
                -Trigger     $trigger   `
                -Settings    $settings  `
                -Principal   $principal `
                -Description $safeDescription `
                -Force -ErrorAction Stop

            # AG5-001: Verify the task was actually created and has correct properties
            if ($null -eq $registeredTask) {
                Write-DLog "Register-ScheduledTask returned null - task may not have been created" "ERROR"
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Task registration returned null" }
            }

            # AG5-001: Verify task name matches what we expected
            if ($registeredTask.TaskName -ne $taskName) {
                Write-DLog "Registered task name '$($registeredTask.TaskName)' does not match expected '$taskName'" "ERROR"
                # Attempt cleanup of incorrectly named task
                Unregister-ScheduledTask -TaskName $registeredTask.TaskName -Confirm:$false -ErrorAction SilentlyContinue
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Task name mismatch after registration" }
            }

            # AG5-001: Verify task state is Ready (not Disabled)
            if ($registeredTask.State -ne 'Ready') {
                Write-DLog "Task registered but state is '$($registeredTask.State)' instead of 'Ready'" "WARN"
            }

            Write-DLog "Register-ScheduledTask succeeded: $taskName (State: $($registeredTask.State))"

            # AG5-002: Verify task trigger is valid and will actually fire
            try {
                $verifyTask = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
                $trigger = $verifyTask.Triggers | Select-Object -First 1

                if ($null -eq $trigger) {
                    Write-DLog "Task registered but has no triggers" "ERROR"
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                    return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Task has no triggers" }
                }

                # Verify trigger start boundary is parseable and in the future
                if ($trigger.StartBoundary) {
                    try {
                        $triggerStart = [datetime]::Parse($trigger.StartBoundary)
                        if ($triggerStart -le (Get-Date)) {
                            Write-DLog "Task trigger time is in the past: $triggerStart" "ERROR"
                            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                            return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Trigger time is in the past" }
                        }
                        Write-DLog "Task trigger verified: will fire at $triggerStart (Local time)"
                    }
                    catch {
                        Write-DLog "Failed to parse trigger StartBoundary: $($trigger.StartBoundary)" "ERROR"
                        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                        return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Invalid trigger time format" }
                    }
                }

                # Verify task state is Ready
                if ($verifyTask.State -ne 'Ready') {
                    Write-DLog "Task state is '$($verifyTask.State)' - task may not fire" "WARN"
                }
            }
            catch {
                Write-DLog "Failed to verify task after registration: $($_.Exception.Message)" "ERROR"
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Task verification failed: $($_.Exception.Message)" }
            }
        }
        catch {
            # AG5-021: Provide specific error handling based on exception type
            $errorMsg = $_.Exception.Message
            if ($errorMsg -match 'already exists') {
                Write-DLog "Task collision detected (shouldn't happen after GUID retry): $errorMsg" "ERROR"
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Task name collision: $errorMsg" }
            }
            elseif ($errorMsg -match 'Access Denied|not have permission') {
                Write-DLog "Permission denied - may need admin rights: $errorMsg" "ERROR"
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = "Access denied: $errorMsg" }
            }
            else {
                Write-DLog "Register-ScheduledTask failed: $errorMsg" "ERROR"
                return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $errorMsg }
            }
        }
    }

    # Persist to tasks.json - atomic: rollback OS task if JSON save fails
    $tasks   = @(Get-TasksJson)
    $newTask = [PSCustomObject]@{
        task_id        = $taskId
        task_name      = $taskName
        folder_path    = $FolderPath
        folder_name    = if ($FolderPath) { $leaf = Split-Path -Leaf $FolderPath; if ($leaf) { $leaf } else { "Unknown Folder" } } else { "Unknown Folder" }
        scheduled_time = $TriggerTime.ToString("yyyy-MM-ddTHH:mm:ss")
        created_at     = (Get-Date -Format "o")
        status         = "PENDING"
        snooze_count   = 0
    }
    $tasks = $tasks + $newTask
    try {
        Save-TasksJson $tasks
    }
    catch {
        # AG5-015 & AG5-020: Rollback with verification - unregister the OS task to keep Task Scheduler and tasks.json in sync
        if (-not $script:Platform) {
            try {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
                Write-DLog "Rollback: Successfully unregistered task $taskName after JSON save failure" "WARN"

                # AG5-015: Verify task was actually removed to prevent race conditions
                $attempts = 0
                $maxAttempts = 3
                $taskStillExists = $true

                while ($taskStillExists -and $attempts -lt $maxAttempts) {
                    Start-Sleep -Milliseconds (100 * ($attempts + 1))
                    try {
                        Get-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
                        $taskStillExists = $true
                        $attempts++
                        Write-DLog "Rollback: Task still exists after unregister, attempt $attempts/$maxAttempts" "WARN"
                    }
                    catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
                        # Task not found - this is what we want
                        $taskStillExists = $false
                        Write-DLog "Rollback: Verified task $taskName was removed" "INFO"
                    }
                    catch {
                        # Other error - assume task still exists
                        $attempts++
                    }
                }

                if ($taskStillExists) {
                    Write-DLog "Rollback: WARNING - Task may still exist after unregister attempts" "ERROR"
                }
            }
            catch {
                # AG5-020: Log and report unregister failure - creates inconsistent state
                Write-DLog "Rollback FAILED: Could not unregister task $taskName - INCONSISTENT STATE: $($_.Exception.Message)" "ERROR"
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

    # Direction 1: JSON → OS Scheduler — mark tasks DELETED if OS task is gone (ERR-008)
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

    # Direction 2: OS Scheduler → JSON — recover orphaned OS tasks missing from tasks.json (FIX-SYNC-002)
    # This handles the case where Register-ScheduledTask succeeded but Save-TasksJson failed,
    # leaving an OS task with no corresponding record in tasks.json.
    $knownNames = @($tasks | Where-Object { $null -ne $_ -and $_.PSObject.Properties['task_name'] } | ForEach-Object { $_.task_name })
    try {
        $osTasks = @(Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue)
    }
    catch { $osTasks = @() }

    foreach ($osTask in $osTasks) {
        if ($knownNames -contains $osTask.TaskName) { continue }

        # Parse folder_path from Description: "Daily Motivation Brain Helper - {FolderPath}"
        $folderPath = ''
        if ($osTask.Description -match '^Daily Motivation Brain Helper - (.+)$') {
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
        Write-DLog "Sync-TaskStatuses: recovered orphaned OS task '$($osTask.TaskName)' into tasks.json"
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

    # AG5-017: Call Sync-TaskStatuses before removal to ensure task state is current
    # This prevents attempting to unregister tasks that were already deleted manually
    if (-not $script:Platform) {
        Sync-TaskStatuses
    }

    $tasks  = Get-TasksJson
    $target = $tasks | Where-Object { $_.task_id -eq $TaskId }
    if (-not $target) { return $false }

    # AG5-017: If task is already marked DELETED, skip OS unregister
    if ($target.status -eq 'DELETED') {
        Write-DLog "Remove-MotivationTask: Task $TaskId already DELETED in OS, removing from JSON only" "INFO"
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
        # AG5-020: Verify unregister succeeded and handle failures properly
        try {
            Unregister-ScheduledTask -TaskName $target.task_name -Confirm:$false -ErrorAction Stop
            # Verify task was actually removed
            $stillExists = Get-ScheduledTask -TaskName $target.task_name -ErrorAction SilentlyContinue
            if ($stillExists) {
                throw "Task still exists after unregister attempt"
            }
        }
        catch {
            Write-DLog "Remove-MotivationTask: Failed to unregister '$($target.task_name)': $_" "ERROR"
            # AG5-020: Don't remove from tasks.json if unregister failed (maintain consistency)
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
    $pending = @($tasks | Where-Object { $_.status -eq "PENDING" })
    # SS-F-01: format ISO timestamp to human-readable; SS-F-06: humanize hyphenated folder name
    # Wrap in @() so a single task doesn't collapse to a bare PSCustomObject (IEnumerable required)
    $displayTasks = @($pending | ForEach-Object {
        $t = $_
        $displayTime = try {
            ([datetime]$t.scheduled_time).ToString("ddd, MMM d 'at' h:mm tt")
        } catch { $t.scheduled_time }
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
    # AG6-007: Ensure ItemsSource is always an array (even if empty) to prevent WPF property iteration
    if (-not $displayTasks) { $displayTasks = @() }
    $TaskListControl.ItemsSource          = $displayTasks
    $NoTasksLabelControl.Visibility       = if ($pending.Count -eq 0) { "Visible" } else { "Collapsed" }
}

function Get-HistoryData {
    if (-not (Test-Path -Path "$script:LogPath" -PathType Leaf)) { return @() }
    $lines = @(Get-Content -Path "$script:LogPath" -Encoding UTF8 |
        Where-Object { $_ -match '^\[' } |
        Select-Object -Last 30)
    if (-not $lines -or $lines.Count -eq 0) { return @() }

    $items = foreach ($line in $lines) {
        $parts = $line -split '\s*\|\s*'
        if ($parts.Count -ge 5) {
            $outcome        = $parts[4].Trim()
            $outcomeDisplay = if ($outcome -eq "PathMissing") { "Path Missing" } else { $outcome }
            [PSCustomObject]@{
                Timestamp      = $parts[0].Trim('[', ']')
                FolderName     = $parts[2].Trim()
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
    # AG6-016: Validate timer interval to prevent CPU spike from zero/negative interval
    $interval = [System.TimeSpan]::FromSeconds(1)
    if ($interval.TotalMilliseconds -le 0) {
        Write-DLog "FATAL: Undo timer interval must be positive (got $($interval.TotalMilliseconds)ms)" "ERROR"
        $UndoBannerControl.Visibility = "Collapsed"
        throw "Invalid timer interval: $($interval.TotalMilliseconds)ms"
    }
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
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FolderPath,
        [Parameter(Mandatory)][datetime]$TriggerTime,
        [switch]$Force
    )

    # Detect network paths (UNC or mapped drives)
    $isUncPath = $FolderPath -match '^\\\\[^\\]'
    $isMappedDrive = $false
    if ($FolderPath -and $FolderPath.Length -ge 2 -and $FolderPath[1] -eq ':') {
        $driveInfo = $null
        try {
            $driveInfo = [System.IO.DriveInfo]::new($FolderPath.Substring(0, 1))
            $isMappedDrive = $driveInfo.DriveType -eq [System.IO.DriveType]::Network
        }
        catch { $isMappedDrive = $false }
        finally {
            if ($driveInfo) { $driveInfo.Dispose() }  # AG14-007: Dispose DriveInfo
        }
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
    # Guard: only register when invoked from a compiled .exe, not the source .ps1.
    # If the script is run directly (pwsh .\DailyMotivation.ps1), $MyInvocation.MyCommand.Path
    # is the .ps1 path. Storing that in the registry causes "This app can't run on your PC"
    # when Explorer invokes the verb, because Windows tries to execute a text file as a PE.
    if (-not $ExePath -or $ExePath -notmatch '\.exe$') {
        Write-DLog "Register-ContextMenu: skipped — ExePath is not a compiled exe ('$ExePath'). Run the compiled DailyMotivation.exe to register the context menu." "WARN"
        return
    }
    $verbKey = "HKCU:\Software\Classes\Directory\shell\ScheduleMotivation"
    $cmdKey  = "$verbKey\command"
    try {
        New-Item -Path $verbKey -Force | Out-Null
        Set-ItemProperty -Path $verbKey -Name "(Default)" -Value "Set as tomorrow's folder (Daily Motivation)"
        New-Item -Path $cmdKey -Force | Out-Null
        $escapedPath = $ExePath -replace '([\\"`])', '`$1'
        Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value "`"$escapedPath`" /setfolder `"%1`""
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
        <!-- Dark-aware RadioButton — replaces system BulletChrome (SS-D-01) -->
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

            <!-- Header accent bar — edge-to-edge, no top dead zone (SS-A-02, SS-B-02) -->
            <Border Background="#00BCD4" Height="3" Margin="-28,0,-28,16"/>

            <!-- Context label — replaces duplicated OS title (SS-A-03) -->
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

            <!-- Drop Zone + Select Folder (SS-C-03: visible border; SS-H-02: left-aligned) -->
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
                            ToolTip="Choose the folder you want to open at the scheduled time"/>
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
                                 ToolTip="Schedule this folder to open today at 2:00 PM"/>
                    <RadioButton x:Name="TomorrowRadio"
                                 Content="Tomorrow at 2:00 PM"
                                 FontSize="12" Foreground="#E8E8F4"
                                 IsChecked="True"
                                 ToolTip="Schedule this folder to open tomorrow at 2:00 PM"/>
                </StackPanel>
            </StackPanel>

            <!-- Schedule Button (SS-E-01: padding fixed; SS-E-02: stretch) -->
            <Button x:Name="ScheduleBtn"
                    Content="Schedule"
                    Style="{StaticResource PrimaryBtn}"
                    IsEnabled="False"
                    HorizontalAlignment="Stretch"
                    Padding="20,10"
                    ToolTip="Create a reminder to open this folder at the scheduled time"/>

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
                            ToolTip="Cancel the schedule you just created"/>
                </Grid>
            </Border>

            <!-- Divider (SS-F-08: raised to 3:1 contrast) -->
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

            <!-- Scheduled Tasks (SS-F-07: header given more weight than body labels) -->
            <TextBlock Text="Scheduled Tasks"
                       FontSize="13" FontWeight="Bold" Foreground="#C8C8E8" Margin="0,0,0,10"/>
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
                                <!-- PENDING badge (SS-F-03: cyan → neutral; SS-I-02: no cyan overload) -->
                                <Border Grid.Column="1"
                                        Background="#1F1F30" CornerRadius="4" Padding="6,2" Margin="8,0">
                                    <TextBlock Text="{Binding status}" FontSize="10" Foreground="#7A7A9A"/>
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
            </ScrollViewer>
            <TextBlock x:Name="NoTasksLabel"
                       Text="No tasks scheduled."
                       FontSize="11" Foreground="#6A6A8A"
                       Margin="0,8,0,0" Visibility="Collapsed"/>

            <!-- History Toggle (SS-G-01: no emoji hack; SS-G-03: stretch not orphaned) -->
            <Button x:Name="HistoryToggleBtn"
                    Content="View History"
                    Style="{StaticResource SecondaryBtn}"
                    HorizontalAlignment="Stretch"
                    Margin="0,16,0,0" Padding="12,8"
                    ToolTip="See a log of your past folder openings"/>

            <!-- History panel -->
            <Border x:Name="HistoryPanel"
                    Background="#0A0A14" BorderBrush="#2A2A42" BorderThickness="1"
                    CornerRadius="7" Padding="14,12" Margin="0,8,0,8"
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
    # AG6-001: Guard — verify WPF assemblies are loaded before attempting any UI operations
    if (-not $script:AssembliesLoaded) {
        Write-DLog "Show-MainWindow: WPF assemblies not loaded — cannot display UI" "ERROR"
        [Console]::Error.WriteLine("UI cannot display: .NET Framework WPF assemblies not available.")
        return
    }
    # AG6-003: Warn if not running on an STA thread (required for WPF ShowDialog)
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA) {
        Write-DLog "Show-MainWindow: thread is not STA ($([System.Threading.Thread]::CurrentThread.ApartmentState)) — WPF dialogs may fail" "WARN"
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
    # AG6-002: Wrap XamlReader.Load() in try-catch — it throws on malformed XAML
    try {
        $window = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        Write-DLog "FATAL: Main XAML build failed - $_" "ERROR"
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

    # AG6-014: Validate FindName() returns non-null to prevent "member on null" errors
    function Find {
        param($n)
        $control = $window.FindName($n)
        if ($null -eq $control) {
            Write-DLog "FATAL: XAML element not found: $n" "ERROR"
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
        # Re-evaluate Today radio visibility at schedule time (A10-ISSUE-05)
        if ($todayRadio.Visibility -eq "Visible" -and (Get-Date).Hour -ge $hour) {
            $todayRadio.Visibility  = "Collapsed"
            $todayRadio.IsChecked   = $false
            $tomorrowRadio.IsChecked = $true
        }
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

    # Show Today radio only before trigger hour; set dynamic labels from config (A3-BUG-02)
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
                if ($dialog) { $dialog.Dispose() }  # AG14-001: Dispose FolderBrowserDialog
            }
        })

    # SS-C-05: drag-over visual feedback
    # AG14-006: Reuse single BrushConverter instance to prevent WPF resource fragmentation
    $converter = [System.Windows.Media.BrushConverter]::new()
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
                $removedId = $script:lastTaskId
                Stop-UndoTimer -UndoBannerControl $undoBanner
                Remove-MotivationTask -TaskId $removedId
                $script:lastTaskId       = $null
                $script:undoScheduledFor = $null
                Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
                $scheduleBtn.IsEnabled = ($script:selectedPath -ne "")
                # Provide confirmation feedback that undo succeeded (A10-ISSUE-06)
                $undoLabel.Text        = "Task removed."
                $undoBanner.Visibility = "Visible"
                $undoFeedbackTimer = [System.Windows.Threading.DispatcherTimer]::new()
                $undoFeedbackTimer.Interval = [System.TimeSpan]::FromMilliseconds(1500)
                $undoFeedbackTimer.Add_Tick({
                    $undoFeedbackTimer.Stop()
                    $undoBanner.Visibility = "Collapsed"
                })
                $undoFeedbackTimer.Start()
            }
        })

    $taskList.Add_PreviewMouseLeftButtonUp({
            param($s, $e)
            # Block deletions while an undo grace period is active (A5-BUG-009)
            if ($script:lastTaskId) {
                [System.Windows.MessageBox]::Show(
                    "Please wait until the undo period completes before deleting tasks.",
                    "Undo in Progress", "OK", "Information") | Out-Null
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

    $historyToggleBtn.Add_Click({
            if ($historyPanel.Visibility -eq "Visible") {
                $historyPanel.Visibility  = "Collapsed"
                $historyToggleBtn.Content = "View History"   # matches new Content attribute
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
                if (Test-Path -Path "$script:LogPath" -PathType Leaf) { Clear-Content $script:LogPath }
                Update-HistoryUI -HistoryListControl $historyList
            }
        })

    # AG3-001, AG3-015, AG3-017: Add window cleanup handler
    $window.Add_Closed({
        try {
            # Stop and dispose undo timer if still running
            if ($script:undoTimer) {
                $script:undoTimer.Stop()
                try { $script:undoTimer.Dispose() } catch {}
                $script:undoTimer = $null
            }
            # AG3-015: Dispose brush objects to prevent memory leak
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
        catch { Write-DLog "Window cleanup error: $_" "WARN" }
    })

    # AG6-010: Stop timers when window closes to prevent memory leaks
    # AG6-011: Cleanup event handlers (best effort - WPF handles most automatically)
    $window.Add_Closing({
        if ($script:undoTimer) {
            $script:undoTimer.Stop()
            $script:undoTimer = $null
        }
        if ($script:undoFeedbackTimer) {
            $script:undoFeedbackTimer.Stop()
            $script:undoFeedbackTimer = $null
        }
        Write-DLog "MainWindow closing - timers stopped"
    })

    # Reconcile task statuses with Windows Task Scheduler before displaying
    Sync-TaskStatuses
    Update-TaskListUI -TaskListControl $taskList -NoTasksLabelControl $noTasksLabel
    # AG6-004: Wrap ShowDialog in try-finally to ensure window disposal
    try {
        $window.ShowDialog() | Out-Null
    }
    finally {
        if ($window) {
            $window.Close()
            Write-DLog "MainWindow closed"
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
                    <TextBlock x:Name="TitleText" FontSize="19" FontWeight="Bold"
                               Foreground="#E8E8F4" VerticalAlignment="Center"
                               TextWrapping="Wrap" MaxWidth="380"/>
                </StackPanel>
                <TextBlock x:Name="BodyText" FontSize="14" Foreground="#8888A8"
                           TextWrapping="Wrap" LineHeight="23" Margin="0,0,0,6"/>
                <!-- B-12: folder name subtitle -->
                <TextBlock x:Name="FolderNameText" FontSize="12" Foreground="#8888A8"
                           TextWrapping="Wrap" Margin="0,0,0,22" Visibility="Collapsed"/>
                <Border Background="#303050" Height="1" Margin="0,0,0,18"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,22">
                    <TextBlock Text="Auto-opening in " FontSize="12" Foreground="#8888A8" VerticalAlignment="Center"/>
                    <TextBlock x:Name="CountdownText" Text="20" FontSize="12" FontWeight="Bold"
                               Foreground="#00BCD4" VerticalAlignment="Center"/>
                    <TextBlock Text="s" FontSize="12" Foreground="#8888A8" VerticalAlignment="Center"/>
                </StackPanel>
                <!-- Buttons -->
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <!-- B-11: Dismiss for Today — TabIndex=3 (lowest priority) -->
                    <Button x:Name="DismissBtn" Content="Dismiss for Today"
                            Width="148" Height="36" Foreground="#7878A0" FontSize="11"
                            Background="#14141F" BorderBrush="#555580" BorderThickness="1"
                            Cursor="Hand" Margin="0,0,8,0" TabIndex="3">
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
                    <!-- B-10: Snooze split-button -->
                    <StackPanel Orientation="Horizontal" Margin="0,0,8,0">
                        <Button x:Name="SnoozeBtn" Content="Snooze 5m" Height="36"
                                Foreground="#8585A5" FontSize="12" FontWeight="SemiBold"
                                Background="#1C1C2C" BorderBrush="#3A3A5A"
                                BorderThickness="1,1,0,1" Cursor="Hand" Padding="10,0" TabIndex="1">
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
                                    <!-- AG17-011: Exit item so the user can close the popup from the snooze menu -->
                                    <MenuItem x:Name="ExitItem" Header=" Exit"                 Foreground="#7878A0" FontSize="12"/>
                                </ContextMenu>
                            </Button.ContextMenu>
                        </Button>
                    </StackPanel>
                    <!-- Open Folder — TabIndex=0 (primary action) -->
                    <Button x:Name="LetsGoBtn" Content="Open Folder &#x2192;" Width="150" Height="36"
                            Foreground="#0D1117" FontSize="13" FontWeight="Bold"
                            Background="#00BCD4" BorderThickness="0" Cursor="Hand" TabIndex="0">
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

function Show-PopupWindow {
    # AG6-003: Warn if not on STA thread (required for WPF ShowDialog)
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA) {
        Write-DLog "Show-PopupWindow: thread is not STA ($([System.Threading.Thread]::CurrentThread.ApartmentState)) — WPF dialogs may fail" "WARN"
    }
    $configPath = $script:PopupCfgPath

    # Named mutex - one popup at a time (SSOT-006 / TASK-006)
    # FIX AG10-012: Add user and session isolation to prevent DoS between users
    $sessionId = try {
        [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    } catch {
        0  # Fallback to 0 if SessionId cannot be determined
    }
    $mutexName  = "Global\DailyMotivationBrainHelperPopup_$env:USERNAME`_$sessionId"
    Write-DLog "Using mutex: $mutexName"
    $mutexOwned = $false
    $mutex      = $null
    try {
        $mutex      = [System.Threading.Mutex]::new($false, $mutexName)
        $mutexOwned = $mutex.WaitOne(0)
        if (-not $mutexOwned) {
            Write-DLog "Mutex held - another popup running. Exiting." "WARN"
            # AG1-001: Dispose the mutex handle even when we did not acquire ownership,
            # to release the kernel object reference and prevent a handle leak.
            if ($mutex) { $mutex.Dispose() }
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
            if ($mutex) { $mutex.Dispose() }
            return
        }
    }
    catch {
        Write-DLog "Mutex error (non-fatal): $_" "WARN"
        if ($mutex) { $mutex.Dispose() }
        return  # AG1-002: Exit safely rather than proceed with undefined state
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
            $loaded = Get-Content -Path "$configPath" -Raw -Encoding UTF8 | ConvertFrom-Json
            $config = $loaded
            Write-DLog "Popup config loaded. title='$($config.title)' folder='$($config.folder_name)'"
        }
        catch { Write-DLog "Config parse failed: $($_.Exception.Message)" "ERROR" }
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
    $reader = $null
    try {
        $reader = [System.Xml.XmlNodeReader]::new($PopupXaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
        if ($null -eq $window) {
            Write-DLog "FATAL: XamlReader returned null" "ERROR"
            if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
            return
        }
    }
    catch {
        Write-DLog "FATAL: Popup XAML build failed - $_" "ERROR"
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }  # AG1-005: Dispose XmlNodeReader
    }

    # AG6-014: Validate FindName() returns non-null to prevent "member on null" errors
    function Find {
        param($n)
        $control = $window.FindName($n)
        if ($null -eq $control) {
            Write-DLog "FATAL: XAML element not found: $n" "ERROR"
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

    # Populate UI based on mode (normal vs path-missing)
    if ($script:pathMissing) {
        $normalPanel.Visibility      = "Collapsed"
        $pathMissingPanel.Visibility = "Visible"
        $folderName = if ($config.explorer_path) { Split-Path -Leaf $config.explorer_path } else { "Unknown" }
        if (-not $folderName -or $folderName.Length -eq 0) { $folderName = "Unknown" }
        $missingPathLabel.Text = "This folder can't be found: $folderName"
        $missingPathLabel.ToolTip    = $config.explorer_path
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
            $folderNameText.Text       = "Folder: $displayName"
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

    # Fade-in animation with recovery fallback (A6-BUG-01)
    $window.Add_Loaded({
            try {
                $anim = [System.Windows.Media.Animation.DoubleAnimation]::new(
                    0, 1, [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(300)))
                $window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
            }
            catch {
                Write-DLog "Fade-in failed: $_" "WARN"
                $window.Opacity = 1  # ensure visible if animation fails
            }
            # Fallback: if opacity is still 0 after 500ms, force it visible
            # AG6-016: Validate fallback timer interval
            $fallbackTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $fallbackInterval = [System.TimeSpan]::FromMilliseconds(500)
            if ($fallbackInterval.TotalMilliseconds -le 0) {
                Write-DLog "WARN: Fallback timer interval invalid, skipping animation fallback" "WARN"
                $window.Opacity = 1
            }
            else {
                $fallbackTimer.Interval = $fallbackInterval
                $fallbackTimer.Add_Tick({
                    $fallbackTimer.Stop()
                    if ($window.Opacity -lt 0.5) { $window.Opacity = 1 }
                })
                $fallbackTimer.Start()
            }
        })

    # Race condition fix: stop countdown on ANY button press before click handler fires (A9-BUG-12)
    # PreviewMouseDown fires before Click, so this safely cancels the timer first.
    $cancelCountdown = {
        param($s, $e)
        if ($null -ne $timer -and $timer.IsEnabled) {
            $timer.Stop()
            Write-DLog "Countdown cancelled by button PreviewMouseDown"
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
                    # AG11-011: Check if window is still loaded before accessing UI elements
                    if ($null -eq $window -or -not $window.IsLoaded) {
                        Write-DLog "Window no longer loaded, stopping timer" "WARN"
                        $script:windowClosed = $true
                        $timer.Stop()
                        return
                    }
                    # AG11-011: Check windowClosed flag FIRST before any UI operations
                    if ($script:windowClosed) {
                        $timer.Stop()
                        return
                    }
                    if ($script:firstTick) { Write-DLog "Countdown running"; $script:firstTick = $false }
                    $script:remaining--
                    $countdownText.Text = $script:remaining
                    if ($script:remaining -le 0 -and -not $script:windowClosed) {
                        # AG11-011: Set flag BEFORE closing window to prevent race condition
                        $script:windowClosed = $true
                        $timer.Stop()
                        $script:openExplorer = $true
                        $window.Close()
                    }
                }
                catch {
                    Write-DLog "Timer error: $_" "ERROR"
                    $script:windowClosed = $true
                    $timer.Stop()
                }
                finally {
                    # AG1-011: Always stop timer when countdown completes or window closes
                    if ($script:remaining -le 0 -or $script:windowClosed) {
                        $timer.Stop()
                    }
                }
            })
        $timer.Start()
        Write-DLog "Countdown timer started"
    }

    # Snooze duration helpers
    # AG6-022: Set proper ContextMenu placement to avoid off-screen positioning
    $snoozeDropBtn.Add_Click({
        $snoozeDropBtn.ContextMenu.PlacementTarget = $snoozeDropBtn
        $snoozeDropBtn.ContextMenu.Placement = 'Bottom'
        $snoozeDropBtn.ContextMenu.IsOpen = $true
    })

    $snooze5.Add_Click({  Set-SnoozeDuration -Minutes 5 -SnoozeBtnControl $snoozeBtn  })
    $snooze15.Add_Click({ Set-SnoozeDuration -Minutes 15 -SnoozeBtnControl $snoozeBtn })
    $snooze30.Add_Click({ Set-SnoozeDuration -Minutes 30 -SnoozeBtnControl $snoozeBtn })
    $snooze60.Add_Click({ Set-SnoozeDuration -Minutes 60 -SnoozeBtnControl $snoozeBtn })

    # AG17-011: Exit item closes the popup without opening explorer (equivalent to Dismiss)
    if ($exitItem) {
        $exitItem.Add_Click({
            Write-DLog "Exit menu item clicked"
            if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) { $timer.Stop() }
            $script:openExplorer = $false
            $script:windowClosed = $true
            $window.Close()
        })
    }

    # Snooze button
    $snoozeBtn.Add_Click({
            try {
                Write-DLog "Snooze clicked ($($script:snoozeMinutes) min)"
                if (-not $script:pathMissing) { $timer.Stop() }
                $script:snoozeCount++
                $script:openExplorer = $false
                # AG11-003: Validate snoozeMinutes is within valid range (1-1440 minutes = 24 hours)
                if ($script:snoozeMinutes -lt 1 -or $script:snoozeMinutes -gt 1440) {
                    Write-DLog "Invalid snooze duration: $($script:snoozeMinutes) minutes" "ERROR"
                    [System.Windows.MessageBox]::Show(
                        "Snooze duration must be between 1 minute and 24 hours.",
                        "Invalid Snooze", "OK", "Error") | Out-Null
                    return
                }
                # AG11-003: Add 1-minute buffer to snooze time to prevent scheduling in past
                # If system processing takes time, this ensures TriggerTime validation won't fail
                $bufferMinutes = 1
                $snoozeTime = (Get-Date).AddMinutes($script:snoozeMinutes + $bufferMinutes)
                Write-DLog "Snooze time calculated: $snoozeTime (requested: $($script:snoozeMinutes)m + buffer: ${bufferMinutes}m)"
                $snoozeResult = New-MotivationTask -FolderPath $config.explorer_path -TriggerTime $snoozeTime -Force
                if (-not $snoozeResult.Success) {
                    Write-DLog "Snooze task creation failed: $($snoozeResult.Error)" "ERROR"
                    [System.Windows.MessageBox]::Show(
                        "Could not snooze the task.`n`n$($snoozeResult.Error)",
                        "Snooze Failed", "OK", "Error") | Out-Null
                    return
                }
                Write-DLog "Snooze task created for $snoozeTime"
                $window.Close()
            }
            catch {
                # AG6-017: Ensure timer stops even in exception paths
                if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) {
                    $timer.Stop()
                }
                Write-DLog "Snooze error: $_" "ERROR"
                $window.Close()
            }
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
                    foreach ($t in $pending) {
                        $removed = Remove-MotivationTask -TaskId $t.task_id
                        if (-not $removed) {
                            Write-DLog "Failed to remove task $($t.task_id) during dismiss" "WARN"
                        }
                    }
                }
                $window.Close()
            }
            catch {
                # AG6-017: Ensure timer stops even in exception paths
                if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) {
                    $timer.Stop()
                }
                Write-DLog "Dismiss error: $_" "ERROR"
                $window.Close()
            }
        })

    # Open Folder button
    $letsGoBtn.Add_Click({
            try {
                Write-DLog "Open Folder clicked"
                if (-not $script:pathMissing) { $timer.Stop() }
                $script:openExplorer = $true
                $window.Close()
            }
            catch {
                # AG6-017: Ensure timer stops even in exception paths
                if (-not $script:pathMissing -and $null -ne $timer -and $timer.IsEnabled) {
                    $timer.Stop()
                }
                Write-DLog "LetsGo error: $_" "ERROR"
            }
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
            $dialog = $null
            try {
                $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
                $dialog.Description         = "Choose the new location for this folder"
                $dialog.ShowNewFolderButton = $false
                if ($dialog.ShowDialog() -eq "OK") {
                    $newPath = $dialog.SelectedPath
                    Write-DLog "Re-pick: $newPath"
                    try {
                        # AG3-008 / AG3-016: Use Set-PopupConfig for atomic write + concurrent-access safety
                        $c = Get-PopupConfig
                        Set-PopupConfig -Glyph $c.glyph -Title $c.title -Body $c.body `
                            -ExplorerPath $newPath -TaskId $c.task_id
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
            }
            finally {
                if ($dialog) { $dialog.Dispose() }  # AG14-001: Dispose FolderBrowserDialog
            }
        })

    # AG3-013, AG3-014: Add window cleanup handler for timers
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
        catch { Write-DLog "Popup timer cleanup error: $_" "WARN" }
    })

    # Show popup
    Write-DLog "Calling ShowDialog()"
    try {
        $window.ShowDialog() | Out-Null
        Write-DLog "ShowDialog returned. openExplorer=$($script:openExplorer)"
    }
    catch { Write-DLog "ShowDialog threw: $_" "ERROR" }
    finally {
        # AG6-004: Close WPF window to release resources
        if ($window) {
            try {
                $window.Close()
                Write-DLog "PopupWindow closed"
            }
            catch { Write-DLog "Window close error: $_" "WARN" }
        }

        # AG3-005, AG3-006, AG3-007, AG3-018, AG3-019: Reset state variables
        # to prevent leakage between popup instances
        $script:pathMissing = $false
        $script:openExplorer = $true
        $script:newExplorerPath = ""
        $script:remaining = 20
        $script:snoozeCount = 0
        $script:firstTick = $true
        $script:windowClosed = $false

        if ($mutexOwned -and $mutex) {
            try { $mutex.ReleaseMutex(); Write-DLog "Mutex released" }
            catch { Write-DLog "Mutex release error: $_" "WARN" }
        }
        if ($null -ne $mutex) {
            try { $mutex.Dispose() }  # AG1-010: Dispose mutex handle
            catch { Write-DLog "Mutex dispose error: $_" "WARN" }
        }
    }

    # Post-close: remove the originating task from Task Scheduler and tasks.json.
    # This must happen for ALL outcomes (Open, Countdown, Snooze, Dismiss, PathMissing).
    # Cannot rely on DeleteExpiredTaskAfter alone — it only fires when the scheduled
    # trigger expires naturally; manually-run tasks are never considered "expired".
    if ($config.task_id -and $config.task_id -ne "") {
        Write-DLog "Removing originating task: $($config.task_id)"
        Remove-MotivationTask -TaskId $config.task_id | Out-Null
    }

    # Post-close: open Explorer (REQ-009)
    $effectivePath = if ($script:newExplorerPath) { $script:newExplorerPath } else { $config.explorer_path }
    if ($script:openExplorer -and $effectivePath -and $effectivePath -ne "") {
        Write-DLog "Launching Explorer: $effectivePath"
        try {
            Start-Process -FilePath "explorer.exe" -ArgumentList "`"$effectivePath`"" -ErrorAction Stop
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
    # Use if-else for .NET Framework 4.x compatibility (ps2exe target)
    $platformName = if ($script:IsWindowsPlatform) { 'Windows' } else { 'Linux' }
    Write-DLog "====== STARTED Mode=$Mode PID=$PID PSVer=$($PSVersionTable.PSVersion) Platform=$platformName ======"

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

    Initialize-AppData

    switch ($Mode) {
        "/popup" {
            Show-PopupWindow
        }
        "/setfolder" {
            Write-DLog "setfolder: FolderPath='$FolderPath'"
            if ($FolderPath -and (Test-Path $FolderPath -PathType Container)) {
                $cfg         = Get-Config
                $triggerHour = if ($cfg -and $null -ne $cfg.default_trigger_hour) { [int]$cfg.default_trigger_hour } else { $script:ConfigDefaults.default_trigger_hour }
                $triggerTime = (Get-Date).Date.AddDays(1).AddHours($triggerHour)
                $msg         = Get-RandomMessage
                $result      = New-MotivationTask -FolderPath $FolderPath -TriggerTime $triggerTime
                Write-DLog "setfolder: New-MotivationTask result Success=$($result.Success) IsDuplicate=$($result.IsDuplicate) Error='$($result.Error)'"
                if ($result.Success) {
                    Set-PopupConfig -Glyph $msg.Glyph -Title $msg.Title -Body $msg.Body `
                        -ExplorerPath $FolderPath -TaskId $result.TaskId
                    # AG6-019: Use Show-InfoDialog (WPF→WinForms→Console fallback) instead of
                    # direct [System.Windows.MessageBox] to handle non-WPF environments.
                    $folderLeaf = Split-Path -Leaf $FolderPath; if (-not $folderLeaf -or $folderLeaf.Length -eq 0) { $folderLeaf = "Unknown Folder" }
                    $schedDisplay = $triggerTime.ToString("dddd 'at' h:mm tt")
                    Show-InfoDialog -Message "'$folderLeaf' scheduled for $schedDisplay." `
                        -Title "Folder Scheduled"
                }
                elseif ($result.IsDuplicate) {
                    Show-InfoDialog -Message "'$FolderPath' is already scheduled for tomorrow." `
                        -Title "Already Scheduled"
                }
                else {
                    Show-ErrorDialog -Message "Could not schedule '$FolderPath'.`n`n$($result.Error)" `
                        -Title "Schedule Failed"
                }
            }
            else {
                Write-DLog "setfolder: invalid or missing FolderPath '$FolderPath'" "WARN"
            }
        }
        default {
            # REQ-010: Ensure context menu is registered every time the exe launches.
            # This self-heals if the user manually deleted the registry key.
            Register-ContextMenu -ExePath $script:ExePath
            Show-MainWindow
        }
    }
}
