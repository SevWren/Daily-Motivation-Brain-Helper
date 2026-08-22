<#
.SYNOPSIS
    Scans files or staged git diffs for literal em dashes (Unicode U+2014) and enforces rejection.

.DESCRIPTION
    Checks target files for prohibited em dash characters. When violations are found, outputs
    a structured, machine-parseable report with line numbers, context snippets, and an
    unambiguous Mandate tailored for AI coding agents / LLMs, then exits with code 1.

.PARAMETER Mode
    Specifies the scanning mode: 'Staged' (default), 'All', 'CommitMsg', 'Range', or 'Path'.

.PARAMETER CommitMsgFile
    Path to commit message file when Mode is 'CommitMsg'.

.PARAMETER Range
    Git revision range to inspect (e.g., 'origin/main..HEAD').

.PARAMETER Path
    Optional specific file or folder path to scan.
#>
[CmdletBinding()]
param(
    [ValidateSet('Staged', 'All', 'CommitMsg', 'Range', 'Path')]
    [string]$Mode = 'Staged',

    [string]$CommitMsgFile = '',

    [string]$Range = '',

    [string]$Path = ''
)

$TargetChar = [char]0x2014
$UnicodeHex = 'U+2014'

$BinaryExtensions = @(
    '.exe', '.dll', '.bin', '.pdf', '.png', '.jpg', '.jpeg', '.gif',
    '.ico', '.zip', '.tar', '.gz', '.7z', '.woff', '.woff2', '.ttf', '.eot'
)

function Test-IsBinaryFile {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $true }
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ($BinaryExtensions -contains $ext) { return $true }
    return $false
}

function Get-FileCategory {
    param([string]$FilePath)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    $name = [System.IO.Path]::GetFileName($FilePath)

    if ($name -match 'COMMIT_EDITMSG|commit-msg') {
        return 'COMMIT_MESSAGE'
    }
    if ($ext -in @('.ps1', '.psm1', '.psd1', '.py', '.js', '.jsx', '.ts', '.tsx', '.sh', '.bash', '.cs', '.go', '.rs', '.c', '.cpp', '.h', '.java', '.json', '.yaml', '.yml', '.toml', '.xml')) {
        return 'CODE_OR_SCRIPT'
    }
    if ($ext -in @('.md', '.markdown', '.txt', '.rst', '.adoc', '.html', '.htm', '.tex')) {
        return 'DOCUMENTATION'
    }
    return 'OTHER_TEXT'
}

$Violations = [System.Collections.Generic.List[PSCustomObject]]::new()

function Scan-File {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return }
    if (Test-IsBinaryFile -FilePath $FilePath) { return }

    $category = Get-FileCategory -FilePath $FilePath
    $lineNum = 0

    try {
        $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)
        foreach ($line in $lines) {
            $lineNum++
            if ($line.Contains($TargetChar)) {
                $colNum = $line.IndexOf($TargetChar) + 1
                $Violations.Add([PSCustomObject]@{
                    File        = $FilePath
                    Category    = $category
                    LineNumber  = $lineNum
                    Column      = $colNum
                    LineContent = $line
                })
            }
        }
    } catch {
        # Fallback if file read fails
    }
}

# Collect target files based on mode
switch ($Mode) {
    'CommitMsg' {
        if ($CommitMsgFile -and (Test-Path -LiteralPath $CommitMsgFile)) {
            Scan-File -FilePath $CommitMsgFile
        }
    }
    'Range' {
        if ($Range) {
            $rangeFiles = & git diff --name-only --diff-filter=ACM $Range 2>$null
            if ($rangeFiles) {
                foreach ($file in $rangeFiles) {
                    if ($file -and (Test-Path -LiteralPath $file)) {
                        Scan-File -FilePath $file
                    }
                }
            }
        }
    }
    'All' {
        $trackedFiles = & git ls-files 2>$null
        if ($LASTEXITCODE -eq 0 -and $trackedFiles) {
            foreach ($file in $trackedFiles) {
                if ($file -and (Test-Path -LiteralPath $file)) {
                    Scan-File -FilePath $file
                }
            }
        } else {
            Get-ChildItem -Recurse -File | ForEach-Object { Scan-File -FilePath $_.FullName }
        }
    }
    'Path' {
        if ($Path -and (Test-Path -LiteralPath $Path)) {
            if ((Get-Item -LiteralPath $Path) -is [System.IO.DirectoryInfo]) {
                Get-ChildItem -LiteralPath $Path -Recurse -File | ForEach-Object { Scan-File -FilePath $_.FullName }
            } else {
                Scan-File -FilePath $Path
            }
        }
    }
    'Staged' {
        $stagedFiles = & git diff --cached --name-only --diff-filter=ACM 2>$null
        if ($stagedFiles) {
            foreach ($file in $stagedFiles) {
                if ($file -and (Test-Path -LiteralPath $file)) {
                    Scan-File -FilePath $file
                }
            }
        }
    }
}

if ($Violations.Count -gt 0) {
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("================================================================================")
    [Console]::Error.WriteLine(" 🛑 [GIT HOOK BLOCKED] EM DASH POLICY VIOLATION DETECTED ($($Violations.Count) INSTANCES)")
    [Console]::Error.WriteLine("================================================================================")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("The git operation was REJECTED because the prohibited literal em dash character")
    [Console]::Error.WriteLine("(Unicode U+2014 / UTF-8 0xE2 0x80 0x94) was found in your changes.")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("--- OFFENDING LOCATIONS --------------------------------------------------------")

    foreach ($v in $Violations) {
        [Console]::Error.WriteLine("  • [FILE] $($v.File)")
        [Console]::Error.WriteLine("    [TYPE] Category: $($v.Category) | Line $($v.LineNumber), Column $($v.Column)")
        [Console]::Error.WriteLine("    [CODE] $($v.LineContent)")
        $pointerPad = if ($v.Column -gt 1) { ' ' * ($v.Column - 1) } else { '' }
        [Console]::Error.WriteLine("    [SPOT] ${pointerPad}^^^ [FORBIDDEN CHARACTER: EM DASH ($UnicodeHex)]")
        [Console]::Error.WriteLine("")
    }

    [Console]::Error.WriteLine("--------------------------------------------------------------------------------")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("================================================================================")
    [Console]::Error.WriteLine(" 📋 MANDATE FOR AI CODING AGENT / LLM (MANDATORY INSTRUCTIONS)")
    [Console]::Error.WriteLine("================================================================================")
    [Console]::Error.WriteLine("1. ZERO-TOLERANCE POLICY: Literal em dashes (Unicode U+2014) are strictly prohibited")
    [Console]::Error.WriteLine("   in this repository across all scripts, code, documentation, comments, and messages.")
    [Console]::Error.WriteLine("2. DO NOT BYPASS: Do not use '--no-verify' or force flags to circumvent this check.")
    [Console]::Error.WriteLine("3. CONTEXT-AWARE REPAIR: You must rewrite the offending content according to its file")
    [Console]::Error.WriteLine("   category and semantic purpose:")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("💡 RESOLUTION PROTOCOL BY CONTEXT:")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  [A] SCRIPT & CODE FILES (.ps1, .py, .js, .ts, .sh, .cs, .json, etc.):")
    [Console]::Error.WriteLine("      • CLI Flags / Operators: If an em dash was inserted for a flag or operator,")
    [Console]::Error.WriteLine("        replace with standard ASCII hyphen '-' or '--'.")
    [Console]::Error.WriteLine("      • String Literals / UI text: Replace with ' - ' or ':' or rewrite the text.")
    [Console]::Error.WriteLine("      • Char Matching / Regex: If testing for U+2014, use escape sequences")
    [Console]::Error.WriteLine("        (e.g., '\u2014' or [char]0x2014) rather than a raw literal character.")
    [Console]::Error.WriteLine("      • Code Comments: Rephrase comments using standard ASCII punctuation ('--', '-', ':').")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  [B] DOCUMENTATION & PROSE (.md, .txt, .rst, docs, README):")
    [Console]::Error.WriteLine("      • Spaced Hyphen / Double Hyphen: Replace em dash with ' - ' or '--'.")
    [Console]::Error.WriteLine("      • Colon / Semicolon: Use ':' for explanations/definitions or ';' between clauses.")
    [Console]::Error.WriteLine("      • Parentheses: Wrap parenthetical remarks in '( ... )'.")
    [Console]::Error.WriteLine("      • Sentence Splitting: Split the run-on sentence into two distinct sentences.")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  [C] COMMIT MESSAGES:")
    [Console]::Error.WriteLine("      • Replace em dash with ' - ' or ':' or rephrase the commit summary.")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("🚀 REQUIRED AGENT ACTION SEQUENCE:")
    [Console]::Error.WriteLine("   Step 1: Inspect each file and line number listed in the report above.")
    [Console]::Error.WriteLine("   Step 2: Edit the lines to eliminate the em dash using the proper Context Resolution Rule.")
    [Console]::Error.WriteLine("   Step 3: Stage the corrected files: git add <files>")
    [Console]::Error.WriteLine("   Step 4: Retry your git commit / git push command.")
    [Console]::Error.WriteLine("================================================================================")
    [Console]::Error.WriteLine("")

    exit 1
}

exit 0
