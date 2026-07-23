# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/) where version
numbers are published (current build metadata: `2.0.0.0` via `build.ps1` / ps2exe).

## [Unreleased]

### Added

- Full documentation set: `docs/`, `manual/`, `SECURITY.md`, `CONTRIBUTING.md`, community GitHub templates
- Domain glossary refresh in `CONTEXT.md` (Open Folder label, hashed outcome log, full task statuses, mutex naming)

### Changed

- Documentation structure aligned to developer (`docs/`) and user (`manual/`) roots

## [2.0.0] - 2026-06 / 2026-07

Project restart on PowerShell 7 with single-file architecture.

### Added

- Single-file `DailyMotivation.ps1` → `DailyMotivation.exe` via ps2exe (`-STA -noConsole`)
- Main, popup, and setfolder execution modes
- WPF main window and popup UI with countdown, snooze, dismiss, path-missing panel
- Windows Task Scheduler integration for MotivationTasks
- Explorer context menu verb: "Set as tomorrow's folder (Daily Motivation)"
- AppData config: `config.json`, `popup_config.json`, `tasks.json`, `popup_log.txt`
- Outcome log path hashing (SHA-256) and log rotation
- Platform adapter for HeadlessPlatform testing on non-Windows CI paths
- Pester 5 test suite (`Invoke-Tests.ps1`) with unit and integration coverage
- GitHub Actions: tests, PSScriptAnalyzer, ps2exe build, coverage artifacts
- Security, performance, UX/accessibility, and Task Scheduler hardening passes (see `docs/archive/`)

### Security

- Path validation (traversal / invalid characters) for scheduled folders
- Context menu registration restricted to compiled `.exe` paths; System32 rejected
- Popup mutex scoped per user and session
- Popup config write mutex
- AppData directory ACL hardening on initialize
- Safe error message handling for user-facing dialogs

### Fixed

- Extensive Task Scheduler and Pester reliability fixes during the PowerShell 7 restart
- Config defaults restoration and scheduling access-denied paths
- UI disposal and accessibility (tab order, automation names)

## [1.x] - historical

Earlier multi-file / pre-restart iterations lived outside the current single-file layout.
Historical agent completion reports are preserved under [docs/archive/](docs/archive/README.md).

[Unreleased]: https://github.com/SevWren/Daily-Motivation-Brain-Helper/compare/HEAD
[2.0.0]: https://github.com/SevWren/Daily-Motivation-Brain-Helper
