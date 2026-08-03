# Localization / i18n of popup UI strings

**Decision:** Out of scope for the current project phase.

**Reason:** The project is a single-binary Windows utility targeting Windows 10/11 English-language environments. The `main` branch source file carries an explicit `ASCII-only` encoding constraint for PowerShell 5.1 / Windows-1252 safety. No maintainer-approved spec exists for multi-language support, and no issue has been opened to discuss scope, supported locales, or the encoding migration required (ASCII-only → UTF-8) to safely ship non-Latin strings through the ps2exe compilation pipeline.

**Prior requests:**
- #176 — "localize popup countdown and dismiss labels" (closed 2026-08-03, wontfix)
- #177 — "[AG12-011] Localize popup hardcoded copy in DailyMotivation popup" (closed 2026-08-03, wontfix/duplicate)
