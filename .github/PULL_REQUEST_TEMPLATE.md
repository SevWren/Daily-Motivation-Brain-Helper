## Summary

<!-- What does this PR change and why? -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / cleanup
- [ ] Documentation
- [ ] Tests only
- [ ] CI / tooling

## Checklist

- [ ] I used domain terms from [`CONTEXT.md`](../CONTEXT.md)
- [ ] Main mode does **not** show startup popups / blocking dialogs
- [ ] Avoided PS7-only runtime syntax that breaks ps2exe (.NET Framework 4.x)
- [ ] Tests updated or added when behavior changed
- [ ] **Windows 10/11 PowerShell 7** test results considered (not Linux-only for Windows suites)
- [ ] Docs updated under `docs/` or `manual/` when user/dev surface changed
- [ ] No secrets or personal handoff content committed

## Test plan

```powershell
.\Invoke-Tests.ps1
# or focused:
# .\Invoke-Tests.ps1 -Tag <Tag>
```

- [ ] Tests run locally on Windows (or platform-safe subset only, with reason)

## Related issues

<!-- Fixes #123 -->
<!-- Closes #456 -->
<!-- Resolves #789 -->