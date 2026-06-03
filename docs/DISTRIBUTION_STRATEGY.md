# DISTRIBUTION_STRATEGY.md
# Daily-Motivation-Brain-Helper — Single-File Distribution Options

**Date:** 2026-06-03
**Goal:** End user downloads **one file**, double-clicks it, picks a folder, and the app handles everything else. No extraction steps. No script editing. No command prompt.

---

## Confirmed User Experience Constraint

> "The user ONLY LAUNCHES THE EXE and then PICKS THE FOLDER via a file explorer choice, OR pastes the full explorer folder path."

This means:
- One downloadable file (`.exe`)
- Double-click launches the app immediately — no install wizard
- The app presents a folder picker dialog (or path paste field)
- All scheduling, config writing, and task registration happens invisibly in the background
- `ShellExtension/` (right-click context menu) is **out of scope** — eliminated from all options below
- The only elevated operation required is registering the Windows Scheduled Task, which can be handled with a single embedded UAC manifest (one prompt, one time)

---

## Critical Prerequisites (Must Fix Before Any Packaging Works)

Regardless of which distribution method is chosen, these two issues from `FORENSIC_REVIEW.md` must be resolved first, or the packaged `.exe` will launch and silently do nothing:

| ID | File | Issue |
|----|------|-------|
| **GAP-002** | `TaskScheduler.psm1:8` | `LauncherPath` points to `%APPDATA%` where `LaunchMotivation.bat` is never copied — all scheduled tasks will fail to execute |
| **ERR-017** | `LaunchMotivation.bat` | Missing `-STA` flag — WPF app crashes on load on most Windows 10/11 systems |

---

## Option 1 — PS2EXE-NG

**Category:** Compile PowerShell script to native Windows executable
**Recommended for:** MVP / fastest path to a working single `.exe`

### How It Works
`ps2exe-ng` is an open-source PowerShell-to-EXE compiler. It takes `MainApp.ps1` as input, embeds all referenced files (XAML, JSON data, modules) as resources, and produces a self-contained Windows PE `.exe`. The result runs as native compiled code — PowerShell execution policy does not apply.

### End-User Experience
1. Downloads `DailyMotivation.exe` (~20–50 MB)
2. Double-clicks it
3. One UAC prompt appears (for Task Scheduler registration) — user clicks Yes
4. Folder picker opens
5. User selects folder, clicks Schedule
6. Done

### Build Command
```powershell
Install-Module -Name ps2exe -Scope CurrentUser
Invoke-ps2exe `
  -inputFile "src\MainApp.ps1" `
  -outputFile "dist\DailyMotivation.exe" `
  -iconFile "assets\icon.ico" `
  -requireAdmin `
  -noConsole `
  -title "Daily Motivation Brain Helper" `
  -version "1.0.0.0"
```

### Handling PowerShell Execution Policy
Not applicable. The compiled `.exe` is native code. Windows does not evaluate script execution policy for PE executables.

### Handling UAC / Task Scheduler
The `-requireAdmin` flag embeds a UAC manifest requesting administrator privileges at launch. The user sees exactly one UAC prompt on every run. This is the simplest approach.

### Pros
- No rewrite of existing code
- True single `.exe` output
- Execution policy completely bypassed
- 1–2 weeks to implement and test
- Open-source tooling (no licensing cost)

### Cons
- **Windows Defender SmartScreen warning** on first launch (unsigned binary from unknown publisher) — user must click "More info → Run anyway"
- **Antivirus false positives** are common for compiled PowerShell; some corporate AV will quarantine the file
- XAML and module files must be embedded as resources or bundled alongside the `.exe` at compile time
- WPF event binding behavior can differ slightly in compiled context vs. interpreted; requires thorough testing
- Does not eliminate the underlying PowerShell bugs — only packages them

### File Size
~20–50 MB (depending on whether .NET Framework runtime is bundled)

### Timeline
1–2 weeks

---

## Option 2 — C# Full Rewrite + .NET 8 Self-Contained Single-File EXE

**Category:** Rewrite core logic in C#; publish as self-contained native executable
**Recommended for:** Production v1.0 — eliminates root causes of most findings

### How It Works
All PowerShell logic (`MainApp.ps1`, `DailyMotivation.ps1`, `ConfigManager.psm1`, `TaskScheduler.psm1`) is ported to C#. The existing `MainWindow.xaml` is kept as-is (WPF XAML is identical in C# WPF projects). The project is published with .NET 8's single-file self-contained mode, which produces one `.exe` that includes the .NET runtime, all app code, and all resources.

### End-User Experience
1. Downloads `DailyMotivation.exe` (~80–120 MB)
2. Double-clicks it
3. One UAC prompt appears — user clicks Yes
4. Folder picker opens instantly
5. User selects folder, clicks Schedule
6. Done — no SmartScreen warning if the binary is code-signed

### Build Command
```bash
dotnet publish -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:EnableCompressionInSingleFile=true \
  -o dist/
```

### Handling PowerShell Execution Policy
Not applicable. Pure .NET 8 native binary. No PowerShell involved at runtime.

### Handling UAC / Task Scheduler
Embed a UAC manifest in the project (`app.manifest`) with:
```xml
<requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
```
One UAC prompt on every launch.

### Pros
- **No SmartScreen warning** — the `.exe` is a standard .NET binary and can be code-signed with an EV certificate for full trust
- **No antivirus false positives** — clean PE, not compiled script
- Eliminates at the root level: ERR-017 (STA thread), ERR-034 (error handling inconsistency), BUG-011 (encoding), BUG-004 (JSON null), and many others — the C# type system and compiler prevent entire categories of bugs
- Existing `MainWindow.xaml` reused directly — no XAML rewrite
- Long-term maintainability: IDE support, debugger, unit tests, CI/CD
- Shell extension can be added cleanly as a future feature without changing distribution approach

### Cons
- Complete rewrite of ~800+ lines of PowerShell logic into C#
- Requires C# / .NET development environment (Visual Studio 2022 or VS Code + .NET 8 SDK)
- Largest file size (~80–120 MB self-contained)
- 3–6 week effort

### File Size
~80–120 MB (self-contained .NET 8 runtime bundled)

### Timeline
3–6 weeks

---

## Option 3 — Warp Packager

**Category:** Wrap existing app folder into a single self-extracting native stub
**Recommended for:** Zero-code-change bridge while C# rewrite is in progress

### How It Works
Warp packages an entire directory (PowerShell scripts + XAML + data + PowerShell runtime) into a single `.exe` stub. On first double-click, the stub extracts its payload to a local cache directory (~2 seconds). On subsequent runs, the cached version launches instantly. The stub is a native Windows binary — execution policy does not apply.

### End-User Experience
1. Downloads `DailyMotivation.exe` (~50–80 MB)
2. Double-clicks it
3. First run: 2-second extraction to local cache, then app opens
4. One UAC prompt for Task Scheduler
5. Folder picker opens
6. User selects folder, clicks Schedule
7. Done

### Build Command
```bash
warp-packer \
  --arch windows-x64 \
  --input_dir ./dist \
  --exec LaunchMotivation.bat \
  --output DailyMotivation.exe
```

### Handling PowerShell Execution Policy
The stub is a native binary launcher. The embedded PowerShell scripts run from the extracted cache path with `-ExecutionPolicy Bypass` passed automatically.

### Handling UAC / Task Scheduler
The stub `.exe` can be manifested for UAC elevation. The Warp launcher respects standard Windows manifest embedding. Use `mt.exe` (from Windows SDK) to embed a UAC manifest post-build.

### Pros
- Zero changes to existing PowerShell codebase
- True single-file distribution
- Fastest path from current state to distributable file (1–3 days after GAP-002 and ERR-017 are fixed)
- Works offline after initial extraction

### Cons
- **Commercial license required** — Warp is not free for commercial use
- **SmartScreen warning likely** on unsigned binary
- Does not fix any of the underlying 55 findings — just packages them
- Cache extraction on first run adds ~2 second delay
- Internal structure visible to technically inclined users who inspect the cache

### File Size
~50–80 MB

### Timeline
1–3 days (after prerequisites fixed)

---

## Option 4 — NSIS Installer

**Category:** Self-extracting installer that bundles all files
**Verdict: Does NOT satisfy the UX requirement**

NSIS (`Nullsoft Scriptable Install System`) creates a self-extracting `.exe` installer that runs a wizard, extracts files, and registers components. It is excellent for traditional Windows software distribution, but requires the user to complete an installation step before the app is usable — violating the "double-click and immediately run" requirement.

**Included for completeness only.** Consider for a future Microsoft Store-adjacent distribution path or enterprise deployment via Group Policy.

---

## Option 5 — MSIX Package

**Category:** Microsoft-native app package format
**Verdict: Does NOT satisfy the UX requirement**

MSIX provides the best OS integration, automatic updates, and clean uninstall. The user experience is one-click install via the built-in AppInstaller, followed by the app appearing in the Start Menu. However, it still requires an installation step before the app can be run — violating the "double-click and immediately run" requirement.

**Included for completeness only.** Strongly recommended for a future Microsoft Store listing once the app reaches v1.0.

---

## Decision Matrix

| Option | Single File | Zero Install Step | No SmartScreen | No Code Changes | AV Clean | Timeline |
|--------|:-----------:|:-----------------:|:--------------:|:---------------:|:--------:|:--------:|
| **PS2EXE-NG** | Yes | Yes | No (unsigned) | Mostly | No | 1–2 wks |
| **C# Rewrite** | Yes | Yes | **Yes** (signable) | No (full rewrite) | **Yes** | 3–6 wks |
| **Warp** | Yes | Yes | No (unsigned) | **Yes** | No | 1–3 days |
| NSIS | No | No (wizard) | Yes | Mostly | Yes | 2–3 wks |
| MSIX | ~Yes | No (1-click) | Yes | Mostly | Yes | 3–4 wks |

---

## Phased Recommendation

| Phase | Method | Rationale |
|-------|--------|-----------|
| **MVP (now)** | PS2EXE-NG | Leverages existing codebase. Single `.exe`. No licensing cost. 1–2 weeks. Acceptable for early users who expect to click through SmartScreen. |
| **Bridge (optional)** | Warp | If PS2EXE-NG hits compatibility or AV blocking issues in testing, Warp is a 1–3 day fallback with zero code changes. Requires commercial license evaluation. |
| **v1.0 (production)** | C# Rewrite + .NET 8 | Correct long-term architecture. Eliminates the majority of findings from `FORENSIC_REVIEW.md` at the root level. Produces a signable, AV-clean binary. No SmartScreen. Best user experience. |

---

## Pre-Packaging Checklist

Before packaging with any method, confirm these items are resolved:

- [x] **GAP-002** fixed: `LauncherPath` correctly points to the app's actual install/run location
- [x] **ERR-017** fixed: `-STA` flag present in launcher; WPF loads without crash
- [x] **GAP-035** addressed: Code-behind event handlers implemented for all buttons
- [x] **BUG-011** fixed: All `Set-Content` calls use `-Encoding UTF8`
- [x] **BUG-004** fixed: Empty task array JSON round-trip returns `@()` not `$null`
- [ ] End-to-end test: Schedule a folder → wait for task to fire → confirm Explorer opens
- [ ] End-to-end test: Snooze the popup → confirm it reappears after 5 minutes
- [ ] End-to-end test: Delete a task → confirm it is removed from both `tasks.json` and Windows Task Scheduler

---

## Build System

The project uses **Invoke-Build** (`.build.ps1`) for all build automation.

```powershell
# Complete release pipeline (recommended for distribution):
Invoke-Build Release

# This runs: Clean -> PSScriptAnalyzer -> Pester tests -> PS2EXE compile -> ZIP package
# Output: ./output/DailyMotivation.exe and release ZIP
```

**Pre-release quality gates** (all must pass before distributing):
1. `Invoke-Build Analyze` -- zero PSScriptAnalyzer warnings
2. `Invoke-Build Test` -- all 180+ Pester tests pass
3. Coverage >= 80% (checked by CI/CD via `.github/workflows/test.yml`)
