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

1. Prefer GitHub **Security Advisories** / private vulnerability reporting on the repository (if enabled).
2. Otherwise contact the maintainer privately via the GitHub profile linked from the repository owner (`SevWren`).

Include:

- Description of the issue and impact
- Steps to reproduce
- Affected version / commit if known
- Whether a fix or workaround is already known

You should receive an acknowledgement when the report is seen. We aim to triage within a reasonable window for a small project and will coordinate disclosure after a fix is available when practical.

## Scope

In scope examples:

- Path traversal or unsafe path handling that affects Task Scheduler registration or Explorer launch
- Privilege escalation via context-menu registration or exe path abuse
- Cross-user interference via named mutexes or shared state
- Sensitive data leakage in logs, config files, or error dialogs
- Code injection via XAML/text rendering of untrusted folder names or messages

Out of scope examples:

- Issues that require physical access or an already-compromised user account with full interactive control
- Social engineering the user into scheduling a malicious folder
- Vulnerabilities only present in unmaintained historical snapshots under `docs/archive/`

## Security design notes

See [docs/security/overview.md](docs/security/overview.md) for the threat model and controls (AppData ACLs, path validation, outcome-log path hashing, context-menu exe guards, popup mutex isolation).

---

_Last updated: 2026-07-23_
