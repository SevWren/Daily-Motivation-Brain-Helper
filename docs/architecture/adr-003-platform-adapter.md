# ADR-003: Optional platform adapter for tests

## Status

Accepted

## Context

Core behavior depends on Windows Task Scheduler, WPF, and registry. Full fidelity tests require Windows 10/11, but CI and contributors may also run subsets on Linux PowerShell 7.

## Decision

Introduce `$script:Platform` (default `$null` = real Windows APIs). Tests may inject a HeadlessPlatform-style object implementing scheduling/dialog operations so pure logic can run without Task Scheduler.

Windows-specific suites (`TaskScheduler.Tests.ps1`, `ContextMenu.Tests.ps1`, integration tests) remain **Windows-primary**. Platform tests (`*.Platform.Tests.ps1`, etc.) are the Linux-safe surface.

## Consequences

### Positive

- Faster unit tests without flaky OS coupling
- Partial CI on non-Windows is possible for adapter-covered paths
- Production path stays simple when `$script:Platform` is null

### Negative

- Risk of false confidence if Linux-only results are treated as full validation
- Mocks can diverge from real Task Scheduler / CIM behavior

## Related

- [Testing strategy](../testing/strategy.md)
- [CLAUDE.md](../../CLAUDE.md) test validation rules
