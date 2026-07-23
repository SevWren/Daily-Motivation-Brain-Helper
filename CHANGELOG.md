# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/) where version
numbers are published (current build metadata: `2.0.0.0` via `build.ps1` / ps2exe).

## [Unreleased]

### Added

- `manual/` user documentation tree: getting-started, guides, troubleshooting, reference
- `docs/archive/` and `docs/reports/` indexes linking historical agent reports and diagnostics
- `docs/reference/functions.md` public function inventory for all 32 script functions
- `docs/plans/`, `docs/reviews/`, `docs/ideas/` stub directories completing the `docs/` tree
- `AGENTS.md` minimal agent orientation redirecting to `CLAUDE.md`
- Documentation section in `README.md` linking `docs/` and `manual/`

## [2.0.0-docs] - 2026-07-22

### Added

- Full governance documentation: `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`
- Developer docs tree: `docs/architecture/`, `docs/development/`, `docs/testing/`, `docs/security/`, `docs/reference/`
- Architecture decision records: `adr-001-single-file-exe.md`, `adr-002-popup-handoff.md`, `adr-003-platform-adapter.md`
- Architecture overview with Mermaid mode-flow, handoff-sequence, task-lifecycle, and popup-outcome diagrams
- GitHub community files: issue templates (bug, feature), PR template, `CODEOWNERS`, `dependabot.yml`
- `.editorconfig` and `.gitattributes`
- Domain glossary refresh in `CONTEXT.md` (Open Folder label, hashed outcome log, full task statuses, mutex naming)

## [2.0.0] - 2026-07

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

[Unreleased]: https://github.com/SevWren/Daily-Motivation-Brain-Helper/compare/v2.0.0...HEAD
[2.0.0-docs]: https://github.com/SevWren/Daily-Motivation-Brain-Helper/compare/v2.0.0...v2.0.0-docs
[2.0.0]: https://github.com/SevWren/Daily-Motivation-Brain-Helper/releases/tag/v2.0.0
