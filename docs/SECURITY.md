# Security Policy

**Last Reviewed**: 2026-06-09

## Supported Versions
Only the latest release is supported for security fixes.

## Reporting a Vulnerability
Please do NOT open a public GitHub issue for security vulnerabilities.

Email: mmueller07@gmail.com  
Subject line: `[SECURITY] Daily-Motivation-Brain-Helper`

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact

You will receive a response within 72 hours.

## Security Model
- This application runs entirely locally with no network access
- It operates under the current user's account (no elevated privileges at runtime)
- No credentials, tokens, or personal data are stored or transmitted
- The only external interaction is launching Windows Explorer

---

## Secure Coding Guidelines

### 1. PowerShell Secure Coding Standards

#### Script Execution Context
- **Always use `-ExecutionPolicy Bypass`** in launchers to prevent R-002 (execution policy blocks)
- Run scripts in the current user context; avoid unnecessary privilege escalation
- Use `#Requires -Version 5.1` at the top of all PowerShell scripts
- Enable strict mode: `Set-StrictMode -Version Latest`

#### Error Handling
```powershell
# Good: Explicit error handling
try {
    $task = Get-ScheduledTask -TaskName "DailyMotivation" -ErrorAction Stop
} catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
    Write-Error "Task Scheduler service unavailable (R-001)"
    exit 1
}

# Bad: Silent failures
$task = Get-ScheduledTask -TaskName "DailyMotivation" -ErrorAction SilentlyContinue
```

#### Avoid Dynamic Code Execution
```powershell
# Bad: Arbitrary code execution risk
Invoke-Expression $userInput
Invoke-Command -ScriptBlock ([ScriptBlock]::Create($userInput))

# Good: Use structured parameters
& $approvedCommand -Parameter $sanitizedInput
```

### 2. Input Validation Requirements

#### File and Folder Paths
All user-provided paths MUST be validated before use (addresses R-003, R-008):

```powershell
function Test-SafePath {
    param([string]$Path)

    # Check for null or empty
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    # Validate path format
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        return $false
    }

    # Check for invalid characters
    $invalidChars = [System.IO.Path]::GetInvalidPathChars()
    if ($Path.IndexOfAny($invalidChars) -ge 0) {
        return $false
    }

    # Test Unicode handling (R-008)
    try {
        $resolved = [System.IO.Path]::GetFullPath($Path)
        return Test-Path -LiteralPath $resolved -IsValid
    } catch {
        return $false
    }
}
```

#### Task Scheduler Parameters
```powershell
# Validate task names (alphanumeric, no special chars)
if ($TaskName -notmatch '^[a-zA-Z0-9_-]+$') {
    throw "Invalid task name format"
}

# Validate time formats (24-hour HH:mm)
if ($Time -notmatch '^([01]\d|2[0-3]):([0-5]\d)$') {
    throw "Invalid time format. Use HH:mm (24-hour)"
}
```

#### User Input from WPF Forms
```powershell
# Sanitize before display or processing
$sanitized = [System.Security.SecurityElement]::Escape($userInput)

# Length limits
if ($userInput.Length -gt 260) {  # MAX_PATH
    throw "Path exceeds maximum length"
}
```

### 3. Path Traversal Prevention

#### Always Use -LiteralPath
```powershell
# Good: Prevents wildcard expansion and path traversal
Test-Path -LiteralPath $userPath
Get-Content -LiteralPath $configFile

# Bad: Vulnerable to wildcards and injection
Test-Path $userPath
Get-Content $configFile
```

#### Restrict to Approved Base Directories
```powershell
function Assert-PathWithinBounds {
    param(
        [string]$Path,
        [string]$AllowedBase
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullBase = [System.IO.Path]::GetFullPath($AllowedBase)

    if (-not $fullPath.StartsWith($fullBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path traversal detected: $Path is outside allowed directory"
    }
}

# Usage
Assert-PathWithinBounds -Path $userFolder -AllowedBase $env:USERPROFILE
```

#### Canonicalize Paths
```powershell
# Resolve relative paths and symbolic links
$canonicalPath = [System.IO.Path]::GetFullPath($userInput)

# Verify it still points where expected
if (-not $canonicalPath.StartsWith("C:\Users\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path outside user directory"
}
```

### 4. Command Injection Prevention

#### Launching External Processes
```powershell
# Good: Use Start-Process with explicit parameters
Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$safePath`"" -NoNewWindow

# Bad: Shell injection risk
cmd.exe /c "explorer.exe /select,$userPath"
Invoke-Expression "explorer.exe /select,$userPath"
```

#### Task Scheduler Actions
```powershell
# Good: Structured parameters
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Bad: String concatenation with user input
$action = New-ScheduledTaskAction -Execute "cmd.exe /c $userCommand"
```

#### Registry Operations
```powershell
# Good: Use cmdlets with parameters
Set-ItemProperty -Path "HKCU:\Software\DailyMotivation" -Name "FolderPath" -Value $path

# Bad: Using reg.exe with string interpolation
& reg.exe add "HKCU\Software\DailyMotivation" /v FolderPath /d "$userPath"
```

### 5. JSON Parsing Security

#### Safe Deserialization
```powershell
# Good: Use ConvertFrom-Json with validation
try {
    $config = Get-Content -LiteralPath $configFile -Raw -ErrorAction Stop
    $data = $config | ConvertFrom-Json -ErrorAction Stop

    # Validate expected structure
    if (-not $data.PSObject.Properties.Name -contains "FolderPath") {
        throw "Missing required field: FolderPath"
    }

    # Type validation
    if ($data.FolderPath -isnot [string]) {
        throw "FolderPath must be a string"
    }

} catch {
    Write-Error "Failed to parse configuration: $_"
    exit 1
}
```

#### Depth and Size Limits
```powershell
# Check file size before parsing (prevent DoS)
$maxSize = 1MB
$fileInfo = Get-Item -LiteralPath $configFile
if ($fileInfo.Length -gt $maxSize) {
    throw "Configuration file exceeds maximum size"
}

# ConvertFrom-Json has built-in depth limits (default 1024)
# For custom depth: Use -Depth parameter (PS 6.2+)
```

#### Avoid Dynamic Type Creation
```powershell
# Bad: Dynamic type instantiation from JSON
$type = $jsonData.TypeName
$object = New-Object -TypeName $type  # Arbitrary code execution risk

# Good: Whitelist allowed types
$allowedTypes = @("System.String", "System.Int32")
if ($jsonData.TypeName -notin $allowedTypes) {
    throw "Type not allowed: $($jsonData.TypeName)"
}
```

### 6. File Permission Guidelines

#### Configuration Files
```powershell
# Set restrictive ACLs on config files
$acl = Get-Acl -LiteralPath $configFile
$acl.SetAccessRuleProtection($true, $false)  # Disable inheritance

# Grant only current user full control
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $identity,
    "FullControl",
    "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl -LiteralPath $configFile -AclObject $acl
```

#### Registry Permissions
```powershell
# Verify registry key is under HKCU (current user only)
if ($registryPath -notmatch '^HKCU:\\') {
    throw "Registry operations must be under HKCU"
}

# Avoid HKLM (requires elevation)
```

#### Shell Extension DLL (R-009)
```powershell
# Document that registration requires one-time elevation
# Verify DLL signature before registration
$signature = Get-AuthenticodeSignature -LiteralPath $dllPath
if ($signature.Status -ne "Valid") {
    Write-Warning "DLL is not signed or signature is invalid (R-010)"
}

# Use regsvr32 with explicit path
Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s `"$dllPath`"" -Verb RunAs -Wait
```

### 7. Credential Handling

#### Never Store Credentials in Code
```powershell
# Bad: Hardcoded secrets
$apiKey = "sk_live_abc123..."
$password = "MyPassword123"

# Bad: Plaintext in config files
@{ ApiKey = "sk_live_abc123..." } | ConvertTo-Json | Set-Content config.json
```

#### This Application's Policy
**This application deliberately stores NO credentials, tokens, or API keys.** All operations are local-only:
- No API calls
- No authentication required
- No network access
- No secret management needed

If future features require credentials:
1. Use Windows Credential Manager (CredentialManager PowerShell module)
2. Use Data Protection API (DPAPI) for encryption
3. Never log or display credentials
4. Implement automatic credential rotation where possible

### 8. UAC Elevation Best Practices

#### Principle of Least Privilege
- **Normal operation runs without elevation** (R-009)
- Only Register-ShellExtension.ps1 requires admin rights
- Check if already elevated before prompting

```powershell
function Test-IsElevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Request elevation only when necessary
if (-not (Test-IsElevated)) {
    if ($RequiresElevation) {
        Write-Host "This operation requires administrator privileges."
        Start-Process powershell.exe -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}
```

#### Validate Elevation Requests
```powershell
# Document WHY elevation is needed
<#
.SYNOPSIS
    Registers shell extension DLL (requires elevation)
.DESCRIPTION
    Registers DailyMotivation.ShellExtension.dll with Windows Explorer.
    This is a ONE-TIME setup operation that requires administrator rights
    to write to HKEY_CLASSES_ROOT.
#>
```

#### Avoid Persistent Elevation
```powershell
# Bad: Running entire app as admin
# Good: Elevate only specific registration script, then drop back to user context
```

### 9. Code Review Checklist

Before merging any code, verify:

#### Input Validation
- [ ] All file paths validated with `Test-SafePath`
- [ ] All user inputs sanitized and length-checked
- [ ] Unicode characters tested (R-008)
- [ ] Path traversal prevention applied

#### Command Execution
- [ ] No `Invoke-Expression` or `Invoke-Command` with user input
- [ ] All `Start-Process` calls use `-FilePath` and `-ArgumentList` separately
- [ ] No string interpolation in shell commands
- [ ] Task Scheduler actions use structured parameters

#### Error Handling
- [ ] Try-catch blocks around all I/O operations
- [ ] Error messages don't leak sensitive paths or system info
- [ ] Graceful degradation when Task Scheduler unavailable (R-001)
- [ ] WPF dependency check implemented (R-005)

#### File Operations
- [ ] `-LiteralPath` used instead of `-Path` for user-provided paths
- [ ] File permissions verified restrictive (current user only)
- [ ] Paths canonicalized before comparison
- [ ] Size limits enforced on parsed files

#### JSON and Configuration
- [ ] JSON structure validated after parsing
- [ ] Type checking on all deserialized values
- [ ] No dynamic type instantiation from config
- [ ] Configuration file permissions restricted

#### Privilege Management
- [ ] No unnecessary elevation requests
- [ ] Elevation documented with clear justification
- [ ] Registry writes confined to HKCU
- [ ] Shell extension registration isolated to dedicated script

#### Testing
- [ ] Unit tests cover all input validation functions
- [ ] Negative test cases (malicious input) included
- [ ] Edge cases tested (empty strings, MAX_PATH, Unicode)
- [ ] Manual testing on clean Windows 10 and 11 VMs

### 10. Security Testing Procedures

#### Pre-Release Security Testing

**Phase 1: Static Analysis**
```powershell
# Run PSScriptAnalyzer with security rules
Invoke-ScriptAnalyzer -Path .\src -Recurse -Settings @{
    Severity = @('Error', 'Warning', 'Information')
    IncludeRules = @(
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSUsePSCredentialType'
    )
}
```

**Phase 2: Input Fuzzing**
Test with malicious inputs:
```powershell
$maliciousInputs = @(
    "..\..\..\Windows\System32\calc.exe",    # Path traversal
    "C:\Users\`;calc.exe`#",                  # Command injection
    "C:\Folder`0\Null",                       # Null byte injection
    "CON", "PRN", "AUX", "NUL",               # Reserved names
    "\\?\C:\VeryLongPath" + ("A" * 300),     # Buffer overflow attempt
    "C:\Folder`r`n& calc &",                  # CRLF injection
    "C:\用户\文件夹",                          # Unicode (R-008)
    "C:\Folder\  ",                           # Trailing spaces
    "'`"; DROP TABLE --"                      # SQL injection pattern (N/A but test parser)
)

foreach ($input in $maliciousInputs) {
    try {
        Test-SafePath -Path $input
        # Should reject all malicious inputs
    } catch {
        Write-Host "✓ Correctly rejected: $input"
    }
}
```

**Phase 3: Privilege Testing**
```powershell
# Verify normal operation doesn't require elevation
Test-IsElevated | Should -Be $false

# Verify Task Scheduler task runs as current user
$task = Get-ScheduledTask -TaskName "DailyMotivation"
$task.Principal.UserId | Should -Be $env:USERNAME
$task.Principal.RunLevel | Should -Be "Limited"  # Not "Highest"
```

**Phase 4: Isolation Testing**
- Run in sandboxed VM (Windows Sandbox)
- Verify no network connections: `netstat -ano` during operation
- Monitor file system access: `Process Monitor` filtered to application
- Check registry writes confined to HKCU

**Phase 5: Antivirus/EDR Testing (R-010)**
Test shell extension with:
- Windows Defender (enabled)
- Common enterprise EDR solutions (if available)
- Document any false positives and mitigation steps

#### Continuous Security Monitoring

**Dependency Scanning**
```powershell
# Check for vulnerable PowerShell modules (if any external modules added)
# Currently only uses built-in modules (no external dependencies)
Get-Module -ListAvailable | Where-Object { $_.PrivateData.PSData.Prerelease -eq $true }
```

**Automated Regression Tests**
- Security unit tests run in CI pipeline (CONTRIBUTING.md)
- Code coverage >80% including validation functions (R-014)
- Manual notification engine test before release (R-013)

**Incident Response**
If a security issue is discovered:
1. Follow responsible disclosure timeline (72-hour response)
2. Issue hotfix release within 7 days of confirmation
3. Update RISK_REGISTER.md with new risk
4. Add regression test to prevent recurrence
5. Notify users via GitHub Security Advisory

---

## Security-Related Risks

See [RISK_REGISTER.md](RISK_REGISTER.md) for tracked security risks:
- **R-002**: Execution policy blocks (mitigated with `-ExecutionPolicy Bypass`)
- **R-008**: Unicode characters in folder paths (validation required)
- **R-009**: Shell extension DLL registration requires elevation (documented one-time setup)
- **R-010**: Shell extension conflicts with antivirus (code signing + documentation)

## Security Audit History

| Date | Auditor | Scope | Findings |
|------|---------|-------|----------|
| 2026-06-09 | Internal | Initial secure coding guidelines | N/A (baseline) |

---

## Additional Resources

- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/security-features)
- [CWE Top 25 Most Dangerous Software Weaknesses](https://cwe.mitre.org/top25/)
- Project RISK_REGISTER.md for current security risks and mitigations
