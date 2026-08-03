#Requires -Modules Pester
<#
.SYNOPSIS
    AG20-023: -NoRun robustness and side-effect suppression tests.
    Verifies that dot-sourcing DailyMotivation.ps1 with -NoRun:
      1. Makes ALL top-level functions in the file reachable (not just the hardcoded 15).
      2. Produces zero $Error entries (no silent failures).
      3. Does NOT write any files to AppData (no file I/O side effects).
      4. Does NOT invoke Register-ScheduledTask, Get-ScheduledTask, or registry cmdlets.
#>

# Set at file scope so Pester's discovery phase can access these for -ForEach population.
$script:RepoRoot   = Join-Path $PSScriptRoot '..\..'
$script:ScriptPath = Join-Path $script:RepoRoot 'DailyMotivation.ps1'

BeforeAll {
    # Ensure path vars are set during the run phase as well as discovery phase.
    $script:RepoRoot   = Join-Path $PSScriptRoot '..\..'
    $script:ScriptPath = Join-Path $script:RepoRoot 'DailyMotivation.ps1'

    # Redirect APPDATA to a clean temp dir so any accidental file I/O is isolated and detectable.
    $script:OriginalAppData = $env:APPDATA
    $script:IsolatedAppData = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_AG20023_$(New-Guid)"
    New-Item -ItemType Directory -Path $script:IsolatedAppData -Force | Out-Null
    $env:APPDATA = $script:IsolatedAppData

    # Clear the error stream before dot-sourcing so we only capture errors from this operation.
    $Error.Clear()

    # Dot-source without executing the entry point.
    . $script:ScriptPath -NoRun

    # Capture error count IMMEDIATELY after dot-source, before any other BeforeAll blocks run.
    $script:ErrorCountAfterDotSource = $Error.Count
}

AfterAll {
    if (Test-Path $script:IsolatedAppData) {
        Remove-Item -Path $script:IsolatedAppData -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:APPDATA = $script:OriginalAppData
}

# ---------------------------------------------------------------------------
# 1. All top-level functions are reachable after dot-source
# ---------------------------------------------------------------------------
Describe '-NoRun: All functions defined in DailyMotivation.ps1 are reachable' {

    BeforeAll {
        # Dynamically build the expected function list from the script source.
        # Only match lines that start at column 0 (^) to exclude nested helper functions.
        $script:DiscoveredFunctions = Select-String `
            -Pattern '^function\s+([A-Za-z][\w-]*)' `
            -Path $script:ScriptPath |
            ForEach-Object { $_.Matches.Groups[1].Value }
    }

    It 'Script contains at least one function definition' {
        $script:DiscoveredFunctions.Count | Should -BeGreaterThan 0
    }

    It 'All functions discovered in DailyMotivation.ps1 are reachable via Get-Command after dot-source' {
        foreach ($fn in $script:DiscoveredFunctions) {
            (Get-Command -Name $fn -ErrorAction SilentlyContinue) |
                Should -Not -BeNullOrEmpty -Because "function '$fn' must be reachable after -NoRun dot-source"
        }
    }
}

# ---------------------------------------------------------------------------
# 2. Zero $Error entries after dot-source (no silent failures)
# ---------------------------------------------------------------------------
Describe '-NoRun: Dot-sourcing produces zero $Error entries' {

    It 'Error stream should be empty after dot-source with -NoRun' {
        # Count captured in outer BeforeAll immediately after dot-source.
        $script:ErrorCountAfterDotSource | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# 3. No file I/O side effects: AppData dir remains empty after dot-source
# ---------------------------------------------------------------------------
Describe '-NoRun: Dot-sourcing does not write any files to AppData' {

    It 'The isolated APPDATA directory should contain no files after dot-source' {
        $filesWritten = Get-ChildItem -Path $script:IsolatedAppData -Recurse -File -ErrorAction SilentlyContinue
        $filesWritten.Count | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# 4. No Task Scheduler or registry side effects (Windows only)
# ---------------------------------------------------------------------------
Describe '-NoRun: Dot-sourcing does not invoke Task Scheduler or registry cmdlets' -Skip:(-not $IsWindows) {

    BeforeAll {
        # Capture call counts for the cmdlets that must NOT fire during dot-source.
        $script:RegisterScheduledTaskCallCount = 0
        $script:GetScheduledTaskCallCount      = 0
        $script:GetItemPropertyCallCount       = 0
        $script:SetItemPropertyCallCount       = 0

        Mock Register-ScheduledTask {
            $script:RegisterScheduledTaskCallCount++
        }
        Mock Get-ScheduledTask {
            $script:GetScheduledTaskCallCount++
        }
        Mock Get-ItemProperty {
            $script:GetItemPropertyCallCount++
        }
        Mock Set-ItemProperty {
            $script:SetItemPropertyCallCount++
        }

        # Clear errors and re-dot-source inside a fresh scope so the mocks are active.
        $Error.Clear()
        . $script:ScriptPath -NoRun
    }

    It 'Register-ScheduledTask should not be called during dot-source' {
        $script:RegisterScheduledTaskCallCount | Should -Be 0
    }

    It 'Get-ScheduledTask should not be called during dot-source' {
        $script:GetScheduledTaskCallCount | Should -Be 0
    }

    It 'Get-ItemProperty (registry read) should not be called during dot-source' {
        $script:GetItemPropertyCallCount | Should -Be 0
    }

    It 'Set-ItemProperty (registry write) should not be called during dot-source' {
        $script:SetItemPropertyCallCount | Should -Be 0
    }
}
