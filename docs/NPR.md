# Non-Product Requirements (NPR)

**Last Reviewed**: 2026-06-09

## NPR-001 — Simplicity
The user must never be required to edit:
- JSON or YAML files
- PowerShell or batch scripts
- Registry keys
- Any configuration file

## NPR-002 — Accessibility
The interface must be understandable by non-technical users, including elderly users and users with cognitive impairments. All UI text must be plain English with no technical jargon.

## NPR-003 — Installation Simplicity
Installation must complete in 3 clicks or fewer. No developer tools, package managers, or elevated privileges should be required for normal use.

## NPR-004 — Reliability
If the machine was off or sleeping at 2 PM, the popup must fire on the next login/wake within the same day.

## NPR-005 — Offline Operation
The application must function entirely offline. No internet connection required at any point.

## NPR-006 — Resource Usage
Idle memory footprint must remain under 100 MB.

## NPR-007 — No Residual Processes
The application must not leave background processes running when not actively scheduling or displaying a popup.

## NPR-008 -- Maintainability

All PowerShell modules must maintain automated Pester test coverage of **80% or higher**.
New functions added to `ConfigManager.psm1` or `TaskScheduler.psm1` require corresponding
tests in `Tests/Unit/` before the PR is merged.

**Rationale:** Test coverage protects against regression as the codebase evolves. The
80% threshold was chosen to allow practical coverage of the non-UI code paths while
acknowledging that WPF components cannot be covered by Pester.

## NPR-009 -- Code Quality

All PowerShell code (`.ps1`, `.psm1`) must pass **PSScriptAnalyzer** static analysis
with **zero warnings** using the project configuration in `.PSScriptAnalyzerSettings.psd1`.

**Rationale:** Enforced via CI/CD. Any warning indicates a potential bug (alias misuse,
scope issue, encoding problem) that should be fixed before shipping.

## NPR-010 -- Build Automation

The project must provide a **single-command build** that runs analysis, tests, and
compilation: `Invoke-Build` (uses `.build.ps1` at project root).

**Rationale:** Reproducible builds reduce the "works on my machine" class of problems.
All distribution artifacts must be produced by the automated build pipeline, not
manual steps.

## Status
> DRAFT
