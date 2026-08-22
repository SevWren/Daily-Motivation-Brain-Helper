<#
.SYNOPSIS
    Installs and configures Git hooks for the repository.

.DESCRIPTION
    Sets core.hooksPath to .githooks and copies hooks into .git/hooks as a fallback.
#>
[CmdletBinding()]
param()

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) {
    $repoRoot = $PSScriptRoot | Split-Path -Parent
}

Write-Host "Configuring Git hooks in: $repoRoot" -ForegroundColor Cyan

# 1. Configure git core.hooksPath to use tracked .githooks directory
git config core.hooksPath .githooks
if ($LASTEXITCODE -eq 0) {
    Write-Host " [OK] git config core.hooksPath set to .githooks" -ForegroundColor Green
} else {
    Write-Warning "Could not set git config core.hooksPath"
}

# 2. Also copy to .git/hooks as a direct fallback
$gitHooksDir = Join-Path $repoRoot ".git/hooks"
$sourceHooksDir = Join-Path $repoRoot ".githooks"

if (Test-Path -LiteralPath $gitHooksDir) {
    Get-ChildItem -Path $sourceHooksDir -File | ForEach-Object {
        $dest = Join-Path $gitHooksDir $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
    }
    Write-Host " [OK] Copied hooks to .git/hooks/" -ForegroundColor Green
}

Write-Host "`nGit hooks installed successfully! Em dash enforcement is active." -ForegroundColor Green
