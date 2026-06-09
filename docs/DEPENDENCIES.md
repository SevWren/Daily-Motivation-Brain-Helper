# DEPENDENCIES.md

**Document Version:** 1.0
**Date:** 2026-06-09
**Project:** Daily Motivation Brain Helper

---

## Overview

This document catalogs all external dependencies required to build, test, and run Daily Motivation Brain Helper. It includes runtime requirements, development tools, PowerShell modules, .NET assemblies, Windows APIs, and version lock recommendations.

---

## Table of Contents

1. [Runtime Dependencies](#1-runtime-dependencies)
2. [PowerShell Modules (Development)](#2-powershell-modules-development)
3. [.NET Framework Requirements](#3-net-framework-requirements)
4. [Windows API Dependencies](#4-windows-api-dependencies)
5. [Build Tools](#5-build-tools)
6. [Development Tools](#6-development-tools)
7. [CI/CD Dependencies](#7-cicd-dependencies)
8. [Version Lock Recommendations](#8-version-lock-recommendations)
9. [Update Procedures](#9-update-procedures)
10. [EOL Monitoring Process](#10-eol-monitoring-process)

---

## 1. Runtime Dependencies

### 1.1 Operating System
- **Windows 10** (Build 19041 or higher) or **Windows 11**
- **Required for:** Task Scheduler, WPF runtime, Windows Forms
- **EOL Status:** Windows 10 support ends October 2025; Windows 11 actively supported
- **Notes:** Application requires Windows Task Scheduler service to be running

### 1.2 PowerShell
- **Version:** PowerShell 5.1 (minimum)
- **Included with:** All supported Windows versions
- **Required by:** All `.ps1`, `.psm1` scripts
- **Version Constraint:** `#Requires -Version 5.1` in all script files
- **EOL Status:** PowerShell 5.1 is in extended support (Windows lifecycle)
- **Notes:** PowerShell 7.x not tested; stick to 5.1 for compatibility

### 1.3 .NET Framework
- **Version:** .NET Framework 4.x (4.5 or higher recommended)
- **Included with:** Windows 10/11 out-of-the-box
- **Required for:** WPF assemblies, Windows Forms, XAML loading
- **Verification:**
  ```powershell
  (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Version
  ```

### 1.4 Windows Services
- **Task Scheduler Service** (`Schedule`)
- **Status Check:** Application validates service is running at startup (see `MainApp.ps1` line 62)
- **Required for:** All scheduled task operations

---

## 2. PowerShell Modules (Development)

These modules are **not required** for end-user installations. They are only needed for building from source, running tests, and performing static analysis.

### 2.1 Pester
- **Purpose:** Unit and integration testing framework
- **Minimum Version:** 5.0
- **Recommended Version:** 5.5.0 (latest stable)
- **Installation:**
  ```powershell
  Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
  ```
- **Used by:**
  - `Invoke-Tests.ps1` (line 80)
  - `.build.ps1` Test task (line 96-113)
  - All test files in `Tests/` directory
- **Import Statement:** `Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop`
- **Version Lock:** `#Requires -Modules Pester` in `Invoke-Tests.ps1`
- **Verification:**
  ```powershell
  Get-Module -ListAvailable Pester | Select-Object Name, Version
  ```

### 2.2 PSScriptAnalyzer
- **Purpose:** Static code analysis and linting
- **Minimum Version:** 1.20.0
- **Recommended Version:** 1.22.0 (latest stable)
- **Installation:**
  ```powershell
  Install-Module -Name PSScriptAnalyzer -MinimumVersion 1.20 -Force -Scope CurrentUser
  ```
- **Used by:**
  - `.build.ps1` Analyze task (line 52-94)
  - `.PSScriptAnalyzerSettings.psd1` configuration
- **Import Statement:** `Import-Module PSScriptAnalyzer`
- **Verification:**
  ```powershell
  Get-Module -ListAvailable PSScriptAnalyzer | Select-Object Name, Version
  ```

### 2.3 InvokeBuild
- **Purpose:** Build automation and task orchestration
- **Minimum Version:** 5.0
- **Recommended Version:** 5.11.1 (latest stable)
- **Installation:**
  ```powershell
  Install-Module -Name InvokeBuild -MinimumVersion 5.0 -Force -Scope CurrentUser
  ```
- **Used by:**
  - `.build.ps1` (all build tasks)
  - CI/CD pipeline (`.github/workflows/test.yml`)
- **Verification:**
  ```powershell
  Get-Module -ListAvailable InvokeBuild | Select-Object Name, Version
  ```

### 2.4 ps2exe (or ps2exe-ng)
- **Purpose:** Compile PowerShell scripts to Windows executables
- **Minimum Version:** 1.0
- **Recommended Version:** 1.0.13 (ps2exe) or latest ps2exe-ng fork
- **Installation:**
  ```powershell
  Install-Module -Name ps2exe -MinimumVersion 1.0 -Force -Scope CurrentUser
  ```
- **Alternative:** `ps2exe-ng` (actively maintained fork with .NET 6+ support)
- **Used by:**
  - `.build.ps1` Build task (line 115-194)
  - `build.ps1` standalone build script (line 37-45)
- **Import Statement:** `Import-Module ps2exe`
- **Verification:**
  ```powershell
  Get-Command Invoke-ps2exe
  Get-Module -ListAvailable ps2exe | Select-Object Name, Version
  ```
- **Notes:**
  - Original `ps2exe` module may have compatibility issues with newer PowerShell versions
  - Consider migrating to `ps2exe-ng` for long-term maintenance

### 2.5 Project-Specific Modules
These modules are part of the project, not external dependencies:
- **ConfigManager.psm1** (`src/Modules/`)
  - Loaded by: `MainApp.ps1`, `DailyMotivation.ps1`, `UpdateScheduledTask.ps1`, all tests
- **TaskScheduler.psm1** (`src/Modules/`)
  - Loaded by: `MainApp.ps1`, `DailyMotivation.ps1`, integration tests

---

## 3. .NET Framework Requirements

### 3.1 Required Assemblies

All assemblies are loaded via `Add-Type -AssemblyName` statements.

| Assembly | Purpose | Used By | Minimum .NET Version |
|----------|---------|---------|---------------------|
| **PresentationFramework** | WPF window management | `MainApp.ps1`, `DailyMotivation.ps1` | .NET 4.0 |
| **PresentationCore** | WPF core controls | `MainApp.ps1`, `DailyMotivation.ps1` | .NET 4.0 |
| **WindowsBase** | WPF base classes | `MainApp.ps1`, `DailyMotivation.ps1` | .NET 4.0 |
| **System.Windows.Forms** | FolderBrowserDialog, drag-drop | `MainApp.ps1`, `DailyMotivation.ps1`, `ShellBridge.ps1` | .NET 2.0 |

### 3.2 .NET Classes Used

The following .NET classes are invoked directly without explicit assembly loading:

- **System.Xml.XmlNodeReader** - XAML parsing
- **System.Windows.Markup.XamlReader** - XAML loading
- **System.Threading.Mutex** - Single-instance enforcement
- **System.Windows.Threading.DispatcherTimer** - Countdown timers
- **System.Windows.Media.Animation.DoubleAnimation** - Fade-in effects
- **System.Windows.DataFormats** - Drag-and-drop data handling
- **System.Windows.DragDropEffects** - Drag-and-drop effects
- **System.IO.Path** - Path normalization and validation
- **System.Guid** - Task ID generation

### 3.3 WPF XAML Requirements
- **MainWindow.xaml** - Requires WPF XAML loader
- **Popup.xaml** (inline) - Generated dynamically in `DailyMotivation.ps1`
- **Encoding:** UTF-8 with BOM (required for XAML parser)

---

## 4. Windows API Dependencies

### 4.1 Task Scheduler COM API
- **Interface:** `IScheduledTaskFolder`, `ITaskService`
- **PowerShell Cmdlets Used:**
  - `Get-ScheduledTask`
  - `New-ScheduledTaskAction`
  - `New-ScheduledTaskTrigger`
  - `New-ScheduledTaskSettingsSet`
  - `New-ScheduledTaskPrincipal`
  - `Register-ScheduledTask`
  - `Unregister-ScheduledTask`
- **Module:** `ScheduledTasks` (built into Windows PowerShell 5.1)
- **Used by:** `TaskScheduler.psm1` (all functions)
- **Minimum Windows Version:** Windows 8 / Server 2012

### 4.2 Windows Services API
- **Service:** Task Scheduler (`Schedule`)
- **Cmdlets Used:**
  - `Get-Service`
  - `Start-Service`
- **Used by:** `MainApp.ps1` (startup health check)

### 4.3 Windows Registry (Optional)
- **Purpose:** Shell extension registration (optional feature)
- **Used by:** `Register-ShellExtension.ps1`
- **Keys Modified:**
  - `HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers`
  - `HKEY_CLASSES_ROOT\CLSID\{GUID}`
- **Requires:** Administrator privileges

### 4.4 File System APIs
- **PowerShell Cmdlets:**
  - `Get-ChildItem`, `Test-Path`, `New-Item`, `Remove-Item`, `Copy-Item`
  - `Get-Content`, `Set-Content`
  - `ConvertFrom-Json`, `ConvertTo-Json`
- **Environment Variables:**
  - `$env:APPDATA` - Primary config storage
  - `$env:TEMP` - Fallback config storage (GAP-003)

---

## 5. Build Tools

### 5.1 Compiler
- **Tool:** Invoke-ps2exe (from ps2exe module)
- **Output:** `.exe` files from `.ps1` scripts
- **Target Architecture:** x86/x64 (platform-agnostic)
- **Compilation Flags:**
  - `-NoConsole` - Hide console window
  - `-NoOutput` - Suppress PS2EXE output
  - `-STA` - Single-threaded apartment (required for WPF)
  - `-RequireAdmin $false` - No elevation required
- **Used by:**
  - `.build.ps1` Build task (MainApp.exe, DailyMotivation.exe)
  - `build.ps1` (standalone build)

### 5.2 Packaging
- **Tool:** `Compress-Archive` (built-in PowerShell cmdlet)
- **Output:** `.zip` release packages
- **Used by:** `.build.ps1` Package task (line 222-238)
- **Contents:**
  - Compiled `.exe` files
  - `src/` directory (modules, data, XAML)
  - `LaunchMotivation.bat`

---

## 6. Development Tools

### 6.1 Required Tools
- **Text Editor:** Visual Studio Code (recommended) or PowerShell ISE
- **Version Control:** Git
- **Terminal:** PowerShell 5.1 console

### 6.2 Recommended VS Code Extensions
- **PowerShell** (ms-vscode.powershell)
- **Pester Test Adapter** (pspester.pester-test)
- **YAML** (redhat.vscode-yaml) - for CI/CD workflows

### 6.3 Optional Tools
- **Task Scheduler GUI** (`taskschd.msc`) - for manual task inspection
- **Registry Editor** (`regedit.exe`) - for shell extension debugging
- **Process Monitor** (Sysinternals) - for file/registry tracing

---

## 7. CI/CD Dependencies

### 7.1 GitHub Actions
- **Runner:** `windows-latest` (Windows Server 2022)
- **PowerShell Version:** PowerShell 7.x (GitHub Actions default)
- **Modules Installed:**
  - Pester >= 5.0
  - PSScriptAnalyzer
  - InvokeBuild
  - ps2exe

### 7.2 GitHub Actions Marketplace
- **actions/checkout@v3** - Code checkout
- **actions/upload-artifact@v3** - Artifact uploads
- **EnricoMi/publish-unit-test-result-action/composite@v2** - Test result publishing
- **irongut/CodeCoverageSummary@v1.3.0** - Coverage reports
- **marocchino/sticky-pull-request-comment@v2** - PR comments
- **github/codeql-action/upload-sarif@v2** - Static analysis results

### 7.3 Test Output Formats
- **NUnit XML** - Test results (`TestResults.xml`)
- **JaCoCo XML** - Code coverage (`coverage.xml`)
- **SARIF** - Static analysis results (`scriptanalyzer-results.sarif`)

---

## 8. Version Lock Recommendations

### 8.1 Critical Version Pins

Create a `versions.lock` file or use this table for reference:

```json
{
  "runtime": {
    "powershell": "5.1",
    "dotnet_framework": "4.7.2",
    "windows_min_build": "19041"
  },
  "modules": {
    "Pester": {
      "minimum": "5.0.0",
      "recommended": "5.5.0",
      "locked": "5.5.0"
    },
    "PSScriptAnalyzer": {
      "minimum": "1.20.0",
      "recommended": "1.22.0",
      "locked": "1.22.0"
    },
    "InvokeBuild": {
      "minimum": "5.0.0",
      "recommended": "5.11.1",
      "locked": "5.11.1"
    },
    "ps2exe": {
      "minimum": "1.0.0",
      "recommended": "1.0.13",
      "locked": "1.0.13",
      "alternative": "ps2exe-ng"
    }
  },
  "github_actions": {
    "checkout": "v3",
    "upload-artifact": "v3",
    "publish-unit-test-result-action": "v2",
    "CodeCoverageSummary": "v1.3.0",
    "sticky-pull-request-comment": "v2",
    "codeql-action": "v2"
  }
}
```

### 8.2 Lock File Management

**Option 1: Manual Version Lock**
- Document versions in this file
- Review quarterly for updates

**Option 2: PowerShell Module Lock (Future)**
- Create `modules.lock.json` in project root
- Script to verify/install locked versions:
  ```powershell
  # Check-Modules.ps1 (not yet implemented)
  $lock = Get-Content modules.lock.json | ConvertFrom-Json
  foreach ($module in $lock.modules.PSObject.Properties) {
      $name = $module.Name
      $version = $module.Value.locked
      # Install specific version
      Install-Module -Name $name -RequiredVersion $version -Force
  }
  ```

### 8.3 Version Update Policy

1. **Patch Updates** (e.g., 5.5.0 → 5.5.1): Apply immediately after testing
2. **Minor Updates** (e.g., 5.5.0 → 5.6.0): Review changelog, test in dev, apply within 30 days
3. **Major Updates** (e.g., 5.x → 6.x): Full regression testing, update docs, apply within 90 days

---

## 9. Update Procedures

### 9.1 Dependency Update Workflow

**Step 1: Check for Updates**
```powershell
# List installed modules
Get-Module -ListAvailable Pester, PSScriptAnalyzer, InvokeBuild, ps2exe |
    Select-Object Name, Version

# Check PowerShell Gallery for latest versions
Find-Module Pester, PSScriptAnalyzer, InvokeBuild, ps2exe |
    Select-Object Name, Version
```

**Step 2: Test Update in Isolation**
```powershell
# Install new version side-by-side (don't force)
Install-Module -Name Pester -RequiredVersion 5.6.0 -Scope CurrentUser

# Run full test suite
Invoke-Build Test

# Run static analysis
Invoke-Build Analyze
```

**Step 3: Update Lock File**
- Update `versions.lock` (section 8.1) with new version
- Commit changes: `git commit -m "chore: update Pester to 5.6.0"`

**Step 4: Update CI/CD**
- Update `.github/workflows/test.yml` if module versions are pinned
- Run CI pipeline to verify

**Step 5: Document Breaking Changes**
- Update this file (DEPENDENCIES.md) with any breaking changes
- Update relevant docs (`TESTING.md`, `INSTALL.md`) if needed

### 9.2 Quarterly Dependency Review

**Schedule:** First week of each quarter (Jan, Apr, Jul, Oct)

**Checklist:**
- [ ] Check PowerShell Gallery for module updates
- [ ] Review GitHub Actions marketplace for action updates
- [ ] Check .NET Framework/Windows OS EOL dates
- [ ] Review security advisories for dependencies
- [ ] Test updates in development environment
- [ ] Update version lock file
- [ ] Update CI/CD workflows
- [ ] Document changes in CHANGELOG.md

### 9.3 Emergency Security Updates

If a critical security vulnerability is announced:

1. **Immediate Assessment** (< 4 hours)
   - Determine if vulnerability affects this project
   - Check if patch is available

2. **Rapid Testing** (< 24 hours)
   - Install patched version
   - Run smoke tests (minimal test suite)
   - Deploy to staging/test environment

3. **Production Deployment** (< 48 hours)
   - Update version lock
   - Deploy to production
   - Notify stakeholders

---

## 10. EOL Monitoring Process

### 10.1 Current EOL Status

| Dependency | Current Version | EOL Date | Status | Action Required |
|------------|----------------|----------|--------|----------------|
| Windows 10 | 22H2 | 2025-10-14 | Approaching EOL | Plan migration to Windows 11 |
| PowerShell 5.1 | 5.1.x | Tied to Windows | Extended Support | Monitor Windows lifecycle |
| .NET Framework 4.x | 4.8 | Tied to Windows | Active | None |
| Pester | 5.5.0 | N/A (active) | Active | None |
| PSScriptAnalyzer | 1.22.0 | N/A (active) | Active | None |
| InvokeBuild | 5.11.1 | N/A (active) | Active | None |
| ps2exe | 1.0.13 | Maintenance mode | Consider alternative | Evaluate ps2exe-ng |

### 10.2 Monitoring Resources

**Official Sources:**
- **Windows Lifecycle:** https://docs.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro
- **PowerShell Blog:** https://devblogs.microsoft.com/powershell/
- **.NET Framework Support:** https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-framework
- **PowerShell Gallery:** https://www.powershellgallery.com/

**Community Resources:**
- **GitHub Release Pages:** Monitor repos for deprecation notices
- **PowerShell Community Blog:** https://powershellcommunity.org/

### 10.3 EOL Notification System

**Manual Monitoring** (Current Approach):
- Quarterly dependency review (see 9.2)
- Subscribe to GitHub release notifications for critical modules
- Monitor Windows Admin Center for OS lifecycle alerts

**Automated Monitoring** (Future Enhancement):
- Implement GitHub Dependabot (for GitHub Actions)
- Create PowerShell script to check PSGallery module publish dates
- Set up calendar reminders for Windows/PowerShell EOL dates

### 10.4 Migration Strategy for EOL Dependencies

**When a dependency reaches EOL:**

1. **Assessment Phase** (3 months before EOL)
   - Identify replacement options
   - Estimate migration effort
   - Update project roadmap

2. **Planning Phase** (2 months before EOL)
   - Create migration branch
   - Update dependencies in test environment
   - Run full regression test suite

3. **Execution Phase** (1 month before EOL)
   - Merge migration changes
   - Update documentation
   - Deploy to production before EOL date

4. **Post-Migration** (After EOL)
   - Archive old dependency references
   - Update version lock file
   - Communicate changes to users

---

## 11. Dependency Installation Reference

### 11.1 One-Time Setup (All Dependencies)

```powershell
# Set PSGallery as trusted (optional, avoids prompts)
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Install all development dependencies
Install-Module -Name InvokeBuild -MinimumVersion 5.0 -Scope CurrentUser -Force
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -MinimumVersion 1.20 -Scope CurrentUser -Force
Install-Module -Name ps2exe -MinimumVersion 1.0 -Scope CurrentUser -Force

# Verify installations
Get-Module -ListAvailable InvokeBuild, Pester, PSScriptAnalyzer, ps2exe |
    Format-Table Name, Version, Path
```

**Alternative: Use Built-In Task**
```powershell
# Requires InvokeBuild to be installed first
Invoke-Build InstallDependencies
```

### 11.2 CI/CD Environment Setup

See `.github/workflows/test.yml` for full CI setup. Key commands:

```powershell
# GitHub Actions workflow excerpt
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Force
Install-Module -Name InvokeBuild -Force
Install-Module -Name ps2exe -Force
```

### 11.3 End-User Requirements (No Installation Needed)

End users do **not** need to install any PowerShell modules. The compiled `.exe` files are self-contained and only require:
- Windows 10/11
- PowerShell 5.1 (included)
- .NET Framework 4.x (included)

---

## 12. Troubleshooting

### 12.1 Module Not Found Errors

**Error:** `Module 'Pester' is not installed`

**Solution:**
```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
```

### 12.2 Version Conflicts

**Error:** `The term 'Invoke-Pester' is not recognized` (Pester 3.x vs 5.x)

**Solution:**
```powershell
# Remove old versions
Get-Module Pester -ListAvailable | Where-Object Version -lt 5.0 | Uninstall-Module -Force

# Install correct version
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
```

### 12.3 PS2EXE Build Failures

**Error:** `Invoke-ps2exe: command not found`

**Solution:**
```powershell
# Verify module is installed
Get-Module ps2exe -ListAvailable

# If not installed:
Install-Module ps2exe -Scope CurrentUser -Force

# Import module explicitly
Import-Module ps2exe
```

**Alternative:** Consider `ps2exe-ng` for better .NET 6+ support

### 12.4 WPF Assembly Load Errors

**Error:** `Could not load file or assembly 'PresentationFramework'`

**Solution:**
- Verify .NET Framework 4.x is installed
- Run PowerShell with `-STA` flag (required for WPF)
- Check Windows version (requires Windows 10 build 19041+)

---

## 13. Related Documentation

- **TESTING.md** - Full testing guide with Pester usage examples
- **INSTALL.md** - End-user installation instructions
- **.build.ps1** - Build automation script with module usage
- **Invoke-Tests.ps1** - Test runner with dependency checks
- **.github/workflows/test.yml** - CI/CD pipeline configuration
- **CONTRIBUTING.md** - Developer contribution guidelines

---

## 14. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-09 | System | Initial dependency documentation (CG-004) |

---

## 15. Maintenance Notes

**Document Owner:** Development Team
**Review Frequency:** Quarterly (see section 9.2)
**Last Review Date:** 2026-06-09
**Next Review Date:** 2026-09-09

**Update Triggers:**
- New dependency added to project
- Module version updated
- EOL announcement for existing dependency
- Security vulnerability discovered
- Windows/PowerShell version requirement changes

---

**End of Document**
