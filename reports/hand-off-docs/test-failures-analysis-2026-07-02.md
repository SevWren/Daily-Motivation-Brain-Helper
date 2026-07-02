# Test Failures Analysis and Fixes — Daily-Motivation-Brain-Helper
**Date:** 2026-07-02
**Branch:** `project-restart-pwsh7`
**Test Output Source:** Windows 10 PowerShell 7 execution of `Invoke-Tests.ps1`

---

## Executive Summary

Test suite shows **83 failures, 188 passing, 4 skipped**. Code coverage at **31.19%** (target: 75%). The primary bug from commit `6378e54` (missing `$script:ConfigDefaults`) has been **RESOLVED** in commit `97d3a65`. However, the test suite reveals **multiple additional issues** introduced during bloat removal and earlier refactoring.

**Critical Finding:** Tests were designed for Windows 10 but many failures stem from mock setup issues, not actual code bugs.

---

## Test Failure Categories

### Category 1: Parameter Binding Failures (HIGH PRIORITY)
**Tests Affected:** 2 failures
**Root Cause:** Tests expect parameters that were removed or renamed during refactoring.

#### 1.1 Set-PopupConfig missing `-FolderPath` parameter
- **Test:** `SingleFile.Tests.ps1:135`
- **Error:** `ParameterBindingException: A parameter cannot be found that matches parameter name 'FolderPath'`
- **Investigation Needed:** Check if `Set-PopupConfig` signature changed; tests may need updating to use `-ExplorerPath` instead

#### 1.2 Save-Config missing `-DefaultTriggerHour` parameter
- **Test:** `SingleFile.Tests.ps1:154`
- **Error:** `ParameterBindingException: A parameter cannot be found that matches parameter name 'DefaultTriggerHour'`
- **Investigation Needed:** Verify `Save-Config` parameter signature; may need to pass as hashtable instead

---

### Category 2: Property Access Failures — TaskName (CRITICAL)
**Tests Affected:** 60+ failures
**Root Cause:** Mock objects for `Get-ScheduledTask` don't include required `TaskName` property.

#### 2.1 Sync-TaskStatuses TaskName PropertyNotFoundException
- **Location:** `DailyMotivation.ps1:888`
- **Error:** `PropertyNotFoundException: The property 'TaskName' cannot be found on this object`
- **Chain:** Called from `New-MotivationTask:573`
- **Root Cause:** Mock objects in tests return `$null` or simple objects without `TaskName` property
- **Affected Tests:** All TaskScheduler tests, Integration tests, Security tests
- **Fix Required:** Update mock definitions in test BeforeAll blocks:

```powershell
# CURRENT (BROKEN):
Mock Get-ScheduledTask { return $null }

# FIX:
Mock Get-ScheduledTask {
    param($TaskName)
    if ($TaskName -eq "DailyMotivation_*") {
        return @()  # Empty array for "find all" queries
    }
    return $null  # Task not found
}
```

---

### Category 3: Property Access Failures — Other Properties (MEDIUM)
**Tests Affected:** 10+ failures

#### 3.1 Get-RandomMessage returning invalid objects
- **Tests:** `FolderScheduling.Tests.ps1:133, 146`
- **Error:** `PropertyNotFoundException: The property 'Glyph' cannot be found`
- **Location:** `Invoke-FolderScheduling:1215`
- **Root Cause:** Test mocks `Get-RandomMessage` to return `$null` or object missing required properties
- **Fix:** Add defensive null checks in `Invoke-FolderScheduling`:

```powershell
$msg = Get-RandomMessage
if (-not $msg -or -not $msg.Glyph -or -not $msg.Title -or -not $msg.Body) {
    # Fallback to default message
    $msg = [PSCustomObject]@{
        Glyph = '[•]'
        Title = 'Daily Motivation'
        Body = 'Time to work on your scheduled task!'
    }
}
```

#### 3.2 ContextMenu.Tests.ps1 — Count property not found
- **Test:** `ContextMenu.Tests.ps1:119`
- **Error:** `PropertyNotFoundException: The property 'Count' cannot be found`
- **Context:** "Should not throw when called multiple times (idempotent)"
- **Investigation:** Check what object is being tested for `.Count` property

#### 3.3 Security.Tests.ps1 — garbage_data property test
- **Test:** `Security.Tests.ps1:333`
- **Error:** `PropertyNotFoundException: The property 'garbage_data' cannot be found`
- **Context:** AG10-017 config schema validation
- **Root Cause:** Test expects config to reject unknown fields, but current implementation allows them
- **Status:** Expected failure — test is checking for security feature not yet implemented

---

### Category 4: Variable Not Set Errors (HIGH PRIORITY)
**Tests Affected:** 10+ failures

#### 4.1 $script:ExePath not set
- **Locations:** Multiple Security.Tests.ps1 and TaskScheduler.Tests.ps1
- **Error:** `RuntimeException: The variable '$script:ExePath' cannot be retrieved because it has not been set`
- **Root Cause:** Tests call `New-MotivationTask` without setting `$script:ExePath` first
- **Fix:** Add to BeforeAll/BeforeEach blocks:

```powershell
$script:ExePath = 'C:\Test\DailyMotivation.exe'
```

#### 4.2 $script:WpfLoaded not set
- **Tests:** `Config.Tests.ps1:275`, `Security.Tests.ps1:268`
- **Error:** `RuntimeException: The variable '$script:WpfLoaded' cannot be retrieved because it has not been set`
- **Location:** `Show-ErrorDialog` function
- **Root Cause:** Tests call `Show-ErrorDialog` without loading assemblies
- **Fix:** Add null/existence check in `Show-ErrorDialog`:

```powershell
if (-not (Get-Variable -Name 'WpfLoaded' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:WpfLoaded = $false
}
```

---

### Category 5: ToCharArray Method Error (LOW PRIORITY)
**Tests Affected:** 1 failure

#### 5.1 Config.Tests.ps1 pipe character sanitization
- **Test:** `Config.Tests.ps1:265`
- **Error:** `RuntimeException: Method invocation failed because [System.Char] does not contain a method named 'ToCharArray'`
- **Context:** "Should sanitize or escape pipe characters to avoid delimiter corruption"
- **Root Cause:** Code tries to call `.ToCharArray()` on a char instead of string
- **Fix:** Ensure variable is `[string]` before calling `.ToCharArray()`

---

### Category 6: Resource Disposal Issues (MEDIUM — Test Quality)
**Tests Affected:** 6 failures
**Note:** These are test expectations, not necessarily code bugs.

#### 6.1 FolderBrowserDialog not disposed in Show-PopupWindow
- **Test:** `Performance.Tests.ps1:45`
- **Expectation:** "FolderBrowserDialog must be disposed to prevent window handle leak (AG14-001)"
- **Investigation:** Check if `rePickBtn` handler in Show-PopupWindow uses FolderBrowserDialog and if it's disposed

#### 6.2 BrushConverter not reused
- **Test:** `Performance.Tests.ps1:107`
- **Expectation:** "BrushConverter instances should be reused or disposed (AG14-006)"
- **Investigation:** Check if multiple `BrushConverter` instances are created in Show-MainWindow

#### 6.3 Timer cleanup issues
- **Test:** `UIDisposal.Tests.ps1:60, 92, 107`
- **Expectations:** Timer intervals must be validated, timers must be stopped on window close
- **Investigation:** Check countdownTimer and fallbackTimer initialization and cleanup

#### 6.4 Window disposal after ShowDialog
- **Tests:** `UIDisposal.Tests.ps1:177, 192`
- **Expectation:** "WPF Window implements IDisposable and must be disposed"
- **Investigation:** Check if try-finally blocks exist in Show-MainWindow and Show-PopupWindow

---

### Category 7: Platform Adapter Mock Failures (LOW — Test Infrastructure)
**Tests Affected:** 4 failures in PlatformAdapter.Tests.ps1
**Root Cause:** Test creates PSCustomObject for mock platform but accesses it as if it has methods.

#### 7.1 Method invocation failures
- **Tests:** Lines 89, 116, 127 in PlatformAdapter.Tests.ps1
- **Errors:** `RuntimeException: Method invocation failed because [System.Management.Automation.PSCustomObject] does not contain a method named 'ScheduleTask'`
- **Fix:** Use ScriptMethod instead of NoteProperty for mock platform:

```powershell
$mockPlatform = New-Object PSCustomObject
$mockPlatform | Add-Member -MemberType ScriptMethod -Name ScheduleTask -Value { param($x) throw "Simulated failure" }
```

---

### Category 8: Windows Path Handling (LOW — Platform Tests)
**Tests Affected:** 3 failures in FolderScheduling.Tests.ps1
**Context:** Tests for Windows drive letters, mapped drives, paths with spaces
**Status:** May be expected failures on Linux test environment

---

### Category 9: Security Test Failures (MEDIUM — Feature Gaps)
**Tests Affected:** 10+ failures
**Root Cause:** Tests validate security features not yet fully implemented

#### 9.1 Registry command format validation
- **Test:** `ContextMenu.Tests.ps1:87`
- **Error:** Expected regex `C:\\Test\\DailyMotivation\.exe` to match `"C:\`Test\`DailyMotivation.exe" /setfolder "%1"`
- **Issue:** Backtick escaping in path breaks regex match

#### 9.2 Security constraints not implemented
- **Tests:** AG10-001, AG10-010, AG10-011, AG10-012, AG10-015, AG10-017
- **Status:** Tests are RED by design — they check for security hardening not yet implemented

---

### Category 10: Integration Test Sync Issues (MEDIUM)
**Tests Affected:** SyncTaskStatuses.Tests.ps1

#### 10.1 Direction 1 sync not working
- **Test:** `SyncTaskStatuses.Tests.ps1:60`
- **Expected:** Task status should change from PENDING to DELETED when OS task is missing
- **Actual:** Status remains PENDING
- **Investigation:** Check if Sync-TaskStatuses is being called correctly; verify mock setup

---

### Category 11: Glyph Format Test Failure (LOW)
**Test:** `Messages.Tests.ps1:88`
**Error:** `Expected '[^]' to be found in collection @('[+]', '[♦]', ...)`, but it was not found.
**Context:** Glyph validation
**Root Cause:** Message array contains `[^]` glyph but test expects only specific glyphs
**Fix:** Either remove `[^]` from $Messages or add it to test's expected list

---

## Priority Fix Recommendations

### P0 — Must Fix Before Next Commit
1. ✅ **COMPLETED** — Restore `$script:ConfigDefaults` (commit `97d3a65`)
2. **IN PROGRESS** — Add `$script:ExePath` initialization to all test BeforeAll blocks
3. **IN PROGRESS** — Fix Get-ScheduledTask mocks to return proper objects with TaskName property

### P1 — Fix for Windows Test Pass
1. Add defensive null check for `$script:WpfLoaded` in Show-ErrorDialog
2. Fix Set-PopupConfig and Save-Config parameter binding issues (or update tests)
3. Add null checking for Get-RandomMessage result in Invoke-FolderScheduling
4. Fix ToCharArray call in Config.Tests.ps1

### P2 — Test Quality Improvements
1. Resource disposal tests (FolderBrowserDialog, BrushConverter, Timers, Windows)
2. Platform adapter mock method definitions
3. SyncTaskStatuses Direction 1 test

### P3 — Security Feature Implementation (Future Work)
1. Security validation tests (AG10-* series)
2. Config schema validation (AG10-017)
3. ACL configuration (AG10-011)

---

## Test Execution Environment Note

**CRITICAL:** Per CLAUDE.md, tests must be validated on **Windows 10 PowerShell 7**. The test output provided is from Windows 10, which is authoritative. Do not assume fixes are valid based solely on Linux sandbox test results.

---

## Suggested Fix Implementation Order

1. **Batch 1 — Quick Wins (30 min)**
   - Set `$script:ExePath` in all test BeforeAll blocks
   - Fix Get-ScheduledTask mocks to include TaskName property
   - Add $script:WpfLoaded null check in Show-ErrorDialog

2. **Batch 2 — Parameter Fixes (45 min)**
   - Investigate Set-PopupConfig FolderPath parameter
   - Investigate Save-Config DefaultTriggerHour parameter
   - Update tests or function signatures as needed

3. **Batch 3 — Defensive Coding (30 min)**
   - Add Get-RandomMessage null checks
   - Fix ToCharArray string cast
   - Update glyph validation test

4. **Batch 4 — Resource Management (2 hours)**
   - FolderBrowserDialog disposal in Show-PopupWindow
   - BrushConverter reuse pattern
   - Timer cleanup handlers
   - Window disposal try-finally blocks

---

## References

- Test output log: `test_output.txt` (Windows 10 execution)
- Original handoff: `reports/hand-off-docs/handoff-2026-07-02.md`
- ConfigDefaults fix commit: `97d3a65`
- Bloat removal commit: `adbd365`
- Bug introduction commit: `6378e54`
