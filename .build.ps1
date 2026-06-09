#Requires -Version 5.1
<#
.SYNOPSIS
    Build script for Daily Motivation Brain Helper

.DESCRIPTION
    Modern PowerShell build script using Invoke-Build pattern.
    Supports clean, analyze, test, and build tasks.

.EXAMPLE
    Invoke-Build
    Runs default build: Clean -> Analyze -> Test -> Build

.EXAMPLE
    Invoke-Build Test
    Runs only tests

.EXAMPLE
    Invoke-Build Build -Verbose
    Builds EXE with verbose output

.NOTES
    Requires: Invoke-Build, PSScriptAnalyzer, Pester, ps2exe modules
    Install: Install-Module InvokeBuild, PSScriptAnalyzer, Pester, ps2exe -Scope CurrentUser
#>

# Build configuration
$script:Config = @{
    ProjectRoot = $PSScriptRoot
    SourcePath = Join-Path $PSScriptRoot 'src'
    TestsPath = Join-Path $PSScriptRoot 'Tests'
    OutputPath = Join-Path $PSScriptRoot 'Output'
    DocsPath = Join-Path $PSScriptRoot 'docs'
    MainAppScript = Join-Path $PSScriptRoot 'src\MainApp.ps1'
    PopupScript = Join-Path $PSScriptRoot 'src\DailyMotivation.ps1'
    MainAppExe = Join-Path $PSScriptRoot 'Output\DailyMotivationBrainHelper.exe'
    PopupExe = Join-Path $PSScriptRoot 'Output\DailyMotivation.exe'
}

# Synopsis: Default build task
task . Clean, Analyze, Test, Build

# Synopsis: Clean output directory
task Clean {
    if (Test-Path $script:Config.OutputPath) {
        Write-Build Green "Cleaning output directory: $($script:Config.OutputPath)"
        Remove-Item -Path $script:Config.OutputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:Config.OutputPath -Force | Out-Null
}

# Synopsis: Run PSScriptAnalyzer
task Analyze {
    Write-Build Green "Running PSScriptAnalyzer..."

    # Check if PSScriptAnalyzer is installed
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Build Yellow "PSScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer"
        return
    }

    Import-Module PSScriptAnalyzer

    # Analyze PowerShell files
    $filesToAnalyze = @(
        Get-ChildItem -Path $script:Config.SourcePath -Filter *.ps1 -Recurse
        Get-ChildItem -Path $script:Config.SourcePath -Filter *.psm1 -Recurse
    )

    $settingsPath = Join-Path $script:Config.ProjectRoot '.PSScriptAnalyzerSettings.psd1'
    $analyzerParams = @{
        Path = $filesToAnalyze
        Recurse = $false
    }

    if (Test-Path $settingsPath) {
        $analyzerParams['Settings'] = $settingsPath
        Write-Build Cyan "Using PSScriptAnalyzer settings: $settingsPath"
    }

    $results = Invoke-ScriptAnalyzer @analyzerParams

    if ($results) {
        Write-Build Yellow "PSScriptAnalyzer found $($results.Count) issue(s):"
        $results | Format-Table -AutoSize | Out-String | Write-Build

        $errors = $results | Where-Object Severity -eq 'Error'
        if ($errors) {
            throw "PSScriptAnalyzer found $($errors.Count) error(s). Build failed."
        }
    } else {
        Write-Build Green "✅ PSScriptAnalyzer: No issues found"
    }
}

# Synopsis: Run Pester tests
task Test {
    Write-Build Green "Running Pester tests..."

    # Check if Pester is installed
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Build Yellow "Pester not found. Install with: Install-Module Pester -MinimumVersion 5.0"
        return
    }

    # Run test script
    $testScript = Join-Path $script:Config.ProjectRoot 'Invoke-Tests.ps1'
    if (Test-Path $testScript) {
        & $testScript -CI -Coverage $true
    } else {
        Write-Build Yellow "Invoke-Tests.ps1 not found"
    }
}

# Synopsis: Build executables with PS2EXE
task Build {
    Write-Build Green "Building executables with PS2EXE..."

    # Check if ps2exe is installed
    if (-not (Get-Module -ListAvailable -Name ps2exe)) {
        Write-Build Yellow "ps2exe not found. Install with: Install-Module ps2exe"
        Write-Build Yellow "Skipping EXE build"
        return
    }

    Import-Module ps2exe

    # Build MainApp.exe
    Write-Build Cyan "Building MainApp executable..."
    $mainParams = @{
        InputFile = $script:Config.MainAppScript
        OutputFile = $script:Config.MainAppExe
        NoConsole = $true
        NoOutput = $true
        NoError = $false
        RequireAdmin = $false
        STA = $true
        Title = "Daily Motivation Brain Helper"
        Product = "Daily Motivation Brain Helper"
        Version = "1.0.0.0"
        Verbose = $false
    }

    Invoke-PS2EXE @mainParams

    if (Test-Path $script:Config.MainAppExe) {
        Write-Build Green "✅ Built: $($script:Config.MainAppExe)"
    } else {
        throw "Failed to build MainApp executable"
    }

    # Build DailyMotivation.exe
    Write-Build Cyan "Building Popup executable..."
    $popupParams = @{
        InputFile = $script:Config.PopupScript
        OutputFile = $script:Config.PopupExe
        NoConsole = $true
        NoOutput = $true
        NoError = $false
        RequireAdmin = $false
        STA = $true
        Title = "Daily Motivation Brain Helper - Popup"
        Product = "Daily Motivation Brain Helper"
        Version = "1.0.0.0"
        Verbose = $false
    }

    Invoke-PS2EXE @popupParams

    if (Test-Path $script:Config.PopupExe) {
        Write-Build Green "✅ Built: $($script:Config.PopupExe)"
    } else {
        throw "Failed to build Popup executable"
    }

    # Copy dependencies
    Write-Build Cyan "Copying dependencies..."

    # Copy Modules
    Copy-Item -Path (Join-Path $script:Config.SourcePath 'Modules') `
              -Destination $script:Config.OutputPath -Recurse -Force

    # Copy data
    if (Test-Path (Join-Path $script:Config.SourcePath 'data')) {
        Copy-Item -Path (Join-Path $script:Config.SourcePath 'data') `
                  -Destination $script:Config.OutputPath -Recurse -Force
    }

    # Copy LaunchMotivation.bat
    Copy-Item -Path (Join-Path $script:Config.SourcePath 'LaunchMotivation.bat') `
              -Destination $script:Config.OutputPath -Force

    Write-Build Green "✅ Build completed successfully"
    Write-Build Cyan "Output directory: $($script:Config.OutputPath)"
}

# Synopsis: Run only unit tests
task TestUnit {
    Write-Build Green "Running unit tests only..."
    $testScript = Join-Path $script:Config.ProjectRoot 'Invoke-Tests.ps1'
    if (Test-Path $testScript) {
        & $testScript -Tag 'Unit' -Coverage $false
    }
}

# Synopsis: Run only integration tests
task TestIntegration {
    Write-Build Green "Running integration tests only..."
    $testScript = Join-Path $script:Config.ProjectRoot 'Invoke-Tests.ps1'
    if (Test-Path $testScript) {
        & $testScript -Tag 'Integration' -Coverage $false
    }
}

# Synopsis: Quick build without tests
task QuickBuild Clean, Build

# Synopsis: Full release build
task Release Clean, Analyze, Test, Build, Package

# Synopsis: Create release package
task Package {
    Write-Build Green "Creating release package..."

    $packagePath = Join-Path $script:Config.OutputPath 'DailyMotivationBrainHelper_Release.zip'

    # Create ZIP package
    $filesToPackage = @(
        $script:Config.MainAppExe
        $script:Config.PopupExe
        (Join-Path $script:Config.OutputPath 'LaunchMotivation.bat')
        (Join-Path $script:Config.OutputPath 'src')
    )

    Compress-Archive -Path $filesToPackage -DestinationPath $packagePath -Force

    Write-Build Green "✅ Package created: $packagePath"
}

# Synopsis: Install required build modules
task InstallDependencies {
    Write-Build Green "Installing build dependencies..."

    $modules = @(
        @{ Name = 'InvokeBuild'; MinimumVersion = '5.0' }
        @{ Name = 'Pester'; MinimumVersion = '5.0' }
        @{ Name = 'PSScriptAnalyzer'; MinimumVersion = '1.20' }
        @{ Name = 'ps2exe'; MinimumVersion = '1.0' }
    )

    foreach ($module in $modules) {
        $installed = Get-Module -ListAvailable -Name $module.Name |
                     Where-Object { $_.Version -ge $module.MinimumVersion } |
                     Select-Object -First 1

        if (-not $installed) {
            Write-Build Yellow "Installing $($module.Name) >= $($module.MinimumVersion)..."
            Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion `
                          -Scope CurrentUser -Force -SkipPublisherCheck
            Write-Build Green "✅ Installed $($module.Name)"
        } else {
            Write-Build Cyan "$($module.Name) already installed: $($installed.Version)"
        }
    }

    Write-Build Green "✅ All dependencies installed"
}

# Synopsis: Show build configuration
task ShowConfig {
    Write-Build Cyan "Build Configuration:"
    $script:Config.GetEnumerator() | Sort-Object Key | ForEach-Object {
        Write-Build White "  $($_.Key): $($_.Value)"
    }
}
