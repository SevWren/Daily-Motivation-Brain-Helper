# Troubleshooting Guide

**Last Updated:** 2026-06-09
**Version:** 1.1
**Status:** Official Support Documentation

---

## Table of Contents

1. [Common Issues and Solutions](#common-issues-and-solutions)
2. [WPF Crashes (STA Thread Issues)](#wpf-crashes-sta-thread-issues)
3. [Module Not Found Errors](#module-not-found-errors)
4. [Scheduled Task Failures](#scheduled-task-failures)
5. [JSON Parsing Errors](#json-parsing-errors)
6. [UAC and Permissions Issues](#uac-and-permissions-issues)
7. [Debug Procedures](#debug-procedures)
8. [Log File Locations](#log-file-locations)

---

## Common Issues and Solutions

### Issue: Application Won't Launch

**Symptoms:**
- Double-clicking MainApp.ps1 does nothing
- No window appears
- No error message

**Cause:** PowerShell execution policy blocking script execution

**Solution:**
```powershell
# Option 1: Launch with bypass flag (recommended)
powershell.exe -ExecutionPolicy Bypass -STA -File "C:\DailyMotivation\src\MainApp.ps1"

# Option 2: Set execution policy for current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Option 3: Use compiled EXE (if available)
C:\DailyMotivation\src\DailyMotivation.exe
```

**Prevention:** Always launch via batch file or with `-ExecutionPolicy Bypass` flag.

---

### Issue: "Module not found" Error on Startup

**Symptoms:**
- Error dialog: "Required modules failed to load"
- App exits immediately after launch

**Cause:** Modules not present in `%APPDATA%\DailyMotivationBrainHelper\Modules\`

**Solution:**
```powershell
# Re-run initial setup script as Administrator
cd C:\DailyMotivation\src
Right-click UpdateScheduledTask.ps1 → "Run with PowerShell"

# Or manually copy modules:
$src = "C:\DailyMotivation\src\Modules"
$dst = "$env:APPDATA\DailyMotivationBrainHelper\Modules"
New-Item -ItemType Directory -Path $dst -Force
Copy-Item "$src\*.psm1" $dst -Force
```

**Verification:**
```powershell
Test-Path "$env:APPDATA\DailyMotivationBrainHelper\Modules\ConfigManager.psm1"
Test-Path "$env:APPDATA\DailyMotivationBrainHelper\Modules\TaskScheduler.psm1"
# Both should return: True
```

---

### Issue: Popup Doesn't Appear at Scheduled Time

**Symptoms:**
- Task shows "Ready" in Task Scheduler
- Scheduled time passes, no popup
- No error in Event Viewer

**Diagnosis:**
```powershell
# Check task status
Get-ScheduledTask -TaskName "DailyMotivation_*" |
  Select-Object TaskName, State, LastRunTime, NextRunTime

# Check Task Scheduler service
Get-Service -Name Schedule | Select-Object Status, StartType
```

**Common Causes:**

1. **Task Scheduler service not running**
   ```powershell
   Start-Service Schedule
   ```

2. **User not logged in at trigger time**
   - Task requires Interactive logon (user must be logged in)
   - Solution: Use `StartWhenAvailable` setting (default)

3. **System time incorrect**
   ```powershell
   Get-Date
   # Verify time matches expected trigger time
   ```

4. **Task was disabled**
   ```powershell
   Get-ScheduledTask -TaskName "DailyMotivation_*" |
     Where-Object State -eq "Disabled" |
     Enable-ScheduledTask
   ```

---

### Issue: Multiple Popups Appearing Simultaneously

**Symptoms:**
- Two or more popup windows open at once
- Named mutex not preventing duplicates

**Cause:** Mutex acquisition race condition or stale processes

**Immediate Fix:**
```powershell
# Kill all popup processes
Get-Process | Where-Object {
  $_.ProcessName -like "*DailyMotivation*" -or
  $_.MainWindowTitle -like "*Daily Motivation*"
} | Stop-Process -Force
```

**Root Cause Investigation:**
```powershell
# Check debug log for mutex messages
Get-Content "$env:TEMP\DailyMotivation_debug.log" |
  Select-String "mutex"

# Expected: "Mutex acquired"
# If: "Mutex already held" → mutex working correctly
# If: "Mutex error" → investigate exception
```

**Prevention:**
- Named mutex implemented in `DailyMotivation.ps1` lines 45-74
- If issue persists, check for stale mutex handles:
  ```powershell
  # Restart computer to clear all mutex handles
  Restart-Computer
  ```

---

### Issue: "Folder was moved or deleted" Message (False Positive)

**Symptoms:**
- Popup shows path error even though folder exists
- Folder accessible in Explorer

**Cause:** Network drive disconnected or UNC path authentication

**Solution:**
```powershell
# Test path accessibility from PowerShell
Test-Path "\\server\share\folder"

# For network drives, ensure they're mapped:
Get-PSDrive -PSProvider FileSystem

# Re-map disconnected drive:
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\server\share" -Persist
```

**For UNC Paths:**
- Task Scheduler may run without network credentials
- Solution: Task automatically uses `RunLevel Highest` for network paths
- Manual fix if needed:
  ```powershell
  # Re-create task with Highest privilege
  # (App does this automatically for paths starting with \\)
  ```

---

### Issue: Application Prompts for Admin Password Every Time

**Symptoms:**
- UAC prompt appears on every launch
- "Do you want to allow this app to make changes?" dialog

**Cause:** Application incorrectly compiled with `-requireAdmin` flag

**Solution:**
```powershell
# Check EXE manifest:
# If compiled with requireAdmin, rebuild without it

# Rebuild from source:
cd C:\DailyMotivation
Invoke-Build

# Or use PowerShell launcher instead:
powershell.exe -ExecutionPolicy Bypass -STA -File "C:\DailyMotivation\src\MainApp.ps1"
```

**Prevention:**
- MainApp.ps1 and DailyMotivation.ps1 do NOT require admin
- Only UpdateScheduledTask.ps1 requires admin (one-time setup)
- Verify `.build.ps1` line 136: `RequireAdmin = $false`

---

### Issue: Scheduled Task Shows "Not Scheduled" in App

**Symptoms:**
- Task created successfully in Task Scheduler
- App's task list shows empty or outdated

**Cause:** Desynchronization between tasks.json and Task Scheduler

**Solution:**
```powershell
# Rebuild tasks.json from Task Scheduler
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
$tasks = @()

Get-ScheduledTask -TaskName "DailyMotivation_*" | ForEach-Object {
    $taskInfo = Get-ScheduledTaskInfo -TaskName $_.TaskName
    $tasks += [PSCustomObject]@{
        task_id        = $_.TaskName -replace '^DailyMotivation_', ''
        task_name      = $_.TaskName
        folder_path    = ""  # Unknown - user must reschedule
        folder_name    = ""
        scheduled_time = $taskInfo.NextRunTime.ToString("o")
        created_at     = (Get-Date -Format "o")
        status         = "PENDING"
        snooze_count   = 0
        snooze_duration_minutes = 5
    }
}

$tasks | ConvertTo-Json -Depth 4 | Set-Content "$appData\tasks.json" -Encoding UTF8
```

**Prevention:** Always use app UI to manage tasks, not Task Scheduler directly.

---

## WPF Crashes (STA Thread Issues)

### Error: "Current thread must be STA"

**Full Error Message:**
```
Exception calling "Load" with "1" argument(s): "The calling thread must be STA, because many UI components require this."
```

**Cause:** PowerShell launched in MTA (Multi-Threaded Apartment) mode

**Solution:**
```powershell
# Always launch with -STA flag
powershell.exe -STA -ExecutionPolicy Bypass -File "script.ps1"

# Check current threading model:
[System.Threading.Thread]::CurrentThread.GetApartmentState()
# Must return: STA
```

**In LaunchMotivation.bat:**
- Line 53: `-STA` flag already present
- If error persists, verify batch file not modified

**In Task Scheduler:**
- Action must use batch wrapper (LaunchMotivation.bat)
- Direct PowerShell execution may not set STA mode correctly

---

### Error: "The invocation of the constructor on type 'System.Windows.Window' failed"

**Symptoms:**
- App crashes during window initialization
- Error in XAML parsing

**Cause:** Corrupted or missing MainWindow.xaml

**Diagnosis:**
```powershell
$xamlPath = "C:\DailyMotivation\src\MainWindow.xaml"
Test-Path $xamlPath  # Must be True

# Validate XML syntax:
[xml]$xaml = Get-Content $xamlPath -Raw -Encoding UTF8
# Should not throw exception
```

**Solution:**
```powershell
# Restore from installation ZIP
Expand-Archive -Path "DailyMotivationBrainHelper_Release.zip" -DestinationPath "$env:TEMP\DM_Restore"
Copy-Item "$env:TEMP\DM_Restore\src\MainWindow.xaml" "C:\DailyMotivation\src\" -Force
```

---

### Error: "Unable to cast object of type 'System.Windows.Controls.Grid' to type 'System.Windows.Window'"

**Symptoms:**
- App crashes after XAML load
- Error: "GAP-005: validate the loaded object is actually a Window"

**Cause:** XAML root element is not `<Window>`

**Solution:**
```powershell
# Check XAML structure:
$xaml = Get-Content "C:\DailyMotivation\src\MainWindow.xaml" -Raw
if ($xaml -match '<Window') {
    Write-Host "XAML root is Window - OK"
} else {
    Write-Host "XAML root is NOT Window - corrupted file"
    # Restore from backup
}
```

**Prevention:** Do not manually edit MainWindow.xaml.

---

## Module Not Found Errors

### Error: "The specified module 'ConfigManager' was not loaded"

**Symptoms:**
- Import-Module fails
- Error during app startup

**Diagnosis:**
```powershell
# Check module location
$modulePath = "$env:APPDATA\DailyMotivationBrainHelper\Modules\ConfigManager.psm1"
Test-Path $modulePath

# Check module syntax:
Get-Content $modulePath | Out-Null
# Should not throw parse errors
```

**Common Causes:**

1. **Module file missing**
   ```powershell
   # Re-copy from source
   Copy-Item "C:\DailyMotivation\src\Modules\*.psm1" `
             "$env:APPDATA\DailyMotivationBrainHelper\Modules\" -Force
   ```

2. **Module file corrupted (UTF-8 BOM issues)**
   ```powershell
   # Check encoding:
   $bytes = [System.IO.File]::ReadAllBytes($modulePath)
   if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
       Write-Host "UTF-8 with BOM - OK"
   } else {
       Write-Host "Encoding issue - restore from source"
   }
   ```

3. **$PSScriptRoot resolution failure (PS2EXE issue)**
   - Issue #3 in GitHub: $PSScriptRoot returns empty string when compiled
   - Fixed in MainApp.ps1 lines 33-41 (fallback to $MyInvocation.MyCommand.Path)
   - Verify fix present:
     ```powershell
     Get-Content "C:\DailyMotivation\src\MainApp.ps1" |
       Select-String "PSScriptRoot" -Context 0,5
     ```

---

### Error: "Import-Module: Access to the path is denied"

**Symptoms:**
- Module file exists but can't be loaded
- Permission error

**Cause:** File permissions restrictive or file locked by antivirus

**Solution:**
```powershell
# Check permissions
$modulePath = "$env:APPDATA\DailyMotivationBrainHelper\Modules\ConfigManager.psm1"
Get-Acl $modulePath | Format-List

# Reset permissions:
$acl = Get-Acl $modulePath
$acl.SetAccessRuleProtection($false, $true)  # Inherit from parent
Set-Acl $modulePath $acl

# Check for file locks:
$file = Get-Item $modulePath
$stream = $file.OpenWrite()
try {
    $stream.Close()
    Write-Host "File not locked"
} catch {
    Write-Host "File locked by another process: $_"
}
```

**If Antivirus Blocking:**
- Add exclusion for `%APPDATA%\DailyMotivationBrainHelper\`
- Whitelist process: `powershell.exe` (for this app)

---

## Scheduled Task Failures

### Task Shows "Last Run Result: 0x1" (Error)

**Meaning:** Task started but script exited with error code 1

**Diagnosis:**
```powershell
# Check launcher log
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\launch_log.txt" -Tail 50

# Check PowerShell stderr log
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\launch_ps.log" -Tail 50

# Check Event Viewer
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-TaskScheduler/Operational'
    StartTime = (Get-Date).AddHours(-1)
} | Where-Object { $_.Message -like "*DailyMotivation*" }
```

**Common Causes:**

1. **LaunchMotivation.bat path incorrect**
   ```powershell
   $task = Get-ScheduledTask -TaskName "DailyMotivation_*" | Select-Object -First 1
   $action = $task.Actions[0]
   Write-Host "Action: $($action.Execute) $($action.Arguments)"

   # Should be: cmd.exe /c "C:\DailyMotivation\src\LaunchMotivation.bat"
   # If path wrong, recreate task via app UI
   ```

2. **PowerShell not found**
   ```powershell
   Get-Command powershell.exe
   # Should return: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
   ```

3. **DailyMotivation.ps1 missing**
   ```powershell
   Test-Path "C:\DailyMotivation\src\DailyMotivation.ps1"
   # Must be True
   ```

---

### Task Shows "Last Run Result: 0x41301" (Task Not Scheduled)

**Meaning:** Task disabled or trigger condition not met

**Solution:**
```powershell
# Enable task
Get-ScheduledTask -TaskName "DailyMotivation_*" | Enable-ScheduledTask

# Check trigger conditions
$task = Get-ScheduledTask -TaskName "DailyMotivation_*" | Select-Object -First 1
$task.Triggers | Format-List

# Verify trigger time not in past
$taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName
$taskInfo.NextRunTime
# Should be future datetime
```

---

### Task Shows "Last Run Result: 0xC0000142" (Application Initialization Error)

**Meaning:** PowerShell or .NET runtime failed to initialize

**Diagnosis:**
```powershell
# Test PowerShell manually
powershell.exe -STA -NoProfile -Command "Write-Host 'Test OK'"

# Check .NET Framework
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
  Get-ItemProperty -Name Version -EA 0 |
  Where-Object { $_.PSChildName -match '^(?!S)\p{L}'} |
  Select-Object PSChildName, Version
```

**Solution:**
- Repair .NET Framework via Control Panel → Programs → Turn Windows features on/off
- Or reinstall: https://dotnet.microsoft.com/download/dotnet-framework

---

### Task Runs But Popup Disappears Immediately

**Symptoms:**
- Task shows "Last Run Result: 0x0" (success)
- No popup window visible
- Debug log shows script started

**Diagnosis:**
```powershell
# Check debug log
Get-Content "$env:TEMP\DailyMotivation_debug.log"

# Look for:
# - "Mutex acquired" → mutex working
# - "XAML loaded" → UI initialized
# - Exit before window shown → exception in window logic
```

**Common Causes:**

1. **Exception in popup_config.json parsing**
   ```powershell
   $config = Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_config.json" -Raw
   $config | ConvertFrom-Json
   # Should not throw exception
   ```

2. **Uncaught exception before window.ShowDialog()**
   ```powershell
   # Check error log
   Get-Content "$env:TEMP\DailyMotivation_error.log"
   ```

3. **Window hidden by other applications**
   - Popup should be Topmost (WPF property)
   - Check if popup is minimized:
     ```powershell
     Get-Process | Where-Object MainWindowTitle -like "*Daily Motivation*" |
       Select-Object MainWindowHandle, @{N='Visible';E={$_.MainWindowHandle -ne 0}}
     ```

---

## JSON Parsing Errors

### Error: "Invalid JSON primitive"

**Symptoms:**
- Config files unreadable
- App shows error dialog on startup

**Diagnosis:**
```powershell
$appData = "$env:APPDATA\DailyMotivationBrainHelper"

# Test each JSON file:
Get-Content "$appData\app_settings.json" -Raw | ConvertFrom-Json
Get-Content "$appData\tasks.json" -Raw | ConvertFrom-Json
Get-Content "$appData\popup_config.json" -Raw | ConvertFrom-Json
```

**Common Causes:**

1. **Trailing commas** (not valid JSON)
   ```json
   {
     "lastFolder": "C:\\Path",
     "theme": "dark",  ← REMOVE THIS COMMA
   }
   ```

2. **Unescaped backslashes in paths**
   ```json
   {
     "lastFolder": "C:\Path"  ← WRONG
     "lastFolder": "C:\\Path" ← CORRECT
   }
   ```

3. **Corrupted by manual editing**
   - Reset to defaults:
     ```powershell
     Remove-Item "$env:APPDATA\DailyMotivationBrainHelper\*.json" -Force
     # Restart app to reinitialize
     ```

---

### Error: "Cannot convert 'null' to type 'System.Object[]'"

**Symptoms:**
- Error when reading tasks.json
- tasks.json contains `null` instead of `[]`

**Cause:** PowerShell 5.1 ConvertFrom-Json returns $null for empty arrays

**Solution:**
- Fixed in TaskScheduler.psm1 lines 18-20 (FIX-003)
- If error persists, manually reset tasks.json:
  ```powershell
  "[]" | Set-Content "$env:APPDATA\DailyMotivationBrainHelper\tasks.json" -Encoding UTF8
  ```

---

### Error: "Conversion from JSON failed with error: Unexpected character"

**Symptoms:**
- JSON contains non-ASCII characters
- Encoding issue

**Diagnosis:**
```powershell
$path = "$env:APPDATA\DailyMotivationBrainHelper\app_settings.json"
$bytes = [System.IO.File]::ReadAllBytes($path)

# Check for UTF-8 BOM (EF BB BF):
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "UTF-8 with BOM - OK"
} else {
    Write-Host "Encoding issue detected"
}
```

**Solution:**
```powershell
# Re-save with correct encoding:
$content = Get-Content $path -Raw
$content | Set-Content $path -Encoding UTF8
```

**Prevention:** ConfigManager.psm1 always saves with UTF-8 encoding (line 89, 121, etc.).

---

## UAC and Permissions Issues

### Issue: "Access is denied" When Creating Task

**Symptoms:**
- Error when clicking "Schedule" button
- Task Scheduler throws access denied

**Cause:** Task Scheduler requires Interactive logon or higher

**Solution:**
```powershell
# Check current user's Task Scheduler permissions:
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
# Should not throw exception

# If error, verify user account:
whoami /priv
# Should include: SeChangeNotifyPrivilege, SeIncreaseQuotaPrivilege
```

**For Standard Users:**
- Creating tasks for own user account: No admin required
- Creating tasks for other users: Admin required
- App only creates tasks for current user (no admin needed)

---

### Issue: "Requested registry access is not allowed" (Shell Extension)

**Symptoms:**
- Shell extension registration fails
- Error mentioning registry

**Cause:** Shell extension requires admin to modify HKEY_CLASSES_ROOT

**Solution:**
```powershell
# Must run Register-ShellExtension.ps1 as Administrator
Right-click Register-ShellExtension.ps1 → "Run with PowerShell"
# UAC prompt expected

# Verify registration:
Get-ItemProperty "HKCR:\Directory\shell\DailyMotivationSchedule" -ErrorAction SilentlyContinue
# Should return registry key if registered
```

---

### Issue: "%APPDATA% Not Accessible"

**Symptoms:**
- Error: "Could not create directory"
- Roaming profile issues in enterprise environment

**Cause:** Disk quota exceeded, network share unavailable, or permissions

**Solution:**
- App automatically falls back to `%TEMP%` (ConfigManager.psm1 lines 62-78)
- Manual fallback:
  ```powershell
  # Check %APPDATA% accessibility
  Test-Path $env:APPDATA -PathType Container

  # Check disk space
  Get-PSDrive C | Select-Object Used, Free

  # If roaming profile, check network:
  Test-Path "\\server\profiles\$env:USERNAME"
  ```

**Verification:**
```powershell
# Check where app stored config
$debugLog = Get-Content "$env:TEMP\DailyMotivation_debug.log"
$debugLog | Select-String "Config path:"
# Should show either %APPDATA% or %TEMP%
```

---

## Debug Procedures

### Collecting Diagnostic Information

**Script to collect all relevant logs:**
```powershell
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$diagPath = "$env:USERPROFILE\Desktop\DailyMotivation_Diagnostics_$timestamp"
New-Item -ItemType Directory -Path $diagPath -Force

# Copy configuration
Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*.json" $diagPath -Force
Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*.txt" $diagPath -Force

# Copy logs
Copy-Item "$env:TEMP\DailyMotivation_*.log" $diagPath -Force -ErrorAction SilentlyContinue

# Export Task Scheduler tasks
Get-ScheduledTask -TaskName "DailyMotivation*" |
  Export-ScheduledTask |
  Out-File "$diagPath\ScheduledTasks.xml" -Encoding UTF8

# System information
@"
Windows Version: $((Get-CimInstance Win32_OperatingSystem).Caption)
PowerShell Version: $($PSVersionTable.PSVersion)
Current User: $env:USERNAME
AppData Path: $env:APPDATA
Temp Path: $env:TEMP
Install Location: C:\DailyMotivation\
Task Scheduler Service: $(Get-Service Schedule | Select-Object -ExpandProperty Status)
"@ | Out-File "$diagPath\SystemInfo.txt"

Write-Host "Diagnostics collected in: $diagPath"
Compress-Archive -Path $diagPath -DestinationPath "$diagPath.zip"
Write-Host "ZIP created: $diagPath.zip"
```

---

### Enabling Verbose Logging

**In DailyMotivation.ps1:**
- Already has verbose logging to `%TEMP%\DailyMotivation_debug.log`
- View in real-time:
  ```powershell
  Get-Content "$env:TEMP\DailyMotivation_debug.log" -Wait
  ```

**In LaunchMotivation.bat:**
- Logs to `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt`
- View recent entries:
  ```powershell
  Get-Content "$env:APPDATA\DailyMotivationBrainHelper\launch_log.txt" -Tail 50
  ```

---

### Testing Without Task Scheduler

**Run popup script manually:**
```powershell
# Set up test config
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
$testConfig = @{
    glyph         = "[+]"
    title         = "Test Popup"
    body          = "This is a test popup."
    explorer_path = "C:\Windows"
    folder_name   = "Windows"
    task_id       = "test12345"
} | ConvertTo-Json

Set-Content "$appData\popup_config.json" -Value $testConfig -Encoding UTF8

# Launch popup directly
powershell.exe -STA -ExecutionPolicy Bypass -File "C:\DailyMotivation\src\DailyMotivation.ps1"

# Check debug log
Get-Content "$env:TEMP\DailyMotivation_debug.log"
```

---

### Testing Task Scheduler Integration

**Create a test task manually:**
```powershell
$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"C:\DailyMotivation\src\LaunchMotivation.bat`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2)

Register-ScheduledTask `
    -TaskName "DailyMotivation_TEST" `
    -Action $action `
    -Trigger $trigger `
    -Description "Test task - delete after testing"

# Wait 2 minutes, then check
Get-ScheduledTaskInfo -TaskName "DailyMotivation_TEST"

# Clean up
Unregister-ScheduledTask -TaskName "DailyMotivation_TEST" -Confirm:$false
```

---

### Testing Module Imports

**Test each module individually:**
```powershell
# Test ConfigManager
Import-Module "$env:APPDATA\DailyMotivationBrainHelper\Modules\ConfigManager.psm1" -Force
Initialize-AppData
Get-AppSettings
Write-Host "ConfigManager OK"

# Test TaskScheduler
Import-Module "$env:APPDATA\DailyMotivationBrainHelper\Modules\TaskScheduler.psm1" -Force
Get-MotivationTasks
Write-Host "TaskScheduler OK"
```

---

## Log File Locations

### Critical Logs

| Log File | Path | Purpose | Troubleshooting Use |
|----------|------|---------|---------------------|
| **DailyMotivation_debug.log** | `%TEMP%\DailyMotivation_debug.log` | Popup script execution trace | Check popup startup, mutex, XAML loading |
| **DailyMotivation_error.log** | `%TEMP%\DailyMotivation_error.log` | Uncaught exceptions | Check for fatal errors |
| **launch_log.txt** | `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt` | Batch launcher execution | Check if Task Scheduler triggered correctly |
| **launch_ps.log** | `%APPDATA%\DailyMotivationBrainHelper\launch_ps.log` | PowerShell stderr output | Check for script errors |
| **popup_log.txt** | `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt` | Task outcome history | Check task completion status |

### Log Analysis Commands

**Check last 20 popup executions:**
```powershell
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_log.txt" |
  Select-Object -Last 20
```

**Find failed task triggers:**
```powershell
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_log.txt" |
  Select-String "PathMissing|Dismissed"
```

**View launcher errors:**
```powershell
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\launch_log.txt" |
  Select-String "ERROR"
```

**Check for PowerShell exceptions:**
```powershell
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\launch_ps.log" |
  Select-String "Exception|Error"
```

**Monitor popup debug log in real-time:**
```powershell
Get-Content "$env:TEMP\DailyMotivation_debug.log" -Wait
# Run this before triggering a test task
```

---

## Event Viewer Integration

### Relevant Event Logs

**Task Scheduler Operational Log:**
```powershell
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 100 |
  Where-Object { $_.Message -like "*DailyMotivation*" } |
  Select-Object TimeCreated, Id, Message
```

**Common Event IDs:**
- **100**: Task registered
- **102**: Task started
- **201**: Task completed successfully
- **203**: Task action failed
- **324**: Task trigger missed
- **411**: Task Scheduler service started

**PowerShell Event Log:**
```powershell
Get-WinEvent -LogName 'Windows PowerShell' -MaxEvents 100 |
  Where-Object { $_.Message -like "*DailyMotivation*" } |
  Select-Object TimeCreated, Id, LevelDisplayName, Message
```

---

## Advanced Troubleshooting

### Issue: High CPU Usage During Popup Display

**Symptoms:**
- Popup window causes CPU spike
- System becomes unresponsive

**Diagnosis:**
```powershell
# Monitor process during popup
Get-Process powershell | Select-Object CPU, Threads, WorkingSet64
```

**Possible Causes:**
1. **Infinite loop in timer/dispatcher**
   - Check DailyMotivation.ps1 for DispatcherTimer logic
   - Verify timer properly disposed

2. **WPF rendering issue**
   - Disable hardware acceleration (add to XAML):
     ```xml
     RenderOptions.ProcessRenderMode="SoftwareOnly"
     ```

---

### Issue: Popup Shows Garbled Text or Missing Characters

**Symptoms:**
- Message text displays as boxes or question marks
- Folder name shows corrupted characters

**Cause:** Encoding mismatch (UTF-8 vs. Windows-1252)

**Solution:**
```powershell
# Check message encoding
$msgPath = "$env:APPDATA\DailyMotivationBrainHelper\messages.json"
$bytes = [System.IO.File]::ReadAllBytes($msgPath)

# Should start with UTF-8 BOM: EF BB BF
if ($bytes[0] -ne 0xEF) {
    Write-Host "Encoding issue - re-save as UTF-8 with BOM"
}
```

**For Folder Names with Unicode:**
- ConfigManager saves paths with UTF-8 encoding (line 89)
- If issue persists, avoid non-ASCII characters in folder names

---

### Issue: "The RPC server is unavailable" (Task Scheduler)

**Symptoms:**
- Cannot create tasks
- Error code: 0x800706BA

**Cause:** Task Scheduler service not running or RPC service issue

**Solution:**
```powershell
# Check services
Get-Service Schedule, RpcSs | Select-Object Name, Status, StartType

# Start if stopped
Start-Service Schedule
Start-Service RpcSs

# If persistent, repair Windows:
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
```

---

## Getting Additional Help

### Before Reporting Issues

Please collect the following:

1. **Diagnostic bundle** (see "Collecting Diagnostic Information" above)
2. **Error messages** (exact text, screenshots)
3. **Steps to reproduce** (what actions lead to the error)
4. **System information:**
   - Windows version: `winver`
   - PowerShell version: `$PSVersionTable.PSVersion`
   - .NET Framework version: (see "Task Shows 0xC0000142" section)

### Reporting Issues

**GitHub Issues:**
- URL: https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues
- Include diagnostic bundle
- Tag with appropriate labels (bug, enhancement, question)

**Security Issues:**
- Email: mmueller07@gmail.com
- Subject: `[SECURITY] Daily-Motivation-Brain-Helper`
- Do NOT post publicly

### Community Support

Check existing documentation:
- `docs/INSTALL.md` - Installation guide
- `TESTING.md` - Testing and development
- `docs/ARCHITECTURE.md` - System architecture
- `docs/CONFIGURATION_SPEC.md` - Config file schemas

---

## Quick Reference: Error Code Lookup

| Error Code | Meaning | Solution Section |
|------------|---------|------------------|
| 0x1 | Script exited with error | "Task Shows Last Run Result: 0x1" |
| 0x41301 | Task not scheduled | "Task Shows Last Run Result: 0x41301" |
| 0xC0000142 | Application init failed | "Task Shows Last Run Result: 0xC0000142" |
| 0x800706BA | RPC server unavailable | "The RPC server is unavailable" |
| Module not found | Import failed | "Module Not Found Errors" |
| STA thread error | Threading issue | "WPF Crashes (STA Thread Issues)" |
| JSON parse error | Invalid JSON | "JSON Parsing Errors" |
| Access denied | Permissions issue | "UAC and Permissions Issues" |

---

**End of Troubleshooting Guide**

**Last Reviewed:** 2026-06-09
**Next Review:** 2026-09-09 (quarterly update recommended)
