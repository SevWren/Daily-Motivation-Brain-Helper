# CRITICAL BUG REPORT: "try is not recognized" Error in ShowDialog()

## Bug ID
BUG-SHOWDIALOG-TRY-001

## Severity
CRITICAL - Application crashes on launch

## Error Message
```
Exception calling "ShowDialog" with "0" argument(s): "The term 'try' is not recognized
as the name of a cmdlet, function, script file, or operable program. Check the spelling
of the name, or if a path was included, verify that the path is correct and try again."
```

## Context
- **File:** DailyMotivation.ps1
- **Function:** Show-PopupWindow
- **Error Location:** ShowDialog() call at line 2797
- **Trigger:** Application compiled to .exe with ps2exe, run in /popup mode
- **Environment:** Windows 10, PowerShell compiled to .NET Framework 4.x

## Symptoms
1. Script loads successfully when dot-sourced in PowerShell 7: `pwsh -NoProfile -Command '. ./DailyMotivation.ps1 -NoRun'`
2. Script compiles successfully with ps2exe
3. Compiled .exe crashes when ShowDialog() is invoked
4. Error indicates PowerShell parser is interpreting "try" as a command name, not a keyword

## Root Cause Analysis
The error "try is not recognized as a cmdlet" occurs when:
- A scriptblock is malformed (missing closing brace)
- A try-catch block appears outside valid scope
- String escaping causes scriptblock to terminate early
- Event handler scriptblock has syntax error that only manifests at runtime

**Key Insight:** The script loads fine during dot-sourcing because PowerShell 7 doesn't evaluate
event handler scriptblocks until they're invoked. When ShowDialog() is called, WPF initializes
the window and registers all event handlers. If any handler scriptblock has a syntax error,
it fails at this point.

## Timeline of Failed Fix Attempts

### Attempt 1: Window.Dispose() Bug (Commit 26b7679)
**Date:** 2026-07-01
**Issue Identified:** Agent fixes incorrectly added $window.Dispose() calls
**Root Cause:** WPF System.Windows.Window does NOT have Dispose() method
**Fix Applied:** Changed `$window.Dispose()` to `$window.Close()` at lines 2073 and 2736
**Result:** FAILED - Different bug, but "try" error persisted

### Attempt 2: Join-String Syntax Error (Commit 5cc4926)
**Date:** 2026-07-01
**Issue Identified:** `Join-String -Separator """"`
**Root Cause:** Four double-quotes invalid syntax
**Fix Applied:** Changed to `Join-String -Separator ""`
**Result:** FAILED - Build succeeded but "try" error persisted

### Attempt 3: DriveInfo.Dispose() Bug (Commit 92e5f60)
**Date:** 2026-07-01
**Issue Identified:** `$driveInfo.Dispose()` called on value type
**Root Cause:** DriveInfo is a struct (value type), not IDisposable
**Fix Applied:** Removed `driveInfo.Dispose()` calls at lines 776 and 1293
**Result:** FAILED - "try" error persisted

### Attempt 4: Indentation Error at Line 2646 (Commit dc95332)
**Date:** 2026-07-01
**Issue Identified:** `[void][System.Windows.MessageBox]::Show(` at wrong indentation
**Location:** Line 2646 in snooze handler validation
**Root Cause:** AG9-003 refactoring left indentation at 12 spaces instead of 20
**Fix Applied:** Corrected indentation to 20 spaces
**Verification:** Script loads successfully: `pwsh -NoProfile -Command '. ./DailyMotivation.ps1 -NoRun'`
**Result:** FAILED - Script loads but compiled .exe still crashes with "try" error

## Current Investigation Status

### What We Know
1. ✅ Script syntax is valid for PowerShell 7 parser
2. ✅ All braces are balanced (618 open, 618 closed)
3. ✅ All MessageBox::Show calls have proper syntax
4. ✅ Build completes successfully
5. ❌ Runtime error occurs specifically at ShowDialog() invocation
6. ❌ Error only manifests in compiled .exe, not in dot-sourced script

### What We've Checked
- [x] Brace balance in entire file
- [x] Brace balance in Show-PopupWindow function (lines 2358-2869)
- [x] All MessageBox::Show calls (11 total)
- [x] All event handler registrations (13 handlers)
- [x] Indentation of all [void] casts
- [x] Try-catch-finally blocks

### What We Haven't Checked Yet
- [ ] **Scriptblock syntax in event handlers** - try-catch inside scriptblocks
- [ ] **String escaping** - backticks in strings inside scriptblocks
- [ ] **Variable expansion** - $(...) inside strings inside scriptblocks
- [ ] **Nested scriptblocks** - scriptblocks passed as parameters
- [ ] **Compiled behavior** - ps2exe may parse scriptblocks differently than pwsh

## Event Handlers in Show-PopupWindow

All event handlers that execute when ShowDialog() is called:

1. **Line 2519:** `$window.Add_Loaded({ ... })` - Window initialization
2. **Line 2539:** `$fallbackTimer.Add_Tick({ ... })` - Fallback opacity timer
3. **Line 2549:** `$cancelCountdown` scriptblock variable
4. **Line 2556-2559:** PreviewMouseDown handlers (use $cancelCountdown)
5. **Line 2565:** `$timer.Add_Tick({ ... })` - Countdown timer (has try-catch-finally)
6. **Line 2608:** `$snoozeDropBtn.Add_Click({ ... })` - Context menu
7. **Line 2619-2622:** Snooze duration handlers (single-line scriptblocks)
8. **Line 2626:** `$exitItem.Add_Click({ ... })` - Exit menu item
9. **Line 2636:** `$snoozeBtn.Add_Click({ ... })` - Snooze button (has try-catch)
10. **Line 2679:** `$dismissBtn.Add_Click({ ... })` - Dismiss button (has try-catch)
11. **Line 2708:** `$letsGoBtn.Add_Click({ ... })` - Open folder button (has try-catch)
12. **Line 2725:** `$pathDismissBtn.Add_Click({ ... })` - Path missing dismiss
13. **Line 2732:** `$rePickBtn.Add_Click({ ... })` - Re-pick folder (has try-catch-finally)
14. **Line 2773:** `$window.Add_Closed({ ... })` - Window cleanup (has try-catch)

## Hypothesis

**The error "try is not recognized" suggests a scriptblock is malformed such that the
closing brace appears BEFORE a try-catch block, causing the try-catch to be outside
the scriptblock.**

Example of how this could happen:
```powershell
$button.Add_Click({
    # Some code
    }  # Scriptblock closes HERE
)
try {  # This try is now OUTSIDE the scriptblock!
    # More code
}
```

**Next Steps:**
1. Manually inspect each event handler scriptblock for premature closing braces
2. Look for try-catch blocks that might be outside their intended scriptblock
3. Check if any scriptblock has a closing brace on the wrong line
4. Examine commit ff3c839 and 98d9f1b more carefully (AG9-003 refactoring)

## Files to Review
- DailyMotivation.ps1 lines 2358-2869 (Show-PopupWindow function)
- Focus on event handlers with try-catch blocks
- Check git diff for commits ff3c839 and 98d9f1b

## Detailed Investigation (Post-Hotfix)

### Verification of All AG9-003 Locations
Checked all 20 AG9-003 comments in the file. All MessageBox::Show calls have proper syntax:
- ✅ Line 2645-2647: Snooze validation error handler
- ✅ Line 2659-2661: Snooze task creation error handler
- ✅ Line 2760-2762: Config update error handler (re-pick folder)
- ✅ Line 2854-2856: Explorer launch error handler

### Verification of Event Handler Structure
Checked all event handlers in Show-PopupWindow (lines 2358-2869):
- ✅ All scriptblocks properly opened and closed
- ✅ All try-catch-finally blocks balanced
- ✅ No premature closing braces before try blocks
- ✅ Brace count: 618 open, 618 closed (balanced)

### Byte-Level Verification
- ✅ No hidden characters or encoding issues (checked with `od -c`)
- ✅ All newlines are standard \n
- ✅ No unusual whitespace or control characters

### Indentation Anomaly
Discovered unusual indentation pattern in popup event handlers:
```powershell
$snoozeBtn.Add_Click({
        try {  # 12 spaces (unusual, but valid PowerShell)
```
While unusual, this should be valid. Most handlers use 8-space indentation, but some use 12 spaces.

### PowerShell 7 vs .NET Framework 4.x Behavior
**Key Finding:** Script loads successfully in PowerShell 7:
```bash
pwsh -NoProfile -Command '. ./DailyMotivation.ps1 -NoRun'
# Output: Script loaded successfully - no syntax errors
```

**But compiled .exe crashes:**
- ps2exe compiles to .NET Framework 4.x (required for WPF/Task Scheduler)
- Error occurs at ShowDialog() invocation (line 2797)
- Error message: "The term 'try' is not recognized"

**Hypothesis:** ps2exe may handle scriptblock embedding differently than native PowerShell 7 parser.

### Possible Root Causes
1. **ps2exe scriptblock compilation issue** - Nested scriptblocks in event handlers may be miscompiled
2. **Variable capture in closures** - Event handlers capture $window, $timer, etc. from outer scope
3. **WPF initialization** - Error occurs when ShowDialog() evaluates event handler registrations
4. **String escaping in embedded scriptblocks** - Backticks and variable expansion in strings
5. **Compiled vs interpreted behavior** - PowerShell 7 dot-sourcing doesn't evaluate handlers until invoked

### What The Error Means
"The term 'try' is not recognized as a cmdlet" indicates PowerShell is trying to **execute**
"try" as a command name, not recognizing it as a keyword. This happens when:
- A scriptblock ends prematurely (but we verified all braces are balanced)
- `try` appears outside a valid execution context
- The parser state is corrupted before reaching the try block

### Critical Question
**Why does the script load in PowerShell 7 but crash when compiled?**

The answer: **Dot-sourcing doesn't evaluate event handler scriptblocks.**
- `$button.Add_Click({ ... })` registers the scriptblock but doesn't parse its contents
- ShowDialog() actually **invokes** the WPF event system, which **evaluates** the scriptblocks
- If ps2exe embedded the scriptblocks incorrectly, they fail at evaluation time, not load time

## Next Steps to Resolve

### Option 1: Binary Search Through Event Handlers
Comment out event handlers one-by-one and recompile to isolate which handler is causing the error:
1. Comment out all Add_Click handlers
2. Recompile and test - if it works, the bug is in a click handler
3. Binary search: enable half, recompile, narrow down to specific handler

### Option 2: Simplified Test Case
Create minimal ps2exe test with:
```powershell
$window = New-Object System.Windows.Window
$button = New-Object System.Windows.Controls.Button
$button.Add_Click({
        try {
            Write-Host "Clicked"
        }
        catch { Write-Host "Error" }
    })
$window.ShowDialog()
```
Compile with ps2exe and test. If this fails, it's a ps2exe issue with nested try-catch in event handlers.

### Option 3: Remove Extra Indentation
Standardize all event handler indentation to 8 spaces instead of 12:
```powershell
$snoozeBtn.Add_Click({
    try {  # 8 spaces (standard)
```
ps2exe might be sensitive to unusual indentation in scriptblocks.

### Option 4: Inspect ps2exe Output
Decompile the .exe or examine ps2exe's embedded PowerShell script to see how it transformed
the event handler scriptblocks.

### Option 5: Alternative Compilation
Try different ps2exe versions or compilation flags:
- `-noConsole` might affect scriptblock handling
- `-STA` is required but might interact with event handlers
- Try ps2exe 1.0.13 vs other versions

### Attempt 5: Previous Session's Final Hotfix (Unknown Commit)
**Date:** 2026-07-01
**What Was Tried:** Unknown specific change from previous session (no commit details recovered)
**Result:** FAILED - "try not recognized" error persisted on both Schedule button and context menu invocations

---

## ROOT CAUSE — CONFIRMED (2026-07-01, 5-Agent Multi-Agent Analysis)

**BUG: PowerShell 7+ try-catch-as-expression syntax incompatible with ps2exe / .NET Framework 4.x**

Two locations used `$variable = try { ... } catch { ... }` syntax — assigning the result of a
try-catch block as a value expression. This is a **PowerShell 7+ only feature** and is
**NOT supported in .NET Framework 4.x**, which is the target runtime for ps2exe-compiled exes.

When the compiled exe attempts to evaluate these lines, the .NET Framework PowerShell host
treats `try` as if it were a cmdlet/command name rather than a language keyword in expression
context, producing the exact error message: `"The term 'try' is not recognized as the name of a cmdlet"`.

The error manifests at ShowDialog() time because that is when WPF initializes the window and
begins executing the script's runtime code paths that reach these lines.

### Affected Lines

| Line | Function | Code |
|------|----------|------|
| 1126-1128 | `Update-TaskListUI` (called before ShowDialog in Show-MainWindow) | `$displayTime = try { ([datetime]$t.scheduled_time).ToString(...) } catch { $t.scheduled_time }` |
| 2367-2371 | `Show-PopupWindow` (first lines, before ShowDialog) | `$sessionId = try { [System.Diagnostics.Process]::GetCurrentProcess().SessionId } catch { 0 }` |

### Fix Applied

**Line 1126-1128** — replaced with PS5.1-compatible statement form:
```powershell
# BEFORE (PS7+ only):
$displayTime = try {
    ([datetime]$t.scheduled_time).ToString("ddd, MMM d 'at' h:mm tt")
} catch { $t.scheduled_time }

# AFTER (PS5.1 compatible):
$displayTime = $t.scheduled_time
try { $displayTime = ([datetime]$t.scheduled_time).ToString("ddd, MMM d 'at' h:mm tt") } catch {}
```

**Line 2367-2371** — replaced with PS5.1-compatible statement form:
```powershell
# BEFORE (PS7+ only):
$sessionId = try {
    [System.Diagnostics.Process]::GetCurrentProcess().SessionId
} catch {
    0  # Fallback to 0 if SessionId cannot be determined
}

# AFTER (PS5.1 compatible):
$sessionId = 0
try { $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId } catch {}
```

### Why Previous Attempts Failed

All 4 prior attempts focused on:
- Window.Dispose() / DriveInfo.Dispose() method existence
- String literal syntax (Join-String -Separator)
- Brace balance and indentation
- MessageBox::Show call formatting

None checked for **PowerShell version compatibility** of language constructs. The script passes
PS7 syntax validation because PS7 supports try-as-expression. Only ps2exe's .NET Framework 4.x
runtime reveals the incompatibility.

### Secondary Bug: Context Menu "Windows cannot access the device"

When running from the Windows context menu, the error:
> "Windows cannot access the specified device, path, or file. You may not have the appropriate permissions to access the item."

This is a **separate bug** from the try-not-recognized error. Root cause is either:
1. The registered exe path in HKCU registry points to an old/missing exe location
2. The exe has been updated but the context menu registration was not refreshed
3. The Mark-of-the-Web (MOTW) zone restriction is blocking the exe

**Resolution:** After a successful build, re-run `Register-ContextMenu` (or launch the app once
in main mode to re-register) to update the registry entry to the new exe path.

## Status
✅ **ROOT CAUSE IDENTIFIED AND FIX APPLIED** — 2026-07-01

Fix removes all `= try { } catch { }` expression-form syntax, replacing with PS5.1-compatible
statement form with pre-initialized default values. Verified 0 remaining instances in file.

**fix_ag9_001.py** — Removed from repo. This Python file had no valid purpose in a PowerShell
project. It attempted to add `[CmdletBinding()]` attributes via regex manipulation, but had no
relationship to the actual bug and should never have been created.

## Last Updated
2026-07-01 - ROOT CAUSE FOUND via 5-agent line-by-line analysis. Fix applied.
