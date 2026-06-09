# Incident Response Procedures

**Last Updated:** 2026-06-09
**Version:** 1.0
**Status:** Official Incident Response Manual

---

## Table of Contents

1. [Incident Classification](#incident-classification)
2. [Response Procedures](#response-procedures)
3. [Escalation Paths](#escalation-paths)
4. [Common Incidents](#common-incidents)
5. [Data Collection](#data-collection)
6. [Rollback Procedures](#rollback-procedures)
7. [User Communication](#user-communication)
8. [Post-Mortem Process](#post-mortem-process)
9. [Root Cause Analysis](#root-cause-analysis)
10. [Prevention Measures](#prevention-measures)

---

## Incident Classification

### Severity Levels

| Level | Name | Definition | Response Time | Example |
|-------|------|------------|---------------|---------|
| **P0** | Critical | Complete application failure affecting all users | Immediate | App crashes on startup for all users |
| **P1** | High | Core functionality broken for most users | < 4 hours | Scheduled tasks not running system-wide |
| **P2** | Medium | Feature degradation or intermittent issues | < 24 hours | WPF threading errors on some machines |
| **P3** | Low | Minor issues, workaround available | < 1 week | UI cosmetic issues, typos |

### Classification Criteria

**P0 - Critical:**
- Application fails to launch on startup
- Data corruption in tasks.json or app_settings.json
- Task Scheduler integration completely broken
- Security vulnerability actively exploited

**P1 - High:**
- Scheduled tasks fail to execute
- Module import failures preventing core functionality
- UAC elevation issues blocking setup
- Widespread WPF rendering failures

**P2 - Medium:**
- Popup doesn't appear intermittently
- Snooze functionality broken
- Path validation fails for valid folders
- Performance degradation (high CPU/memory)

**P3 - Low:**
- UI text truncation or alignment issues
- Minor log file formatting problems
- Non-critical feature enhancement requests
- Documentation errors

---

## Response Procedures

### P0 - Critical Incident Response

**Immediate Actions (0-15 minutes):**

1. **Acknowledge Incident**
   ```powershell
   # Create incident tracking file
   $incidentId = "INC-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   $incidentLog = "C:\Incidents\$incidentId.txt"

   @"
   Incident ID: $incidentId
   Severity: P0 - Critical
   Reporter: [Name/Email]
   Time Detected: $(Get-Date)
   Description: [Brief description]
   Status: INVESTIGATING
   "@ | Out-File $incidentLog
   ```

2. **Assess Blast Radius**
   - How many users affected? (All/Most/Some/One)
   - Which version(s) affected?
   - What platforms? (Win 10/11, specific builds)

3. **Initiate Communication**
   - Post status update (see [User Communication](#user-communication))
   - Notify development team
   - Create GitHub issue with `P0-CRITICAL` label

**Investigation (15-60 minutes):**

4. **Collect Critical Diagnostics**
   ```powershell
   # Run diagnostic collection script
   $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
   $diagPath = "C:\Incidents\$incidentId\Diagnostics"
   New-Item -ItemType Directory -Path $diagPath -Force

   # Collect logs
   Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*.json" $diagPath -Force
   Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*.txt" $diagPath -Force
   Copy-Item "$env:TEMP\DailyMotivation_*.log" $diagPath -Force -ErrorAction SilentlyContinue

   # Export Task Scheduler tasks
   Get-ScheduledTask -TaskName "DailyMotivation*" |
     Export-ScheduledTask |
     Out-File "$diagPath\ScheduledTasks.xml" -Encoding UTF8

   # System information
   systeminfo > "$diagPath\SystemInfo.txt"
   $PSVersionTable | Out-File "$diagPath\PSVersion.txt"
   ```

5. **Identify Root Cause**
   - Check recent code changes (git log)
   - Review error logs for stack traces
   - Test on clean machine if needed

**Resolution (1-4 hours):**

6. **Implement Fix**
   - Develop hotfix if code change required
   - Test fix on affected environment
   - Prepare rollback plan before deployment

7. **Deploy Fix**
   - Release hotfix version (e.g., v1.1.1)
   - Update GitHub release with fix notes
   - Notify users via communication channels

8. **Verify Resolution**
   - Test on multiple affected machines
   - Monitor for 24 hours
   - Close incident when confirmed stable

**Post-Incident:**
- Schedule post-mortem within 48 hours
- Document in incident log
- Update TROUBLESHOOTING.md with prevention steps

---

### P1 - High Priority Incident Response

**Response Timeline: < 4 hours**

1. **Acknowledge & Assess** (0-30 minutes)
   - Create incident log (similar to P0)
   - Determine impact scope
   - Check if workaround exists

2. **Communicate** (30 minutes)
   - Post status update
   - Provide workaround if available
   - Set expectation for fix timeline

3. **Investigate** (1-2 hours)
   - Collect diagnostics (see Data Collection)
   - Reproduce issue in dev environment
   - Identify root cause

4. **Fix & Deploy** (2-4 hours)
   - Develop and test fix
   - Release patch version
   - Update documentation

5. **Monitor** (4-24 hours)
   - Track user reports
   - Verify fix effectiveness
   - Close incident when stable

---

### P2 - Medium Priority Incident Response

**Response Timeline: < 24 hours**

1. **Log & Triage** (0-1 hour)
   - Create GitHub issue with `P2-MEDIUM` label
   - Document reproduction steps
   - Assess if workaround exists

2. **Investigate** (1-8 hours)
   - Reproduce issue
   - Review related code
   - Identify fix complexity

3. **Schedule Fix** (8-24 hours)
   - Include in next patch release
   - Or release targeted fix if critical enough
   - Update issue with ETA

4. **Deploy & Verify**
   - Release with next version
   - Monitor for regressions
   - Close issue when confirmed fixed

---

### P3 - Low Priority Incident Response

**Response Timeline: < 1 week**

1. **Log Issue**
   - Create GitHub issue with `P3-LOW` label
   - Document details
   - Add to backlog

2. **Schedule for Next Release**
   - Prioritize with other P3 items
   - Assign to milestone
   - Fix in normal development cycle

3. **Deploy with Regular Release**
   - Include in release notes
   - No special communication needed

---

## Escalation Paths

### Internal Escalation

**Level 1: Developer**
- Initial triage and investigation
- Handle P3, most P2 incidents
- Escalate if unable to resolve within SLA

**Level 2: Lead Developer**
- Handle P1, P2 incidents
- Review critical fixes before deployment
- Coordinate cross-functional response for P0

**Level 3: Security Contact**
- Handle security-related incidents
- Email: mmueller07@gmail.com
- Subject: `[SECURITY-INCIDENT] Daily-Motivation-Brain-Helper`

### External Escalation

**User Support:**
- GitHub Issues: https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues
- Tag with appropriate severity label
- Expected response time per severity level

**Security Issues:**
- **Do NOT** post publicly
- Email: mmueller07@gmail.com
- Subject: `[SECURITY] Daily-Motivation-Brain-Helper`
- Encrypt sensitive details if possible

---

## Common Incidents

### INC-001: App Crashes on Startup

**Severity:** P0 (if widespread) or P1 (if isolated)

**Symptoms:**
- Application window never appears
- Process starts then immediately exits
- Error in Event Viewer: Application crash

**Common Causes:**
1. Module import failure (missing .psm1 files)
2. XAML parsing error (corrupted MainWindow.xaml)
3. PowerShell execution policy blocking
4. .NET Framework missing/corrupted

**Quick Fix:**
```powershell
# Verify modules exist
Test-Path "$env:APPDATA\DailyMotivationBrainHelper\Modules\ConfigManager.psm1"
Test-Path "$env:APPDATA\DailyMotivationBrainHelper\Modules\TaskScheduler.psm1"

# If missing, re-run setup
cd C:\DailyMotivation\src
.\UpdateScheduledTask.ps1

# Verify XAML is valid
[xml]$xaml = Get-Content "C:\DailyMotivation\src\MainWindow.xaml" -Raw -Encoding UTF8
# Should not throw exception

# Check execution policy
Get-ExecutionPolicy -List
# Set if needed:
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**Resolution:**
- See TROUBLESHOOTING.md: "Application Won't Launch"
- See TROUBLESHOOTING.md: "Module Not Found Errors"

**Post-Incident Actions:**
- Update installation verification script
- Add pre-flight checks to MainApp.ps1
- Document in INSTALL.md

---

### INC-002: Scheduled Tasks Not Running

**Severity:** P1

**Symptoms:**
- Task shows "Ready" in Task Scheduler
- Scheduled time passes, no popup appears
- No error in Event Viewer

**Common Causes:**
1. Task Scheduler service stopped
2. User not logged in at trigger time
3. Task disabled accidentally
4. Execution path incorrect in task action

**Quick Fix:**
```powershell
# Check Task Scheduler service
$service = Get-Service -Name Schedule
if ($service.Status -ne 'Running') {
    Start-Service Schedule
}

# Check task state
Get-ScheduledTask -TaskName "DailyMotivation_*" | ForEach-Object {
    if ($_.State -eq 'Disabled') {
        Enable-ScheduledTask -TaskName $_.TaskName
    }
}

# Verify task action
$task = Get-ScheduledTask -TaskName "DailyMotivation_*" | Select-Object -First 1
$action = $task.Actions[0]
Write-Host "Action: $($action.Execute) $($action.Arguments)"
# Should be: cmd.exe /c "C:\DailyMotivation\src\LaunchMotivation.bat"

# Test task manually
Start-ScheduledTask -TaskName $task.TaskName
```

**Resolution:**
- See TROUBLESHOOTING.md: "Popup Doesn't Appear at Scheduled Time"
- See TROUBLESHOOTING.md: "Scheduled Task Failures"

**Post-Incident Actions:**
- Add task health check to MainApp startup
- Create automated monitoring script
- Update OPERATIONS.md monitoring section

---

### INC-003: Data Corruption in tasks.json

**Severity:** P1

**Symptoms:**
- App crashes when opening task list
- Error: "Invalid JSON primitive"
- tasks.json unreadable

**Common Causes:**
1. Concurrent write operations (race condition)
2. Manual editing with syntax errors
3. Application crash during write
4. Disk full/quota exceeded

**Quick Fix:**
```powershell
$appData = "$env:APPDATA\DailyMotivationBrainHelper"

# Backup corrupted file
Copy-Item "$appData\tasks.json" "$appData\tasks.json.corrupted.$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Attempt recovery
try {
    $content = Get-Content "$appData\tasks.json" -Raw
    $tasks = $content | ConvertFrom-Json
    Write-Host "JSON is valid, recovery not needed"
} catch {
    Write-Host "JSON corrupted, resetting to empty array"
    "[]" | Set-Content "$appData\tasks.json" -Encoding UTF8
}

# If tasks were scheduled, rebuild from Task Scheduler
Get-ScheduledTask -TaskName "DailyMotivation_*" | ForEach-Object {
    Write-Host "Found orphaned task: $($_.TaskName)"
    Write-Host "User must reschedule via app UI"
}
```

**Resolution:**
- See TROUBLESHOOTING.md: "JSON Parsing Errors"
- Restore from backup if available
- User must reschedule tasks

**Post-Incident Actions:**
- Implement file locking in ConfigManager.psm1
- Add JSON validation before write
- Create automatic backup before overwrite
- Document in RISK_REGISTER.md

---

### INC-004: WPF Threading Errors

**Severity:** P2

**Symptoms:**
- Error: "Current thread must be STA"
- Popup crashes after display
- DispatcherTimer errors

**Common Causes:**
1. PowerShell launched without -STA flag
2. Cross-thread UI updates
3. Task Scheduler action missing STA setup

**Quick Fix:**
```powershell
# Check current thread state
[System.Threading.Thread]::CurrentThread.GetApartmentState()
# Must return: STA

# Verify LaunchMotivation.bat uses -STA
Get-Content "C:\DailyMotivation\src\LaunchMotivation.bat" | Select-String "-STA"
# Should find: powershell.exe -STA -ExecutionPolicy Bypass...

# Test direct launch with STA
powershell.exe -STA -ExecutionPolicy Bypass -File "C:\DailyMotivation\src\DailyMotivation.ps1"
```

**Resolution:**
- See TROUBLESHOOTING.md: "WPF Crashes (STA Thread Issues)"
- Ensure all PowerShell launches use -STA flag
- Review DailyMotivation.ps1 for cross-thread operations

**Post-Incident Actions:**
- Add STA state check at script startup
- Update .build.ps1 to enforce -STA in compiled EXE
- Document threading requirements in ARCHITECTURE.md

---

### INC-005: Module Import Failures

**Severity:** P1

**Symptoms:**
- Error: "The specified module 'ConfigManager' was not loaded"
- App exits immediately after launch
- Module files exist but can't be imported

**Common Causes:**
1. Module files missing from %APPDATA%
2. PowerShell module path incorrect
3. File permissions blocking read access
4. Antivirus quarantine

**Quick Fix:**
```powershell
$modulePath = "$env:APPDATA\DailyMotivationBrainHelper\Modules"

# Verify module files exist
Get-ChildItem $modulePath
# Should show: ConfigManager.psm1, TaskScheduler.psm1

# Test import manually
Import-Module "$modulePath\ConfigManager.psm1" -Force -Verbose
Import-Module "$modulePath\TaskScheduler.psm1" -Force -Verbose

# If import fails, check permissions
Get-Acl "$modulePath\ConfigManager.psm1" | Format-List

# Re-copy from source
$src = "C:\DailyMotivation\src\Modules"
Copy-Item "$src\*.psm1" $modulePath -Force

# Check for antivirus quarantine
# (Manual: Check AV logs/quarantine section)
```

**Resolution:**
- See TROUBLESHOOTING.md: "Module Not Found Errors"
- See TROUBLESHOOTING.md: "Import-Module: Access to the path is denied"

**Post-Incident Actions:**
- Add module verification at app startup
- Create module repair function
- Document AV exclusions in INSTALL.md

---

### INC-006: UAC Elevation Issues

**Severity:** P2

**Symptoms:**
- Setup fails with "Access denied"
- Shell extension registration fails
- Task creation blocked

**Common Causes:**
1. UpdateScheduledTask.ps1 not run as admin
2. User lacks Task Scheduler permissions
3. UAC prompt dismissed/blocked by policy

**Quick Fix:**
```powershell
# Check if running as admin (for setup scripts only)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Not running as administrator"
    Write-Host "Right-click UpdateScheduledTask.ps1 → Run as Administrator"
}

# For shell extension specifically
Test-Path "HKCR:\Directory\shell\DailyMotivationSchedule"
# If False, shell extension not registered

# Verify user can create tasks (no admin needed for user tasks)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
Write-Host "User can create tasks: OK"
```

**Resolution:**
- See TROUBLESHOOTING.md: "UAC and Permissions Issues"
- See INSTALL.md for correct installation procedure
- MainApp and popup DO NOT require admin

**Post-Incident Actions:**
- Clarify admin requirements in documentation
- Add elevation check to setup scripts
- Display clear error message if setup runs without admin

---

## Data Collection

### Automated Diagnostic Collection

**Primary Script: Collect-Diagnostics.ps1**

```powershell
# Save as: C:\DailyMotivation\scripts\Collect-Diagnostics.ps1

param(
    [string]$IncidentId = "DIAG-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

$diagRoot = "$env:USERPROFILE\Desktop\DailyMotivation_Diagnostics"
$diagPath = Join-Path $diagRoot $IncidentId
New-Item -ItemType Directory -Path $diagPath -Force | Out-Null

Write-Host "Collecting diagnostics for incident: $IncidentId"

# 1. Configuration files
Write-Host "Collecting configuration files..."
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
if (Test-Path $appData) {
    Copy-Item "$appData\*.json" $diagPath -Force -ErrorAction SilentlyContinue
    Copy-Item "$appData\*.txt" $diagPath -Force -ErrorAction SilentlyContinue
}

# 2. Log files
Write-Host "Collecting log files..."
Copy-Item "$env:TEMP\DailyMotivation_*.log" $diagPath -Force -ErrorAction SilentlyContinue

# 3. Task Scheduler exports
Write-Host "Exporting scheduled tasks..."
$tasks = Get-ScheduledTask -TaskName "DailyMotivation*" -ErrorAction SilentlyContinue
if ($tasks) {
    $tasks | Export-ScheduledTask | Out-File "$diagPath\ScheduledTasks.xml" -Encoding UTF8

    # Task history
    $tasks | ForEach-Object {
        $info = Get-ScheduledTaskInfo -TaskName $_.TaskName
        [PSCustomObject]@{
            TaskName      = $_.TaskName
            State         = $_.State
            LastRunTime   = $info.LastRunTime
            LastTaskResult = $info.LastTaskResult
            NextRunTime   = $info.NextRunTime
        }
    } | Export-Csv "$diagPath\TaskHistory.csv" -NoTypeInformation
}

# 4. System information
Write-Host "Collecting system information..."
@"
Incident ID: $IncidentId
Collection Time: $(Get-Date)
Computer Name: $env:COMPUTERNAME
Username: $env:USERNAME

Windows Version: $((Get-CimInstance Win32_OperatingSystem).Caption) Build $((Get-CimInstance Win32_OperatingSystem).BuildNumber)
PowerShell Version: $($PSVersionTable.PSVersion)
.NET Framework: $(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' | Get-ItemPropertyValue -Name Version)

AppData Path: $env:APPDATA
Temp Path: $env:TEMP
Install Location: C:\DailyMotivation\

Task Scheduler Service Status: $(Get-Service Schedule | Select-Object -ExpandProperty Status)
RPC Service Status: $(Get-Service RpcSs | Select-Object -ExpandProperty Status)

Execution Policy:
$(Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-String)
"@ | Out-File "$diagPath\SystemInfo.txt"

# 5. Process information
Write-Host "Collecting process information..."
Get-Process | Where-Object {
    $_.ProcessName -like "*PowerShell*" -or
    $_.ProcessName -like "*DailyMotivation*"
} | Select-Object ProcessName, Id, StartTime, CPU, WorkingSet64 |
    Export-Csv "$diagPath\Processes.csv" -NoTypeInformation

# 6. Event Viewer logs
Write-Host "Collecting Event Viewer logs..."
try {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-TaskScheduler/Operational'
        StartTime = (Get-Date).AddDays(-7)
    } -MaxEvents 500 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -like "*DailyMotivation*" } |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Export-Csv "$diagPath\TaskScheduler_EventLog.csv" -NoTypeInformation
} catch {
    Write-Host "Could not collect Task Scheduler event log: $_"
}

try {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'Windows PowerShell'
        StartTime = (Get-Date).AddDays(-7)
    } -MaxEvents 500 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -like "*DailyMotivation*" } |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Export-Csv "$diagPath\PowerShell_EventLog.csv" -NoTypeInformation
} catch {
    Write-Host "Could not collect PowerShell event log: $_"
}

# 7. Module verification
Write-Host "Verifying modules..."
@"
ConfigManager.psm1 exists: $(Test-Path "$appData\Modules\ConfigManager.psm1")
TaskScheduler.psm1 exists: $(Test-Path "$appData\Modules\TaskScheduler.psm1")

ConfigManager.psm1 size: $((Get-Item "$appData\Modules\ConfigManager.psm1" -ErrorAction SilentlyContinue).Length) bytes
TaskScheduler.psm1 size: $((Get-Item "$appData\Modules\TaskScheduler.psm1" -ErrorAction SilentlyContinue).Length) bytes

Import test results:
"@ | Out-File "$diagPath\ModuleVerification.txt"

try {
    Import-Module "$appData\Modules\ConfigManager.psm1" -Force -ErrorAction Stop
    "ConfigManager: OK" | Out-File "$diagPath\ModuleVerification.txt" -Append
} catch {
    "ConfigManager FAILED: $_" | Out-File "$diagPath\ModuleVerification.txt" -Append
}

try {
    Import-Module "$appData\Modules\TaskScheduler.psm1" -Force -ErrorAction Stop
    "TaskScheduler: OK" | Out-File "$diagPath\ModuleVerification.txt" -Append
} catch {
    "TaskScheduler FAILED: $_" | Out-File "$diagPath\ModuleVerification.txt" -Append
}

# 8. Create ZIP archive
Write-Host "Creating ZIP archive..."
$zipPath = "$diagRoot\$IncidentId.zip"
Compress-Archive -Path $diagPath -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "Diagnostics collected successfully!"
Write-Host "Location: $diagPath"
Write-Host "ZIP archive: $zipPath"
Write-Host ""
Write-Host "Please attach the ZIP file when reporting the incident."
```

### What to Collect for Each Severity

**P0 - Critical:**
- Full diagnostic bundle (all items)
- Screenshots of error messages
- Video recording of crash if reproducible
- Memory dump if available (Windows Error Reporting)

**P1 - High:**
- Full diagnostic bundle
- Screenshots of error messages
- Task Scheduler event logs
- Reproduction steps

**P2 - Medium:**
- Configuration files (tasks.json, app_settings.json)
- Relevant log files only
- Task Scheduler task export
- Reproduction steps

**P3 - Low:**
- Description and screenshots
- Version information
- No full diagnostic needed

### Manual Data Collection Steps

If automated script fails:

```powershell
# 1. Configuration
cd $env:APPDATA\DailyMotivationBrainHelper
Get-ChildItem *.json, *.txt | Copy-Item -Destination C:\IncidentData\

# 2. Logs
Copy-Item $env:TEMP\DailyMotivation_*.log C:\IncidentData\

# 3. Task Scheduler
Get-ScheduledTask -TaskName "DailyMotivation*" | Export-ScheduledTask > C:\IncidentData\Tasks.xml

# 4. System Info
systeminfo > C:\IncidentData\SystemInfo.txt
$PSVersionTable > C:\IncidentData\PSVersion.txt
```

---

## Rollback Procedures

### Scenario 1: Rollback to Previous Application Version

**When to Use:**
- New version introduces critical bug (P0/P1)
- Fix will take > 24 hours
- Users need immediate working version

**Procedure:**

```powershell
# Step 1: Stop all running instances
Get-Process | Where-Object {
    $_.ProcessName -like "*DailyMotivation*" -or
    $_.MainWindowTitle -like "*Daily Motivation*"
} | Stop-Process -Force

# Step 2: Backup current version (for investigation)
$backupPath = "$env:USERPROFILE\Documents\DailyMotivation_Rollback_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupPath -Force
Copy-Item "C:\DailyMotivation" $backupPath -Recurse -Force

# Step 3: Backup configuration (will restore after rollback)
$configBackup = "$env:TEMP\DM_Config_Backup"
New-Item -ItemType Directory -Path $configBackup -Force
Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*.json" $configBackup -Force

# Step 4: Remove current version
Remove-Item "C:\DailyMotivation" -Recurse -Force

# Step 5: Extract previous version
# Download from: https://github.com/SevWren/Daily-Motivation-Brain-Helper/releases
# Example: v1.0.0
Expand-Archive -Path "DailyMotivationBrainHelper_v1.0.0.zip" -DestinationPath "C:\DailyMotivation" -Force

# Step 6: Update modules in %APPDATA%
$src = "C:\DailyMotivation\src\Modules"
$dst = "$env:APPDATA\DailyMotivationBrainHelper\Modules"
Copy-Item "$src\*.psm1" $dst -Force

# Step 7: Restore user configuration (if compatible)
Copy-Item "$configBackup\app_settings.json" "$env:APPDATA\DailyMotivationBrainHelper\" -Force -ErrorAction SilentlyContinue
Copy-Item "$configBackup\tasks.json" "$env:APPDATA\DailyMotivationBrainHelper\" -Force -ErrorAction SilentlyContinue

# Step 8: Verify rollback
C:\DailyMotivation\src\DailyMotivation.exe
# Should launch without errors

# Step 9: Test task execution
Get-ScheduledTask -TaskName "DailyMotivation_*" | Select-Object -First 1 | Start-ScheduledTask
# Wait for popup to appear
```

**Verification Checklist:**
- [ ] Application launches without errors
- [ ] Task list displays correctly
- [ ] Can schedule new task successfully
- [ ] Scheduled task triggers and shows popup
- [ ] Snooze/Dismiss/Open Folder buttons work

**Communication:**
- Notify users of rollback via GitHub issue
- Provide link to previous version
- Set expectation for fix timeline
- Update incident log with rollback timestamp

---

### Scenario 2: Restore Corrupted Configuration

**When to Use:**
- Configuration files corrupted (tasks.json, app_settings.json)
- Application fails to read config
- User reports data loss

**Procedure:**

```powershell
# Step 1: Backup corrupted files for analysis
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
$corruptedBackup = "$env:TEMP\DM_Corrupted_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $corruptedBackup -Force
Copy-Item "$appData\*.json" $corruptedBackup -Force -ErrorAction SilentlyContinue

# Step 2: Check if automatic backup exists
$autoBackupDir = "$env:USERPROFILE\Documents\DailyMotivation_Backup"
if (Test-Path $autoBackupDir) {
    $latestBackup = Get-ChildItem $autoBackupDir | Sort-Object Name -Descending | Select-Object -First 1

    if ($latestBackup) {
        Write-Host "Found backup from: $($latestBackup.Name)"

        # Restore from backup
        Copy-Item "$($latestBackup.FullName)\*.json" $appData -Force
        Write-Host "Configuration restored from backup"
    }
} else {
    Write-Host "No automatic backup found"
}

# Step 3: If no backup, reset to defaults
if (-not $latestBackup) {
    Write-Host "Resetting to default configuration..."

    # Reset app_settings.json
    @{
        firstRun      = $true
        lastFolder    = ""
        recentFolders = @()
        theme         = "dark"
    } | ConvertTo-Json | Set-Content "$appData\app_settings.json" -Encoding UTF8

    # Reset tasks.json
    "[]" | Set-Content "$appData\tasks.json" -Encoding UTF8

    Write-Host "Configuration reset to defaults"
}

# Step 4: Rebuild tasks from Task Scheduler (if possible)
$orphanedTasks = Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue
if ($orphanedTasks) {
    Write-Host "Found $($orphanedTasks.Count) orphaned tasks in Task Scheduler"
    Write-Host "User will need to reschedule these tasks via the app UI"

    # Optionally, attempt to rebuild tasks.json
    # (Note: folder_path is unknown, user must reschedule)
}

# Step 5: Verify restoration
Get-Content "$appData\app_settings.json" | ConvertFrom-Json
Get-Content "$appData\tasks.json" | ConvertFrom-Json
Write-Host "Configuration files verified OK"
```

**Recovery Rate:**
- With automatic backup: 100% recovery
- Without backup: Lose scheduled task details (user must reschedule)

**Prevention:**
- Enable automated backup task (see OPERATIONS.md)
- Implement file locking in ConfigManager.psm1
- Add validation before write operations

---

### Scenario 3: Rollback Task Scheduler Changes

**When to Use:**
- Task Scheduler integration broken after update
- Tasks not triggering correctly
- Need to recreate all tasks from scratch

**Procedure:**

```powershell
# Step 1: Export current tasks for reference
$exportPath = "$env:TEMP\DM_Tasks_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $exportPath -Force

Get-ScheduledTask -TaskName "DailyMotivation_*" | ForEach-Object {
    $_ | Export-ScheduledTask | Out-File "$exportPath\$($_.TaskName).xml"
}

# Step 2: Remove all Daily Motivation tasks
Get-ScheduledTask -TaskName "DailyMotivation*" | Unregister-ScheduledTask -Confirm:$false

# Step 3: Clear tasks.json
"[]" | Set-Content "$env:APPDATA\DailyMotivationBrainHelper\tasks.json" -Encoding UTF8

# Step 4: Recreate placeholder task (if needed)
cd C:\DailyMotivation\src
.\UpdateScheduledTask.ps1

# Step 5: User must reschedule all tasks via app UI
Write-Host "Task Scheduler reset complete"
Write-Host "Users must reschedule tasks via the application UI"
```

**User Impact:**
- All scheduled tasks deleted
- User must reschedule manually
- No data loss (folder paths stored in tasks.json if not corrupted)

**Communication:**
- Provide step-by-step reschedule instructions
- Offer to assist with bulk rescheduling if many tasks affected

---

## User Communication

### Communication Channels

**Primary:**
- GitHub Issues: https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues
- Create issue with appropriate label and severity

**Secondary:**
- README.md (update with known issues section if needed)
- CHANGELOG.md (document incident and fix in next release)

### Incident Notification Templates

#### P0 - Critical Incident

**Subject:** [CRITICAL] Daily Motivation Brain Helper - Application Down

**Template:**
```markdown
## Critical Incident Notice

**Incident ID:** INC-20260609-143000
**Severity:** P0 - Critical
**Status:** INVESTIGATING
**Reported:** 2026-06-09 14:30 UTC

### Issue
The Daily Motivation Brain Helper application is experiencing a critical failure that prevents startup for all users on Windows 11 build 22000+.

### Impact
- Application crashes immediately on launch
- All users on Windows 11 affected
- Estimated users impacted: [number]

### Current Status
We are actively investigating the root cause. Initial diagnosis suggests a module import failure related to PowerShell version differences.

### Workaround
None available at this time.

### Next Update
We will provide an update within 2 hours or sooner if a fix is deployed.

### Action Required
No action required from users. We will notify when a fix is available.

---
**Last Updated:** 2026-06-09 14:30 UTC
**Incident Commander:** [Name]
```

#### P1 - High Priority Incident

**Subject:** [HIGH] Daily Motivation Brain Helper - Scheduled Tasks Not Running

**Template:**
```markdown
## High Priority Incident

**Incident ID:** INC-20260609-090000
**Severity:** P1 - High
**Status:** FIX IN PROGRESS
**Reported:** 2026-06-09 09:00 UTC

### Issue
Scheduled tasks are not triggering at the specified time. Tasks show as "Ready" in Task Scheduler but popups do not appear.

### Impact
- Users not receiving scheduled reminders
- Affects all scheduled tasks created after 2026-06-08
- Estimated users impacted: [number or percentage]

### Root Cause
Task Scheduler action path was incorrectly set in version 1.1.1, causing LaunchMotivation.bat to fail silently.

### Workaround
**Temporary Fix (Manual):**
1. Open Task Scheduler (taskschd.msc)
2. Find tasks starting with "DailyMotivation_"
3. Edit each task → Actions tab
4. Verify action is: `cmd.exe /c "C:\DailyMotivation\src\LaunchMotivation.bat"`
5. If different, correct the path and save

### Fix Status
- **ETA:** 4 hours (by 2026-06-09 13:00 UTC)
- **Version:** v1.1.2 hotfix
- **Deployment:** Automatic update via GitHub release

### Next Steps
1. Download v1.1.2 when released
2. Existing tasks will be automatically repaired
3. No user action required after update

---
**Last Updated:** 2026-06-09 11:00 UTC
```

#### P2 - Medium Priority Incident

**Subject:** [MEDIUM] Daily Motivation Brain Helper - WPF Display Issues on Some Systems

**Template:**
```markdown
## Medium Priority Issue

**Issue ID:** INC-20260609-160000
**Severity:** P2 - Medium
**Reported:** 2026-06-09 16:00 UTC

### Issue
Popup window displays with garbled text or missing elements on systems with high DPI scaling (> 150%).

### Impact
- Popup window displays incorrectly
- Functionality still works (buttons are clickable)
- Affects users with 4K displays or high DPI settings
- Estimated impact: < 10% of users

### Root Cause
WPF layout not properly handling DPI scaling on certain display configurations.

### Workaround
**Temporary Fix:**
Reduce display scaling to 125% or lower:
1. Right-click Desktop → Display Settings
2. Scale and layout → Change to 125%
3. Sign out and sign back in

Or continue using app despite visual issues (functionality unaffected).

### Fix Schedule
- Scheduled for next release: v1.2.0
- **ETA:** 2 weeks (2026-06-23)
- Will include proper DPI awareness configuration

### Tracking
Follow progress on GitHub: [link to issue]

---
**Last Updated:** 2026-06-09 16:30 UTC
```

#### Incident Resolution Notification

**Subject:** [RESOLVED] Daily Motivation Brain Helper - Issue Fixed

**Template:**
```markdown
## Incident Resolved

**Incident ID:** INC-20260609-143000
**Severity:** P0 - Critical
**Status:** RESOLVED
**Resolution Time:** 3 hours 45 minutes

### Issue
Application crash on startup for Windows 11 users (see original notification for details).

### Resolution
**Fix deployed in:** v1.1.3 (released 2026-06-09 18:15 UTC)

**Root Cause:**
Module import path resolution failed due to $PSScriptRoot being empty when compiled with PS2EXE. This was a known issue but regression was introduced in v1.1.2.

**Fix:**
Updated MainApp.ps1 to use fallback path resolution:
```powershell
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
} else {
    $scriptPath = $PSScriptRoot
}
```

### Verification
- Tested on Windows 10 (build 19045) and Windows 11 (build 22621)
- All manual test cases passed (TC-001 through TC-020)
- No regressions detected

### Action Required
**All users should update to v1.1.3:**
1. Download from: [GitHub release link]
2. Extract to C:\DailyMotivation (overwrite existing files)
3. Run setup: Right-click UpdateScheduledTask.ps1 → Run as Administrator
4. Launch application to verify

### Prevention
- Added pre-flight path check to startup
- Enhanced CI testing for PS2EXE compiled versions
- Updated TROUBLESHOOTING.md with this scenario

### Apology
We apologize for the disruption caused by this issue. We have implemented additional safeguards to prevent similar issues in future releases.

Thank you for your patience.

---
**Incident closed:** 2026-06-09 18:30 UTC
**Post-mortem:** Will be published within 48 hours
```

---

## Post-Mortem Process

### Timeline

- **Within 24 hours:** Initial incident review
- **Within 48 hours:** Full post-mortem document
- **Within 1 week:** Action items assigned and tracked

### Post-Mortem Document Template

**File:** `docs/post-mortems/YYYYMMDD-incident-brief-description.md`

```markdown
# Post-Mortem: [Brief Description]

**Incident ID:** INC-YYYYMMDD-HHMMSS
**Date:** YYYY-MM-DD
**Author:** [Name]
**Severity:** P0/P1/P2
**Duration:** [X hours Y minutes]

---

## Executive Summary

[One paragraph summary of what happened, impact, and resolution]

## Timeline

**All times in UTC**

| Time | Event |
|------|-------|
| 14:00 | First user report of issue |
| 14:15 | Issue confirmed by team |
| 14:30 | Incident declared P0, investigation started |
| 15:00 | Root cause identified |
| 16:00 | Fix developed and tested |
| 17:00 | Hotfix v1.1.3 released |
| 18:00 | Fix verified on user systems |
| 18:30 | Incident resolved |

## Root Cause Analysis

### What Happened
[Detailed technical explanation of what went wrong]

### Why It Happened
[Analysis of underlying factors that allowed this to occur]

### How It Was Fixed
[Technical details of the fix]

## Impact

- **Users affected:** [number/percentage]
- **Duration:** [X hours]
- **Data loss:** None / [description]
- **Workaround available:** Yes/No

## Detection

- **How was it detected?** [User report / Monitoring / etc.]
- **Time to detect:** [X minutes from occurrence]
- **Could we have detected it sooner?** [Yes/No, explanation]

## Response

- **Time to acknowledge:** [X minutes]
- **Time to fix:** [X hours]
- **What went well:**
  - [Item 1]
  - [Item 2]

- **What could be improved:**
  - [Item 1]
  - [Item 2]

## Action Items

| ID | Description | Owner | Due Date | Status |
|----|-------------|-------|----------|--------|
| AI-001 | Add pre-flight path validation | [Name] | YYYY-MM-DD | Open |
| AI-002 | Update CI to test PS2EXE compilation | [Name] | YYYY-MM-DD | Open |
| AI-003 | Document $PSScriptRoot fallback pattern | [Name] | YYYY-MM-DD | Open |

## Lessons Learned

### What Worked
- [Item 1]
- [Item 2]

### What Didn't Work
- [Item 1]
- [Item 2]

### Improvements for Next Time
- [Item 1]
- [Item 2]

---

**Post-mortem reviewed:** YYYY-MM-DD
**Reviewers:** [Name 1], [Name 2]
```

---

## Root Cause Analysis

### 5 Whys Technique

**Example: Module Import Failure**

1. **Why did the application crash on startup?**
   - Because ConfigManager.psm1 could not be imported

2. **Why could the module not be imported?**
   - Because the module path was incorrect ($PSScriptRoot was empty)

3. **Why was $PSScriptRoot empty?**
   - Because the application was compiled with PS2EXE, which doesn't set $PSScriptRoot

4. **Why didn't we catch this before release?**
   - Because our test suite runs the .ps1 scripts directly, not the compiled .exe

5. **Why don't we test the compiled version?**
   - Because CI pipeline doesn't include post-compilation testing step

**Root Cause:** Lack of automated testing for PS2EXE compiled binaries

**Fix:** Add CI step to test compiled .exe files before release

### Fishbone Diagram Categories

When analyzing incidents, consider these categories:

**People:**
- Training gaps
- Communication failures
- Insufficient staffing

**Process:**
- Missing steps in workflow
- Inadequate testing procedures
- Lack of validation gates

**Technology:**
- Tool limitations
- Platform differences
- Third-party dependencies

**Environment:**
- Configuration drift
- External service failures
- Security policy changes

### Root Cause Documentation

**Required Fields:**
- Immediate cause (what directly caused the failure)
- Contributing factors (what allowed it to happen)
- Underlying root cause (systemic issue)
- Evidence (logs, screenshots, test results)

**Template:**
```markdown
## Root Cause Analysis

**Immediate Cause:**
[What directly triggered the failure]

**Contributing Factors:**
1. [Factor 1 - e.g., missing validation]
2. [Factor 2 - e.g., test gap]
3. [Factor 3 - e.g., documentation unclear]

**Underlying Root Cause:**
[Systemic issue that allowed contributing factors to exist]

**Evidence:**
- [Link to log file showing error]
- [Screenshot of failure]
- [Test result demonstrating gap]

**Verification:**
[How root cause was confirmed - e.g., fix resolves issue when root cause addressed]
```

---

## Prevention Measures

### Pre-Release Prevention

**1. Comprehensive Testing**
```powershell
# Add to .build.ps1 Release task

# Test compiled executables (not just scripts)
task TestCompiledEXE {
    Write-Build Green "Testing compiled executables..."

    # Test MainApp.exe
    $mainAppExe = Join-Path $Config.OutputPath 'DailyMotivationBrainHelper.exe'
    $testResult = Start-Process $mainAppExe -ArgumentList "/test" -PassThru -Wait
    assert ($testResult.ExitCode -eq 0) "MainApp.exe test failed"

    # Test DailyMotivation.exe (popup)
    $popupExe = Join-Path $Config.OutputPath 'DailyMotivation.exe'
    # (Add similar test)
}
```

**2. Pre-Flight Checks**
```powershell
# Add to MainApp.ps1 startup

function Test-Prerequisites {
    $issues = @()

    # Check modules exist
    $modulePath = "$env:APPDATA\DailyMotivationBrainHelper\Modules"
    if (-not (Test-Path "$modulePath\ConfigManager.psm1")) {
        $issues += "ConfigManager.psm1 missing from $modulePath"
    }
    if (-not (Test-Path "$modulePath\TaskScheduler.psm1")) {
        $issues += "TaskScheduler.psm1 missing from $modulePath"
    }

    # Check configuration directory
    $appData = "$env:APPDATA\DailyMotivationBrainHelper"
    if (-not (Test-Path $appData)) {
        $issues += "Configuration directory missing: $appData"
    }

    # Check Task Scheduler service
    $service = Get-Service -Name Schedule -ErrorAction SilentlyContinue
    if ($service.Status -ne 'Running') {
        $issues += "Task Scheduler service not running"
    }

    if ($issues.Count -gt 0) {
        $message = "Pre-flight checks failed:`n`n" + ($issues -join "`n")
        [System.Windows.MessageBox]::Show($message, "Setup Required", "OK", "Error")
        exit 1
    }
}

# Call at startup
Test-Prerequisites
```

**3. Configuration Validation**
```powershell
# Add to ConfigManager.psm1

function Test-JsonValid {
    param([string]$Path)

    try {
        $content = Get-Content $Path -Raw -ErrorAction Stop
        $json = $content | ConvertFrom-Json -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "Invalid JSON in $Path: $_"
        return $false
    }
}

function Save-AppSettings {
    param($Settings)

    $path = Get-ConfigPath 'app_settings.json'

    # Backup existing file
    if (Test-Path $path) {
        $backupPath = "$path.backup"
        Copy-Item $path $backupPath -Force
    }

    try {
        # Save new file
        $Settings | ConvertTo-Json -Depth 4 | Set-Content $path -Encoding UTF8

        # Validate saved file
        if (-not (Test-JsonValid $path)) {
            # Restore backup
            if (Test-Path $backupPath) {
                Copy-Item $backupPath $path -Force
            }
            throw "Saved JSON is invalid, restored from backup"
        }

    } catch {
        throw "Failed to save app_settings.json: $_"
    }
}
```

### Runtime Prevention

**4. Defensive Programming**
```powershell
# Example: Task creation with validation

function New-MotivationTask {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$FolderPath,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ -gt (Get-Date) })]
        [datetime]$ScheduledTime
    )

    # Input validated by parameter attributes
    # Proceed with task creation...
}
```

**5. Mutex Enforcement**
```powershell
# In DailyMotivation.ps1 - already implemented
# Ensure only one popup instance runs

$mutexName = "Global\DailyMotivationBrainHelper_SingleInstance"
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)

if (-not $createdNew) {
    Write-Host "Another instance is already running. Exiting."
    exit 0
}
```

**6. Error Logging**
```powershell
# Centralized error logging

function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$Exception = "",
        [string]$Component = "Unknown"
    )

    $logPath = "$env:TEMP\DailyMotivation_error.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $logEntry = @"
[$timestamp] [$Component] ERROR
Message: $Message
Exception: $Exception
User: $env:USERNAME
Machine: $env:COMPUTERNAME
PS Version: $($PSVersionTable.PSVersion)
---
"@

    Add-Content -Path $logPath -Value $logEntry
}

# Usage:
try {
    # Some operation
} catch {
    Write-ErrorLog -Message "Failed to load config" -Exception $_.Exception.Message -Component "ConfigManager"
    throw
}
```

### Monitoring and Detection

**7. Health Check Script**

Create `scripts/Health-Check.ps1`:

```powershell
# Run this daily via Task Scheduler to detect issues early

$issues = @()

# Check 1: Task Scheduler service
$service = Get-Service -Name Schedule
if ($service.Status -ne 'Running') {
    $issues += "Task Scheduler service is not running"
}

# Check 2: Scheduled tasks exist and are enabled
$tasks = Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue
$disabledTasks = $tasks | Where-Object { $_.State -eq 'Disabled' }
if ($disabledTasks) {
    $issues += "Found $($disabledTasks.Count) disabled tasks"
}

# Check 3: Configuration files are valid JSON
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
foreach ($file in @('app_settings.json', 'tasks.json', 'popup_config.json')) {
    $path = Join-Path $appData $file
    if (Test-Path $path) {
        try {
            Get-Content $path -Raw | ConvertFrom-Json | Out-Null
        } catch {
            $issues += "Invalid JSON in $file"
        }
    }
}

# Check 4: Log files not too large
$logFiles = Get-ChildItem "$appData\*.log", "$appData\*.txt" -ErrorAction SilentlyContinue
$largeFiles = $logFiles | Where-Object { $_.Length -gt 10MB }
if ($largeFiles) {
    $issues += "Found $($largeFiles.Count) log files > 10MB (should rotate)"
}

# Report results
if ($issues.Count -gt 0) {
    $report = "Daily Motivation Health Check - Issues Found:`n`n" + ($issues -join "`n")

    # Log to file
    $report | Out-File "$env:TEMP\DM_HealthCheck_$(Get-Date -Format 'yyyyMMdd').txt"

    # Optionally: Send email/notification
    Write-Warning $report
} else {
    Write-Host "Daily Motivation Health Check - All OK"
}
```

**8. Automated Alerts**

For enterprise deployments, configure monitoring:

```powershell
# Example: Monitor Task Scheduler event log for failures

$eventFilter = @{
    LogName   = 'Microsoft-Windows-TaskScheduler/Operational'
    ID        = 203  # Task action failed
    StartTime = (Get-Date).AddHours(-1)
}

$failedTasks = Get-WinEvent -FilterHashtable $eventFilter -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like "*DailyMotivation*" }

if ($failedTasks) {
    # Alert: Task failures detected
    $alertMessage = "Detected $($failedTasks.Count) Daily Motivation task failures in the last hour"
    # Send to monitoring system
}
```

### Documentation Prevention

**9. Keep Documentation Updated**

After each incident:
- [ ] Update TROUBLESHOOTING.md with new scenario
- [ ] Add to Common Incidents section above
- [ ] Update RISK_REGISTER.md with new risks
- [ ] Document prevention in this file
- [ ] Update TEST_PLAN.md with new test case

**10. Review Cycle**

Schedule regular reviews:
- **Monthly:** Review open incidents, update procedures
- **Quarterly:** Review RISK_REGISTER.md, update mitigations
- **After Each Release:** Review INCIDENT_RESPONSE.md for improvements
- **Annual:** Full documentation review and update

---

## Appendix A: Quick Reference Cards

### P0 Response Card

**Print and keep near workstation**

```
╔═══════════════════════════════════════════════════════════╗
║         P0 CRITICAL INCIDENT RESPONSE CARD                ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║ 1. ACKNOWLEDGE (0-15 min)                                ║
║    □ Create incident log: INC-YYYYMMDD-HHMMSS           ║
║    □ Post status update on GitHub                        ║
║    □ Label: P0-CRITICAL                                  ║
║                                                           ║
║ 2. ASSESS (15-30 min)                                    ║
║    □ How many users affected?                            ║
║    □ Which versions/platforms?                           ║
║    □ Data loss risk?                                     ║
║                                                           ║
║ 3. COLLECT DATA (30-60 min)                             ║
║    □ Run: .\Collect-Diagnostics.ps1                     ║
║    □ Check Event Viewer logs                            ║
║    □ Reproduce on test machine                          ║
║                                                           ║
║ 4. FIX (1-4 hours)                                       ║
║    □ Develop hotfix                                      ║
║    □ Test thoroughly                                     ║
║    □ Prepare rollback plan                              ║
║    □ Deploy fix                                          ║
║                                                           ║
║ 5. VERIFY (4-24 hours)                                   ║
║    □ Test on affected systems                           ║
║    □ Monitor for 24 hours                               ║
║    □ Post resolution notice                             ║
║    □ Schedule post-mortem                               ║
║                                                           ║
║ ESCALATION:                                              ║
║    Security issues: mmueller07@gmail.com                 ║
║    GitHub: /SevWren/Daily-Motivation-Brain-Helper       ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

### Diagnostic Collection Card

```
╔═══════════════════════════════════════════════════════════╗
║           DIAGNOSTIC COLLECTION CHECKLIST                 ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║ AUTOMATED COLLECTION:                                     ║
║   powershell .\Collect-Diagnostics.ps1                   ║
║                                                           ║
║ MANUAL COLLECTION (if script fails):                     ║
║   □ Configuration files:                                 ║
║     %APPDATA%\DailyMotivationBrainHelper\*.json         ║
║                                                           ║
║   □ Log files:                                           ║
║     %APPDATA%\DailyMotivationBrainHelper\*.txt          ║
║     %TEMP%\DailyMotivation_*.log                        ║
║                                                           ║
║   □ Task Scheduler tasks:                                ║
║     Get-ScheduledTask -TaskName "DailyMotivation_*" |   ║
║       Export-ScheduledTask > tasks.xml                   ║
║                                                           ║
║   □ System info:                                         ║
║     systeminfo > systeminfo.txt                          ║
║     $PSVersionTable > psversion.txt                      ║
║                                                           ║
║   □ Event Viewer logs:                                   ║
║     TaskScheduler/Operational                            ║
║     Windows PowerShell                                   ║
║                                                           ║
║ OUTPUT LOCATION:                                          ║
║   Desktop\DailyMotivation_Diagnostics\[timestamp]        ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

---

## Appendix B: Contact Information

**Primary Contacts:**

| Role | Name | Email | GitHub |
|------|------|-------|--------|
| Lead Developer | [Name] | [email] | @username |
| Security Contact | [Name] | mmueller07@gmail.com | @SevWren |

**Escalation Path:**
1. Developer (P3, most P2)
2. Lead Developer (P1, P2)
3. Security Contact (security incidents only)

**External Resources:**
- GitHub Issues: https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues
- Documentation: /docs/
- Support Email: mmueller07@gmail.com

---

**End of Incident Response Procedures**

**Document Control:**
- **Created:** 2026-06-09
- **Last Updated:** 2026-06-09
- **Next Review:** 2026-09-09 (quarterly)
- **Owner:** Development Team
- **Version:** 1.0
