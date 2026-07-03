# Debug script to understand the mock behavior

$script:MockedTasks = @{}

# Simulate Register-ScheduledTask
function Register-MockTask {
    param($TaskName)
    Write-Host "Registering task: $TaskName"
    $script:MockedTasks[$TaskName] = @{ TaskName = $TaskName; Status = "Ready" }
    Write-Host "MockedTasks after register: $($script:MockedTasks.Keys -join ', ')"
}

# Simulate Get-ScheduledTask
function Get-MockTask {
    param($TaskName)
    Write-Host "Looking up task: $TaskName"
    Write-Host "MockedTasks contains: $($script:MockedTasks.Keys -join ', ')"
    Write-Host "ContainsKey result: $($script:MockedTasks.ContainsKey($TaskName))"

    if ($script:MockedTasks.ContainsKey($TaskName)) {
        Write-Host "Found task: $TaskName"
        return $script:MockedTasks[$TaskName]
    }
    else {
        Write-Host "Task not found: $TaskName"
        throw "No task found with name '$TaskName'"
    }
}

# Simulate the test scenario
Write-Host "`n=== First Task Creation ==="
$taskName1 = "DailyMotivation_abc123"
Register-MockTask -TaskName $taskName1

Write-Host "`n=== Second Task Creation (Sync-TaskStatuses lookup) ==="
try {
    Get-MockTask -TaskName $taskName1
    Write-Host "SUCCESS: Task found"
}
catch {
    Write-Host "ERROR: Task lookup failed - $_"
}

Write-Host "`n=== Checking if task is still in hash after lookup ==="
Write-Host "MockedTasks contains: $($script:MockedTasks.Keys -join ', ')"
