# Glossary

**Last Updated:** 2026-06-03

| Term | Definition |
|------|-----------|
| Scheduled Task | A Windows Task Scheduler entry that fires the popup at a specific time |
| Popup | The WPF motivational notification window |
| Snooze | Dismissing the popup temporarily; it reappears after the selected duration (5/15/30/60 min) |
| Accept / Open Folder | The action that completes a scheduled task and opens Windows Explorer |
| Dismiss for Today | A terminal action that cancels all remaining snooze re-triggers without opening the folder (B-11) |
| Undo Window | The 30-second grace period after scheduling during which the task can be cancelled with one click (B-04) |
| Folder Path | The absolute Windows filesystem path to the user's target folder |
| Folder Name | The leaf directory name (last component of the path), shown in the popup subtitle (B-12) |
| Explorer Launcher | The component that calls `explorer.exe` with the target folder path |
| Snooze Loop | The cycle of popup → snooze → reappear that repeats until acceptance or dismissal |
| Task Completion | The state reached when the user clicks "Open Folder" (outcome=Opened) |
| popup_config.json | The local config file read by the popup script — written by the app, never by the user |
| Motivation Repository | The store of motivational messages available for popup display |
| Recent Folders | A persisted list of up to 5 previously scheduled folder paths for quick re-scheduling (B-02) |
| Last Folder | The single most recently scheduled folder, offered as a one-click default on next app launch (B-01) |
| Shell Extension | The optional COM DLL that adds "Schedule for Tomorrow at 2 PM" to the Windows Explorer right-click menu (B-13) |
| History Viewer | The in-app panel displaying past task outcomes parsed from popup_log.txt (B-18) |
| First-Run Overlay | The one-time onboarding card shown on initial app launch (B-07) |
| **CI/CD Pipeline** | Automated workflow (`.github/workflows/test.yml`) that runs PSScriptAnalyzer, Pester tests, and PS2EXE compilation on every push and pull request |
| **Code Coverage** | Percentage of source code lines executed during a Pester test run; project target is 80%+ for module code |
| **Invoke-Build** | PowerShell build automation framework; project uses it via `.build.ps1` for test, analyze, compile, and package tasks |
| **Pester** | PowerShell testing framework (v5.x); used for unit and integration tests in `Tests/` |
| **PSScriptAnalyzer** | Static analysis tool for PowerShell; enforces code quality rules defined in `.PSScriptAnalyzerSettings.psd1` |
| **Quality Gate** | CI/CD enforcement point: tests must pass, coverage must be >=80%, PSScriptAnalyzer must show zero warnings before a PR can merge |
| **Tag Filter** | Pester feature for running a subset of tests by category: `Unit`, `Integration`, `Initialization` |
| **Test Fixture** | Pre-built sample data files in `Tests/Fixtures/` used to simulate realistic inputs in Pester tests |

## Status
> v1.1 DRAFT
