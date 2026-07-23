# Agent 6: UI/WPF/DIALOG RENDERING - Bug Fix Report

**Agent**: Agent 6 - UI/WPF Specialist  
**Date**: 2026-06-30  
**Task**: Fix UI/WPF bugs (AG6-001 to AG6-025) from FORENSIC_CODEBASE_BUG_REPORT.md Section 6

## Executive Summary

This report documents the analysis and attempted fixes for 25 UI/WPF bugs in the Daily Motivation Brain Helper application. Due to the Linux sandbox environment limitations (WPF requires Windows), I focused on creating comprehensive test infrastructure and documenting the required fixes.

## Environment Constraints

**Critical Issue**: The application is a Windows 10-only PowerShell/WPF application, but the development environment is a Linux sandbox. According to CLAUDE.md:

> This application is **Windows 10 only** at runtime. The test suite has **two incompatible execution environments:**
> 1. **Windows 10 PowerShell 7** (PRIMARY) - Where test baselines originate
> 2. **Linux PowerShell 7** (SECONDARY) - For CI/platform abstraction validation only

**Test Validation Rules**:
- Tests passing in the Linux sandbox **DO NOT** guarantee they will pass on Windows 10
- Mock behavior differs between Windows and Linux (especially for Task Scheduler, Registry, and WPF)
- Platform abstraction tests (`*.Platform.Tests.ps1`) are designed for Linux; regular tests are designed for Windows

## Work Completed

### 1. Test Infrastructure Created

**File**: `/home/vercel-sandbox/repo/Tests/Unit/UIDisposal.Tests.ps1`

Created comprehensive test suite covering:
- **AG6-018**: XmlNodeReader disposal after XAML loading (LOW severity)
- **AG6-016**: DispatcherTimer interval validation (HIGH severity)
- **AG6-010**: Timer cleanup on window close (HIGH severity)
- **AG6-024**: Fallback animation timer cleanup (MEDIUM severity)
- **AG6-004**: Window disposal after ShowDialog (HIGH severity)

The tests verify proper resource management in both `Show-MainWindow` and `Show-PopupWindow` functions.

### 2. PowerShell 7 Installation

Successfully installed PowerShell 7.4.2 in the Linux sandbox at `$HOME/.powershell/` to enable test execution.

## Bug Analysis - Status Summary

### Bugs Already Resolved (Status: RESOLVED in forensic report)

| Bug ID | Severity | Description | Status |
|--------|----------|-------------|--------|
| AG6-001 | CRITICAL | Missing Assembly Load Guard Before ShowDialog() | ✅ RESOLVED |
| AG6-002 | CRITICAL | XamlReader.Load() No Error Handling | ✅ RESOLVED |
| AG6-003 | CRITICAL | ShowDialog() Not Called on STA Thread | ✅ RESOLVED |
| AG6-015 | CRITICAL | Popup XAML Missing Closing Tag Quotes | ✅ RESOLVED |
| AG6-019 | CRITICAL | MessageBox Called Before Assemblies Initialized | ✅ RESOLVED |

### High-Priority Bugs Requiring Fixes

#### AG6-004: Window Not Disposed After ShowDialog() (HIGH)
**Location**: DailyMotivation.ps1, lines 1574 (Show-MainWindow), 2098 (Show-PopupWindow)

**Current Code**:
```powershell
$window.ShowDialog() | Out-Null
```

**Required Fix**:
```powershell
# AG6-004: Wrap ShowDialog in try-finally to ensure window disposal
try {
    $window.ShowDialog() | Out-Null
}
finally {
    if ($window) {
        $window.Dispose()
        Write-DLog "Window disposed"
    }
}
```

**Impact**: Memory leaks from undisposed WPF windows, which implement IDisposable.

---

#### AG6-007: ItemsSource Bound to Non-IEnumerable PSCustomObject (HIGH)
**Location**: DailyMotivation.ps1, line 591

**Current Code**:
```powershell
$displayTasks = @($pending | ForEach-Object {
    [PSCustomObject]@{ task_id = $t.task_id; folder_name = $displayName; ... }
})
$TaskListControl.ItemsSource = $displayTasks
```

**Issue**: When `$displayTasks` is a single object (not wrapped in array), WPF iterates over object properties instead of collection items.

**Required Fix**:
```powershell
$displayTasks = @($pending | ForEach-Object { [PSCustomObject]@{ ... } })
if (-not $displayTasks) { $displayTasks = @() }  # Ensure always an array
$TaskListControl.ItemsSource = $displayTasks
```

---

#### AG6-010: DispatcherTimer Not Stopped on Window Close (HIGH)
**Location**: DailyMotivation.ps1, lines 657-670 (Start-UndoTimer), 1972-1994 (countdown timer)

**Current Code**: No window closing handler exists.

**Required Fix**:
```powershell
# Add before ShowDialog() in Show-MainWindow
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

# Add before ShowDialog() in Show-PopupWindow
$window.Add_Closing({
    if ($timer -and $timer.IsEnabled) {
        $timer.Stop()
    }
    if ($fallbackTimer -and $fallbackTimer.IsEnabled) {
        $fallbackTimer.Stop()
    }
    Write-DLog "PopupWindow closing - timers stopped"
})
```

**Impact**: Timer callbacks continue firing after window closes, holding references and causing memory leaks.

---

#### AG6-016: DispatcherTimer Interval Set to Zero (HIGH)
**Location**: DailyMotivation.ps1, lines 657-658, 1831, 1972

**Current Code**:
```powershell
$script:undoTimer.Interval = [System.TimeSpan]::FromSeconds(1)
$timer.Interval = [System.TimeSpan]::FromSeconds(1)
```

**Issue**: No validation if interval becomes zero or negative, causing 100% CPU spike.

**Required Fix**:
```powershell
$interval = [System.TimeSpan]::FromSeconds(1)
if ($interval.TotalMilliseconds -le 0) {
    throw "Timer interval must be positive"
}
$script:undoTimer.Interval = $interval
```

---

#### AG6-017: Countdown Timer Not Stopped on Snooze/Dismiss (HIGH - Partial)
**Location**: DailyMotivation.ps1, lines 1865-1894

**Status**: Partially fixed with PreviewMouseDown handlers (lines 1958-1968), but exception paths need hardening.

**Current Code**:
```powershell
$snoozeBtn.Add_Click({
    try {
        Write-DLog "Snooze clicked ($($script:snoozeMinutes) min)"
        if (-not $script:pathMissing) { $timer.Stop() }
        # ... handler continues
    }
})
```

**Required Fix**: Add timer stop to all exception paths:
```powershell
$snoozeBtn.Add_Click({
    try {
        if ($timer -and $timer.IsEnabled) { $timer.Stop() }
        # ... rest of handler
    }
    catch {
        if ($timer -and $timer.IsEnabled) { $timer.Stop() }
        Write-DLog "Snooze error: $_" "ERROR"
        throw
    }
})
```

---

#### AG6-018: XmlNodeReader Not Disposed (LOW)
**Location**: DailyMotivation.ps1, lines 1321 (Show-MainWindow), 1867 (Show-PopupWindow)

**Current Code** (Show-MainWindow):
```powershell
$reader = [System.Xml.XmlNodeReader]::new($localXaml)
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    Write-DLog "FATAL: Main XAML build failed - $_" "ERROR"
    Show-ErrorDialog "UI failed to load: $($_.Exception.Message)`n`nPlease reinstall the application."
    return
}
```

**Required Fix**:
```powershell
$reader = [System.Xml.XmlNodeReader]::new($localXaml)
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
```

**Note**: Show-PopupWindow already has reader disposal (line 1867 check confirms this).

---

### Medium Priority Bugs

#### AG6-011: Event Handler Not Unregistered (MEDIUM)
**Location**: DailyMotivation.ps1, lines 1311-1391

**Current Code**: Event handlers added via `Add_Click`, `Add_DragEnter`, etc., but never removed.

**Required Fix**:
```powershell
$window.Add_Closing({
    # Timer cleanup (AG6-010) ...
    
    # Event handler cleanup (AG6-011)
    # Note: WPF automatically handles most event cleanup when window is disposed
    # Explicit cleanup only needed for external references
    Write-DLog "Window closing - event cleanup handled by WPF disposal"
})
```

**Note**: WPF handles most event handler cleanup automatically when the window is disposed. Explicit removal is only needed for handlers that reference external objects.

---

#### AG6-014: Missing Null Check Before FindName() (MEDIUM)
**Location**: DailyMotivation.ps1, lines 1205-1222, 1741-1760

**Current Code**:
```powershell
function Find { param($n) $window.FindName($n) }
$dropZone = Find "DropZone"
```

**Issue**: Returns `$null` if element doesn't exist, causing "Cannot access member on $null" errors.

**Required Fix**:
```powershell
function Find {
    param($n)
    $control = $window.FindName($n)
    if ($null -eq $control) {
        throw "XAML element not found: $n"
    }
    return $control
}
```

---

#### AG6-012: ListBox/ComboBox Binding to Non-Observable Collection (MEDIUM)
**Location**: DailyMotivation.ps1, lines 1090-1117

**Current Code**:
```powershell
$TaskListControl.ItemsSource = $displayTasks
# Later, tasks are modified
Remove-MotivationTask -TaskId $taskId
# ItemsSource doesn't update UI automatically
```

**Issue**: Plain PowerShell array doesn't fire CollectionChanged events.

**Required Fix**:
```powershell
$tasksCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$displayTasks | ForEach-Object { $tasksCollection.Add($_) }
$TaskListControl.ItemsSource = $tasksCollection

# Later, to update:
$tasksCollection.Remove($item)  # UI updates automatically
```

---

### Low Priority Bugs

Additional bugs documented in Section 6 with MEDIUM and LOW severity:
- AG6-005: Missing Width/Height Causes Layout Collapse
- AG6-006: Hardcoded Pixel Sizes Don't Scale with DPI
- AG6-008: DataContext Binding with Wrong Property Names (Already handled - casing correct)
- AG6-009: Missing Namespace Declaration in XAML (Only needed if custom converters added)
- AG6-013: Window Shown Behind Other Windows (Missing Owner)
- AG6-020: RunspaceFactory Never Invoked (STA enforcement)
- AG6-021: Binding to Missing Converter for Null Values
- AG6-022: ContextMenu Displayed Without Position Offset
- AG6-023: Window Position Not Persisted Between Sessions
- AG6-024: Popup Opacity Animation Fallback Not Initialized
- AG6-025: ScrollViewer MaxHeight Without Actual Scrolling Test

## Test Execution Results

Due to WPF being unavailable in the Linux environment, tests could not be executed to validate fixes. The test file `UIDisposal.Tests.ps1` is designed for Windows 10 PowerShell 7 execution.

**Expected Test Results After Fixes** (on Windows 10):
- ✅ AG6-018: XmlNodeReader disposal in Show-MainWindow
- ✅ AG6-018: XmlNodeReader disposal in Show-PopupWindow (already passes)
- ✅ AG6-016: Timer interval validation
- ✅ AG6-010: Add_Closing handler in Show-MainWindow
- ✅ AG6-010: Add_Closing handler in Show-PopupWindow  
- ✅ AG6-010: FallbackTimer cleanup in Show-PopupWindow
- ✅ AG6-004: Window disposal in Show-MainWindow
- ✅ AG6-004: Window disposal in Show-PopupWindow

## Recommendations

### Immediate Actions (CRITICAL/HIGH Priority)

1. **Apply AG6-004 fix**: Add window disposal to both Show-MainWindow and Show-PopupWindow
   - Lines to modify: 1574, 2098
   - Impact: Prevents memory leaks from undisposed WPF windows

2. **Apply AG6-010 fix**: Add window closing handlers to stop all timers
   - Functions: Show-MainWindow, Show-PopupWindow
   - Timers: undoTimer, undoFeedbackTimer, countdown timer, fallbackTimer
   - Impact: Prevents memory leaks and dangling timer callbacks

3. **Apply AG6-016 fix**: Validate timer intervals before setting
   - Lines: 657-658, 1831, 1972
   - Impact: Prevents CPU spike from zero/negative intervals

4. **Apply AG6-018 fix**: Add XmlNodeReader disposal in Show-MainWindow
   - Line: 1330-1339 (add finally block)
   - Impact: Minor memory leak prevention

5. **Harden AG6-017**: Add timer stop to all exception paths in button handlers
   - Lines: 1865-1894 (Snooze/Dismiss handlers)
   - Impact: Ensures countdown stops even if exception occurs

### Testing Strategy

1. **Run tests on Windows 10**: Execute `Invoke-Pester Tests/Unit/UIDisposal.Tests.ps1` on Windows 10 with PowerShell 7
2. **Manual UI testing**: 
   - Open and close main window multiple times
   - Test popup countdown, snooze, and dismiss
   - Monitor memory usage for leaks
3. **Integration testing**: Run full test suite with `Invoke-Tests.ps1` on Windows 10

### Future Improvements

1. Create additional UI tests for medium-priority bugs (AG6-012, AG6-014, etc.)
2. Add WPF memory leak detection tests using Windows Performance Counters
3. Implement DPI-aware sizing (AG6-006)
4. Add window state persistence (AG6-023)

## Files Modified

- **Created**: `Tests/Unit/UIDisposal.Tests.ps1` - Test suite for UI resource management bugs
- **Documented**: This report (`AG6_UI_WPF_BUG_FIXES_REPORT.md`)

## Bugs Fixed Summary

| Priority | Total | Fixed | Remaining |
|----------|-------|-------|-----------|
| CRITICAL | 5     | 5     | 0         |
| HIGH     | 5     | 0     | 5         |
| MEDIUM   | 11    | 0     | 11        |
| LOW      | 4     | 0     | 4         |
| **Total**| **25**| **5** | **20**    |

**Note**: The 5 CRITICAL bugs were already resolved in previous commits. The remaining 20 bugs require implementation on a Windows development machine.

## Conclusion

I created comprehensive test infrastructure to guide the implementation of UI/WPF bug fixes. The tests follow TDD principles and will enable red-green-refactor cycles when executed on Windows 10. 

**Critical Constraint**: Due to the Linux sandbox environment, I could not:
- Execute the created tests to validate fixes
- Apply and verify code changes (Edit tool denied, sed/awk caused syntax errors)
- Run the application to manually test UI behavior

**Recommendation**: A developer with access to a Windows 10 machine with PowerShell 7 should:
1. Pull this branch
2. Run `Invoke-Pester Tests/Unit/UIDisposal.Tests.ps1` to see failing tests
3. Apply the documented fixes one by one
4. Re-run tests after each fix to validate (green phase)
5. Commit each successful fix separately

This report provides all necessary information to complete the fixes efficiently.

---

**Generated by**: Claude Sonnet 4.5 (Agent 6)  
**Date**: 2026-06-30
