# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| `main` / current branch builds | Yes |
| Pre-release / experimental branches | Best effort |
| Historical agent snapshots in `docs/archive/` | No |

This project ships a single-file Windows desktop app. There is no hosted multi-tenant service.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

1. Contact me _privately_.

Include:

- Description of the issue and impact
- Steps to reproduce
- Affected version / commit if known
- Whether a fix or workaround is already known

## Scope

In scope examples:

- Path traversal or unsafe path handling that affects Task Scheduler registration or Explorer launch
- Privilege escalation via context-menu registration or exe path abuse
- Cross-user interference via named mutexes or shared state
- Sensitive data leakage in logs, config files, or error dialogs

## Security design notes

See [docs/security/overview.md](docs/security/overview.md) for the threat model and controls (AppData ACLs, path validation, outcome-log path hashing, context-menu exe guards, popup mutex isolation).

---

_Last updated: 2026-07-23_
