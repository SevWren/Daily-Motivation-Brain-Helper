#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Mandated real-Task-Scheduler integration test (CLAUDE.md CORRECT 5, MANDATE #5).

.DESCRIPTION
    Exercises the REAL Register-ScheduledTask / Get-ScheduledTask /
    Unregister-ScheduledTask cmdlets with NO mocking, using a real temp folder and
    a throwaway .exe action path. This is the gate the MANDATE requires before any
    change to the task principal (LogonType/RunLevel) or any scheduling fix is
    declared resolved.

    Why a separate file: TaskScheduler.Tests.ps1 mocks the persistence cmdlets in a
    file-scoped BeforeAll. This file deliberately does NOT mock them.

    CRITICAL -- leak-free design:
      A per-user task registered by a process is reliably deletable from THAT SAME
      process, but deletion from a DIFFERENT process has been observed to fail with
      E_ACCESSDENIED (0x80070005) even for the owning user. Because the Pester
      process is the creator, every task MUST be removed in-process (in the test's
      finally + the file-scoped AfterAll), both of which run in the same process.
      Never rely on cleanup from a later, unrelated process.

      - $env:APPDATA is redirected to a temp dir so tasks.json is isolated from the
        user's real config.
      - The OS task trigger is 2 days out, so it cannot fire during the test even if
        cleanup were skipped.
      - Each test removes its own task in a finally block; AfterAll is a safety net
        that unregisters every name this run created (SilentlyContinue no-ops on a
        task already removed).
    Runs only on Windows (real Task Scheduler cmdlets + registry).
#>

BeforeAll {
    if (-not $IsWindows) { return }

    # Resolve the script path to a normalized absolute path. A literal '..\..' in the
    # dot-source command position can fail to resolve under Pester's run context.
    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $scriptToDotSource = Join-Path $repoRoot 'DailyMotivation.ps1'
    if (-not (Test-Path -LiteralPath $scriptToDotSource)) {
        throw "Cannot find DailyMotivation.ps1 at $scriptToDotSource"
    }
    . $scriptToDotSource -NoRun

    $script:OriginalAppData = $env:APPDATA
    $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_IntegReal_$(New-Guid)"
    Initialize-AppData

    # Real registration validates ExePath (absolute + .exe). Create a throwaway .exe;
    # Task Scheduler does not require it to be a valid PE at register time.
    $script:probeExe = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_IntegReal_$(New-Guid).exe"
    'DMBH' | Set-Content $script:probeExe -Encoding ASCII

    # $script:ExePath is only assigned by the script's entry-point block, which -NoRun
    # skips, so it is unset here and an unguarded read throws under the runner's
    # Set-StrictMode -Version Latest. Capture it defensively, then repoint the
    # dot-sourced functions at the throwaway .exe.
    $script:OriginalExePath = $null
    if (Get-Variable -Name 'ExePath' -Scope 'Script' -ErrorAction SilentlyContinue) {
        $script:OriginalExePath = $script:ExePath
    }
    $script:ExePath = $script:probeExe

    $script:IntegCreated = @()   # every OS task name created this run, for leak-free cleanup
}

AfterAll {
    # Safety net: unregister every task this run created (in-process, so it works).
    # Every script var is probed with Get-Variable: the runner's Set-StrictMode -Version
    # Latest turns a read of a not-yet-assigned variable into a terminating error, and
    # BeforeAll early-returns on non-Windows (and could stop mid-way on error), leaving
    # these unset. Getting them via a local default keeps AfterAll from aborting the run.
    $createdTasks = @()
    if (Get-Variable -Name 'IntegCreated' -Scope 'Script' -ErrorAction SilentlyContinue) { $createdTasks = $script:IntegCreated }
    foreach ($name in $createdTasks) {
        try { Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue }
        catch {}
    }

    # AG20-015: Comprehensive sweep for ANY stray DailyMotivation_* tasks (safety net)
    # This catches tasks that were created but not tracked (e.g., test failure before adding to $script:IntegCreated)
    if ($IsWindows) {
        try {
            $strayTasks = Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue
            if ($strayTasks) {
                Write-Warning "AG20-015 cleanup: Found $($strayTasks.Count) stray task(s) after test run. Removing..."
                foreach ($task in $strayTasks) {
                    try {
                        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                        Write-Host "  - Removed stray task: $($task.TaskName)" -ForegroundColor Yellow
                    }
                    catch {
                        Write-Warning "  - Failed to remove $($task.TaskName): $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            # Get-ScheduledTask itself failed - log but don't fail the test run
            Write-Warning "AG20-015 cleanup: Could not sweep for stray tasks: $($_.Exception.Message)"
        }
    }

    $probe = $null
    if (Get-Variable -Name 'probeExe' -Scope 'Script' -ErrorAction SilentlyContinue) { $probe = $script:probeExe }
    if ($probe -and (Test-Path -LiteralPath $probe)) { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue }

    $origAppData = $null
    if (Get-Variable -Name 'OriginalAppData' -Scope 'Script' -ErrorAction SilentlyContinue) { $origAppData = $script:OriginalAppData }
    if ($origAppData -and $env:APPDATA -and $env:APPDATA -ne $origAppData -and (Test-Path -LiteralPath $env:APPDATA)) {
        Remove-Item -LiteralPath $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($origAppData) { $env:APPDATA = $origAppData }

    $origExe = $null
    if (Get-Variable -Name 'OriginalExePath' -Scope 'Script' -ErrorAction SilentlyContinue) { $origExe = $script:OriginalExePath }
    if ($null -ne $origExe) { $script:ExePath = $origExe }
}

Describe 'New-MotivationTask - real Task Scheduler integration (no mocking)' -Skip:(-not $IsWindows) {
    It 'registers a real OS task for an accessible folder and verifies the principal' {
        $testPath = Join-Path ([System.IO.Path]::GetTempPath()) 'dmh-integration-test'
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        $result = $null; $taskName = $null
        try {
            $result = New-MotivationTask -FolderPath $testPath -TriggerTime (Get-Date).AddDays(2)
            # Use the hashtable indexer, not .Error: New-MotivationTask's success and
            # duplicate returns have no 'Error' key, and this -Because string is
            # interpolated eagerly, so .Error would throw under the runner's
            # Set-StrictMode -Version Latest and mask the real verdict.
            $result.Success | Should -Be $true -Because `
                "real Register-ScheduledTask must succeed for a per-user Interactive/Limited task; got: $($result['Error'])"
            $taskName = "DailyMotivation_$($result.TaskId)"
            $script:IntegCreated += $taskName

            $osTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            $osTask | Should -Not -BeNullOrEmpty -Because 'the OS task must exist after real registration'

            # Principal must be the live-validated Interactive / Limited values.
            # Get-ScheduledTask returns LogonTypeEnum/RunLevelEnum; compare by name.
            [string]$osTask.Principal.LogonType | Should -Be 'Interactive'
            [string]$osTask.Principal.RunLevel  | Should -Be 'Limited'
        }
        finally {
            # Leak-proof cleanup: recompute the OS task name from $result.TaskId, not
            # from $taskName. $taskName is only assigned inside the try block, AFTER the
            # first assertion, so if an assertion throws there $taskName is still $null
            # and the previous guard ($result -and $result.TaskId -and $taskName) skipped
            # removal entirely, leaking the real OS task. Recompiling from TaskId makes
            # cleanup independent of whether the assertion got that far.
            if ($result -and $result.TaskId) {
                $cleanupName = "DailyMotivation_$($result.TaskId)"
                try { [void](Remove-MotivationTask -TaskId $result.TaskId) } catch {}
                try { Unregister-ScheduledTask -TaskName $cleanupName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
            }
            if (Test-Path $testPath) { Remove-Item $testPath -Force -Recurse -ErrorAction SilentlyContinue }
        }
    }

    It 'removes the real OS task via Remove-MotivationTask and verifies it is gone' {
        $testPath = Join-Path ([System.IO.Path]::GetTempPath()) 'dmh-integration-test-remove'
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        $result = $null; $taskName = $null
        try {
            $result = New-MotivationTask -FolderPath $testPath -TriggerTime (Get-Date).AddDays(2)
            $result.Success | Should -Be $true -Because "setup registration must succeed: $($result['Error'])"
            $taskName = "DailyMotivation_$($result.TaskId)"
            $script:IntegCreated += $taskName

            $removed = Remove-MotivationTask -TaskId $result.TaskId
            $removed | Should -Be $true -Because 'Remove-MotivationTask must unregister the real OS task'

            # Real Windows throws CimJobException for a not-found task.
            $leftover = $null
            try { $leftover = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop }
            catch { $leftover = $null }
            $leftover | Should -BeNullOrEmpty -Because 'the OS task must be gone after Remove-MotivationTask'
        }
        finally {
            # Leak-proof cleanup: recompute the OS task name from $result.TaskId, not
            # from $taskName. $taskName is only assigned inside the try block, AFTER the
            # first assertion, so if an assertion throws there $taskName is still $null
            # and the previous guard ($result -and $result.TaskId -and $taskName) skipped
            # removal entirely, leaking the real OS task. Recompiling from TaskId makes
            # cleanup independent of whether the assertion got that far.
            if ($result -and $result.TaskId) {
                $cleanupName = "DailyMotivation_$($result.TaskId)"
                try { [void](Remove-MotivationTask -TaskId $result.TaskId) } catch {}
                try { Unregister-ScheduledTask -TaskName $cleanupName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
            }
            if (Test-Path $testPath) { Remove-Item $testPath -Force -Recurse -ErrorAction SilentlyContinue }
        }
    }
}
