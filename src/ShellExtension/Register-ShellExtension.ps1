# =============================================================================
# Register-ShellExtension.ps1 -- TASK-NEW-02 / B-13
# Compiles MotivationShellExt.cs and registers the COM shell extension.
# Run ONCE as Administrator after installation.
#
# Usage:
#   Right-click -> Run with PowerShell (as Administrator)
# =============================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$scriptDir  = $PSScriptRoot
$srcFile    = Join-Path $scriptDir "MotivationShellExt.cs"
$outDll     = Join-Path $scriptDir "MotivationShellExt.dll"
$appDataDir = Join-Path $env:APPDATA "DailyMotivationBrainHelper"

Write-Host "Daily Motivation Brain Helper -- Shell Extension Registration" -ForegroundColor Cyan
Write-Host ""

# --- Verify source file ---
if (-not (Test-Path $srcFile)) {
    Write-Error "Source file not found: $srcFile"
    exit 1
}

# --- Compile the C# DLL ---
Write-Host "Compiling shell extension..."
Add-Type -TypeDefinition (Get-Content $srcFile -Raw) `
         -OutputAssembly $outDll `
         -OutputType Library `
         -ReferencedAssemblies "System.dll","Microsoft.CSharp.dll" `
         -ErrorAction Stop
Write-Host "  Compiled: $outDll" -ForegroundColor Green

# --- Copy bridge script to AppData ---
$bridgeSrc = Join-Path $scriptDir "ShellBridge.ps1"
if (Test-Path $bridgeSrc) {
    if (-not (Test-Path $appDataDir)) { New-Item -ItemType Directory $appDataDir -Force | Out-Null }
    Copy-Item $bridgeSrc (Join-Path $appDataDir "ShellBridge.ps1") -Force
    Write-Host "  Bridge script copied to $appDataDir" -ForegroundColor Green
}

# --- Register with regasm ---
$regasm = Join-Path $env:SystemRoot "Microsoft.NET\Framework64\v4.0.30319\regasm.exe"
if (-not (Test-Path $regasm)) {
    $regasm = Join-Path $env:SystemRoot "Microsoft.NET\Framework\v4.0.30319\regasm.exe"
}
if (-not (Test-Path $regasm)) {
    Write-Error "regasm.exe not found. Ensure .NET Framework 4.x is installed."
    exit 1
}

Write-Host "Registering COM server..."
& $regasm $outDll /codebase /nologo 2>&1 | ForEach-Object { Write-Host "  $_" }
Write-Host "  Registered." -ForegroundColor Green

# --- Restart Explorer to pick up the new extension ---
Write-Host ""
Write-Host "Restarting Windows Explorer to apply changes..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process explorer

Write-Host ""
Write-Host "Done! Right-click any folder in Explorer to see:" -ForegroundColor Green
Write-Host "  'Schedule for Tomorrow at 2 PM'" -ForegroundColor Cyan
Write-Host ""
Write-Host "To unregister, run:  regasm /unregister `"$outDll`"" -ForegroundColor Gray
