# Risk Register

**Last Updated:** 2026-06-03
**Last Reviewed**: 2026-06-09

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|-----------|
| R-001 | Task Scheduler service disabled by user/IT policy | Low | High | Detect at startup; show clear error with fix instructions (TASK-012) |
| R-002 | Execution policy blocks PowerShell script | Medium | High | Use -ExecutionPolicy Bypass in launcher; document in INSTALL.md |
| R-003 | Folder path deleted or moved before 2 PM | Medium | Medium | Re-pick prompt in popup (B-05, TASK-007) |
| R-004 | Machine off at scheduled time | High | Low | Configure task to run at next logon (NPR-004) |
| R-005 | WPF unavailable (.NET Framework not installed) | Low | High | Check at startup; provide download link |
| R-006 | Multiple popups appearing simultaneously | Low | Medium | Named mutex enforces SSOT-006 (TASK-006) |
| R-007 | Snooze loop runs indefinitely | Medium | Low | Dismiss for Today provides graceful exit (B-11) |
| R-008 | Unicode characters in folder path | Medium | Medium | Validate path at popup time (TASK-007) |
| R-009 | Shell extension DLL registration requires admin (B-13) | High | Medium | Document as one-time setup step; Register-ShellExtension.ps1 prompts for elevation |
| R-010 | Shell extension conflicts with antivirus/EDR (B-13) | Medium | High | Code-sign the DLL; document exception instructions for common AV products |
| R-011 | Re-pick FolderBrowserDialog inside WPF popup (B-05) | Medium | Medium | Use Add-Type with STA thread check; test on both Win 10 and 11 |
| R-012 | Test dependency version drift (Pester, PSScriptAnalyzer incompatible versions) | Low | Low | `Invoke-Build InstallDependencies` pins versions; CI uses consistent runner |
| R-013 | Notification Engine change introduced without manual test run | Medium | Medium | NOTIFICATION_ENGINE_SPEC.md warning; CONTRIBUTING.md checklist; pre-release regression requirement |
| R-014 | Code coverage drops below 80% threshold | Medium | Low | CI blocks PR merge on coverage regression; developer must add tests or document exception |

## Status
> v1.1 DRAFT
