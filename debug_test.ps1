#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

# Minimal reproduction of the Get-MotivationTasks issue

. (Join-Path $PSScriptRoot 'DailyMotivation.ps1') -NoRun

Write-Host "=== DEBUG: Testing Get-MotivationTasks count issue ===" -ForegroundColor Cyan

# Setup like BeforeAll
$script:OriginalAppData = $env:APPDATA
$env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_Debug_$(New-Guid)"
Write-Host "APPDATA set to: $env:APPDATA" -ForegroundColor Yellow

Initialize-AppData
Write-Host "TasksPath set to: $script:TasksPath" -ForegroundColor Yellow

# Check if directory exists
if (Test-Path $script:AppDataDir) {
    Write-Host "AppDataDir exists: $script:AppDataDir" -ForegroundColor Green
} else {
    Write-Host "AppDataDir MISSING: $script:AppDataDir" -ForegroundColor Red
}

$script:ExePath = "C:\Test\DailyMotivation.exe"
$script:TestFolder1 = 'C:\Projects\TestFolder1'
$script:TestFolder2 = 'C:\Projects\TestFolder2'

# Mock setup
$script:MockedTasks = @{}

Mock Register-ScheduledTask -Verifiable {
    param($TaskName, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
    Write-Host "  [MOCK] Register-ScheduledTask called: $TaskName" -ForegroundColor Gray
    $script:MockedTasks[$TaskName] = [PSCustomObject]@{
        TaskName = $TaskName
        State = [PSCustomObject]@{ State = 'Ready' }
        Triggers = @($Trigger)
    }
    return $null
}

Mock Unregister-ScheduledTask -Verifiable {
    param($TaskName, $Confirm)
    Write-Host "  [MOCK] Unregister-ScheduledTask called: $TaskName" -ForegroundColor Gray
    if ($script:MockedTasks.ContainsKey($TaskName)) {
        $script:MockedTasks.Remove($TaskName)
    }
}

Mock Get-ScheduledTask {
    param($TaskName)
    Write-Host "  [MOCK] Get-ScheduledTask called with: '$TaskName'" -ForegroundColor Gray
    if ($TaskName -eq "DailyMotivation_*") {
        $count = $script:MockedTasks.Values.Count
        Write-Host "  [MOCK]   Returning $count tasks (wildcard query)" -ForegroundColor Gray
        return @($script:MockedTasks.Values)
    }
    if ($script:MockedTasks.ContainsKey($TaskName)) {
        Write-Host "  [MOCK]   Returning 1 task (exact match)" -ForegroundColor Gray
        return $script:MockedTasks[$TaskName]
    }
    Write-Host "  [MOCK]   Throwing (not found)" -ForegroundColor Gray
    throw [Microsoft.PowerShell.Cmdletization.Cim.CimJobException]::new("No MSFT_ScheduledTask objects found with property 'TaskName' equal to '$TaskName'")
}

Mock New-ScheduledTaskAction { param($Execute, $Argument); return [PSCustomObject]@{} }
Mock New-ScheduledTaskTrigger { param($Once, $At); return [PSCustomObject]@{ StartBoundary = $At.ToString('yyyy-MM-ddTHH:mm:ss'); EndBoundary = '' } }
Mock New-ScheduledTaskSettingsSet { return [PSCustomObject]@{} }
Mock New-ScheduledTaskPrincipal { return [PSCustomObject]@{} }

Write-Host "`n--- Test: Should return all tasks ---" -ForegroundColor Cyan

# BeforeEach simulation
Write-Host "1. BeforeEach: Resetting tasks.json to []" -ForegroundColor Yellow
$tasksJsonPath = Join-Path $env:APPDATA 'DailyMotivationBrainHelper\tasks.json'
Write-Host "   Writing to: $tasksJsonPath" -ForegroundColor Gray
'[]' | Set-Content $tasksJsonPath -Encoding UTF8

Write-Host "2. BeforeEach: Resetting MockedTasks" -ForegroundColor Yellow
$script:MockedTasks = @{}
Write-Host "   MockedTasks count: $($script:MockedTasks.Count)" -ForegroundColor Gray

Write-Host "3. Reading tasks.json immediately after reset" -ForegroundColor Yellow
$beforeTasks = Get-MotivationTasks
Write-Host "   Count: $($beforeTasks.Count) (should be 0)" -ForegroundColor $(if ($beforeTasks.Count -eq 0) { 'Green' } else { 'Red' })
if ($beforeTasks.Count -gt 0) {
    Write-Host "   UNEXPECTED TASKS FOUND:" -ForegroundColor Red
    $beforeTasks | ForEach-Object { Write-Host "     - $($_.task_id): $($_.folder_path)" -ForegroundColor Red }
}

Write-Host "4. Creating first task" -ForegroundColor Yellow
$t = (Get-Date).AddHours(2)
$result1 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t
Write-Host "   Success: $($result1.Success), TaskId: $($result1.TaskId)" -ForegroundColor Gray
Write-Host "   MockedTasks count: $($script:MockedTasks.Count)" -ForegroundColor Gray

Write-Host "5. Reading tasks.json after first task" -ForegroundColor Yellow
$afterFirst = Get-MotivationTasks
Write-Host "   Count: $($afterFirst.Count) (should be 1)" -ForegroundColor $(if ($afterFirst.Count -eq 1) { 'Green' } else { 'Red' })

Write-Host "6. Creating second task" -ForegroundColor Yellow
$result2 = New-MotivationTask -FolderPath $script:TestFolder2 -TriggerTime $t
Write-Host "   Success: $($result2.Success), TaskId: $($result2.TaskId)" -ForegroundColor Gray
Write-Host "   MockedTasks count: $($script:MockedTasks.Count)" -ForegroundColor Gray

Write-Host "7. Reading tasks.json after second task" -ForegroundColor Yellow
$finalTasks = Get-MotivationTasks
Write-Host "   Count: $($finalTasks.Count) (should be 2)" -ForegroundColor $(if ($finalTasks.Count -eq 2) { 'Green' } else { 'Red' })

if ($finalTasks.Count -ne 2) {
    Write-Host "`n   FAILURE: Expected 2 tasks, got $($finalTasks.Count)" -ForegroundColor Red
    Write-Host "   Tasks found:" -ForegroundColor Red
    $finalTasks | ForEach-Object {
        Write-Host "     - task_id: $($_.task_id), folder: $($_.folder_path), status: $($_.status)" -ForegroundColor Red
    }

    Write-Host "`n   Reading raw JSON file:" -ForegroundColor Yellow
    $rawContent = Get-Content $tasksJsonPath -Raw
    Write-Host "   Content length: $($rawContent.Length) chars" -ForegroundColor Gray
    Write-Host "   Content:`n$rawContent" -ForegroundColor Gray
} else {
    Write-Host "`n   SUCCESS: Test passed!" -ForegroundColor Green
}

# Cleanup
Write-Host "`n--- Cleanup ---" -ForegroundColor Cyan
if (Test-Path $env:APPDATA) {
    Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed temp directory" -ForegroundColor Gray
}
$env:APPDATA = $script:OriginalAppData
Write-Host "Restored original APPDATA" -ForegroundColor Gray

Write-Host "`n=== DEBUG COMPLETE ===" -ForegroundColor Cyan
