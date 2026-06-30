#!/usr/bin/env python3
"""
Fix AG9-001: Add [CmdletBinding()] to functions that need it
"""
import re

# Read the file
with open('DailyMotivation.ps1', 'r', encoding='utf-8') as f:
    content = f.read()

# Functions to fix based on test failures
functions_to_fix = [
    'Write-DLog',
    'Initialize-AppData',
    'Get-Config',
    'Save-Config',
    'Get-PopupConfig',
    'Set-PopupConfig',
    'Write-OutcomeLog'
]

for func_name in functions_to_fix:
    # Pattern 1: function NAME { param(...) }
    pattern1 = rf'(function {re.escape(func_name)} \{{\n)(\s+)(param\()'
    replacement1 = r'\1\2[CmdletBinding()]\n\2\3'
    content = re.sub(pattern1, replacement1, content)

    # Pattern 2: function NAME { <# comment #> ... (no param yet)
    pattern2 = rf'(function {re.escape(func_name)} \{{\n)(\s+)(<#)'
    replacement2 = r'\1\2[CmdletBinding()]\n\2param()\n\2\3'
    # Only apply if [CmdletBinding()] is not already there
    if f'function {func_name}' in content and '[CmdletBinding()]' not in content[content.find(f'function {func_name}'):content.find(f'function {func_name}') + 200]:
        content = re.sub(pattern2, replacement2, content)

# Write back
with open('DailyMotivation.ps1', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed AG9-001: Added [CmdletBinding()] to all target functions")
