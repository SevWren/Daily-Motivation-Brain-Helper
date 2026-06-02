# Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|-----------|
| R-001 | Task Scheduler service disabled by user/IT policy | Low | High | Detect at startup; show clear error with fix instructions |
| R-002 | Execution policy blocks PowerShell script | Medium | High | Use -ExecutionPolicy Bypass in launcher; document in INSTALL.md |
| R-003 | Folder path deleted or moved before 2 PM | Medium | Medium | Validate path at popup time; show graceful error |
| R-004 | Machine off at scheduled time | High | Low | Configure task to run at next logon |
| R-005 | WPF unavailable (.NET Framework not installed) | Low | High | Check at startup; provide download link |
| R-006 | Multiple popups appearing simultaneously | Low | Medium | Enforce SSOT-006 via mutex/lock at popup startup |
| R-007 | Snooze loop runs indefinitely for days | Medium | Low | Optional: add max-snooze-days config (v1.1) |
| R-008 | Unicode characters in folder path | Medium | Medium | Test with paths containing spaces and special chars |

## Status
> DRAFT
