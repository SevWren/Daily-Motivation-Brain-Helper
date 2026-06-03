# =============================================================================
# ConfigManager.psm1
# Manages all JSON config files in %APPDATA%\DailyMotivationBrainHelper\
# User never interacts with these files directly.
# =============================================================================

$script:AppDataDir  = Join-Path $env:APPDATA "DailyMotivationBrainHelper"
$script:ConfigPath  = Join-Path $script:AppDataDir "popup_config.json"
$script:TasksPath   = Join-Path $script:AppDataDir "tasks.json"
$script:MessagesPath= Join-Path $script:AppDataDir "messages.json"
$script:SettingsPath= Join-Path $script:AppDataDir "app_settings.json"
$script:LogPath     = Join-Path $script:AppDataDir "popup_log.txt"

function Initialize-AppData {
    <#
    .SYNOPSIS
    Creates %APPDATA%\DailyMotivationBrainHelper\ and default JSON files if absent.
    Falls back to %TEMP%\DailyMotivationBrainHelper\ if %APPDATA% is unavailable (GAP-003).
    Call at every app startup.
    #>
    if (-not (Test-Path $script:AppDataDir)) {
        try {
            New-Item -ItemType Directory -Path $script:AppDataDir -Force -ErrorAction Stop | Out-Null
        } catch {
            # %APPDATA% unavailable (permission denied, disk quota, roaming redirect failure).
            # Fall back to %TEMP% so the app can still run.
            $fallback = Join-Path $env:TEMP "DailyMotivationBrainHelper"
            Write-Warning "Initialize-AppData: Could not create '$script:AppDataDir' ($_). Falling back to '$fallback'."
            New-Item -ItemType Directory -Path $fallback -Force | Out-Null
            $script:AppDataDir   = $fallback
            $script:ConfigPath   = Join-Path $script:AppDataDir "popup_config.json"
            $script:TasksPath    = Join-Path $script:AppDataDir "tasks.json"
            $script:MessagesPath = Join-Path $script:AppDataDir "messages.json"
            $script:SettingsPath = Join-Path $script:AppDataDir "app_settings.json"
            $script:LogPath      = Join-Path $script:AppDataDir "popup_log.txt"
        }
    }

    # app_settings.json
    if (-not (Test-Path $script:SettingsPath)) {
        $defaults = [ordered]@{
            firstRun      = $true
            lastFolder    = ""
            recentFolders = @()
            theme         = "dark"
        }
        $defaults | ConvertTo-Json -Depth 3 | Set-Content -Path $script:SettingsPath -Encoding UTF8
    }

    # tasks.json
    if (-not (Test-Path $script:TasksPath)) {
        "[]" | Set-Content -Path $script:TasksPath -Encoding UTF8
    }

    # popup_config.json (blank default)
    if (-not (Test-Path $script:ConfigPath)) {
        [ordered]@{
            glyph         = "[+]"
            title         = ""
            body          = ""
            explorer_path = ""
            folder_name   = ""
            task_id       = ""
        } | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
    }
}

function Get-AppSettings {
    try {
        return Get-Content $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return [PSCustomObject]@{ firstRun = $true; lastFolder = ""; recentFolders = @() }
    }
}

function Save-AppSettings {
    param([PSCustomObject]$Settings)
    $Settings | ConvertTo-Json -Depth 3 | Set-Content -Path $script:SettingsPath -Encoding UTF8
}

function Get-IsFirstRun {
    return (Get-AppSettings).firstRun -eq $true
}

function Set-FirstRunComplete {
    $s = Get-AppSettings
    $s.firstRun = $false
    Save-AppSettings $s
}

function Get-LastFolder {
    return (Get-AppSettings).lastFolder
}

function Set-LastFolder {
    param([string]$FolderPath)
    $s = Get-AppSettings
    $s.lastFolder = $FolderPath
    Save-AppSettings $s
}

function Get-RecentFolders {
    $folders = (Get-AppSettings).recentFolders
    if ($null -eq $folders) { return @() }
    return $folders
}

function Add-RecentFolder {
    <#
    Adds a folder to the recent list (FIFO, max 5, deduped, newest first).
    #>
    param([string]$FolderPath)
    $s = Get-AppSettings
    $existing = if ($null -eq $s.recentFolders) { @() } else { [System.Collections.Generic.List[string]]$s.recentFolders }
    # Remove if already present, then prepend
    $existing.Remove($FolderPath) | Out-Null
    $existing.Insert(0, $FolderPath)
    if ($existing.Count -gt 5) { $existing = $existing[0..4] }
    $s.recentFolders = $existing
    Save-AppSettings $s
}

function Get-PopupConfig {
    try {
        return Get-Content $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Set-PopupConfig {
    param(
        [string]$Glyph,
        [string]$Title,
        [string]$Body,
        [string]$ExplorerPath,
        [string]$TaskId
    )
    $folderName = Split-Path -Leaf $ExplorerPath
    [ordered]@{
        glyph         = $Glyph
        title         = $Title
        body          = $Body
        explorer_path = $ExplorerPath
        folder_name   = $folderName
        task_id       = $TaskId
    } | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
}

function Write-OutcomeLog {
    <#
    Writes a structured pipe-delimited log entry.
    Format: [YYYY-MM-DD HH:mm:ss] | task_id | folder_name | folder_path | outcome | snooze_count
    #>
    param(
        [string]$TaskId,
        [string]$FolderName,
        [string]$FolderPath,
        [string]$Outcome,      # Opened | Snoozed | Dismissed | PathMissing
        [int]$SnoozeCount = 0
    )
    $ts    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] | $TaskId | $FolderName | $FolderPath | $Outcome | $SnoozeCount"
    Add-Content -Path $script:LogPath -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-OutcomeLog {
    <#
    Returns parsed log entries as objects, newest first, max $Limit entries.
    #>
    param([int]$Limit = 30)
    if (-not (Test-Path $script:LogPath)) { return @() }
    $lines = Get-Content $script:LogPath -Encoding UTF8 | Where-Object { $_ -match '^\[' } | Select-Object -Last $Limit
    $entries = foreach ($line in [Linq.Enumerable]::Reverse([string[]]$lines)) {
        $parts = $line -split '\s*\|\s*'
        if ($parts.Count -ge 6) {
            [PSCustomObject]@{
                Timestamp   = $parts[0].Trim('[', ']')
                TaskId      = $parts[1].Trim()
                FolderName  = $parts[2].Trim()
                FolderPath  = $parts[3].Trim()
                Outcome     = $parts[4].Trim()
                SnoozeCount = [int]($parts[5].Trim())
            }
        }
    }
    return $entries
}

function Clear-OutcomeLog {
    if (Test-Path $script:LogPath) {
        Clear-Content -Path $script:LogPath -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function *
