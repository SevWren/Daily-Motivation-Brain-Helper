# Non-Product Requirements (NPR)

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

## Status
> DRAFT
