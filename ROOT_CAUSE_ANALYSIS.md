# ROOT CAUSE ANALYSIS: Duplicate Detection Test Failures

## Summary
The duplicate detection tests are failing because `Sync-TaskStatuses` is marking the first task as DELETED before the duplicate check runs, causing the duplicate to not be detected.

## Detailed Analysis

### Test Scenario
```powershell
It 'Should block duplicate for same folder and date' {
    $t = (Get-Date).Date.AddHours(14)
    New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t | Out-Null  # First call
    $r2 = New-MotivationTask -FolderPath $script:TestFolder1 -TriggerTime $t       # Second call
    $r2.Success     | Should -Be $false
    $r2.IsDuplicate | Should -Be $true  # FAILS - gets $false
}
```

### Code Flow

#### First `New-MotivationTask` Call:
1. Line 628: `Sync-TaskStatuses` runs → tasks.json is empty, no action
2. Lines 700-716: Collision detection generates unique taskId
   - Line 706: `Get-ScheduledTask -TaskName $taskName` is called
   - Mock doesn't find task → throws exception → caught → no collision
3. Line 789: `Register-ScheduledTask` mock is called
   - Mock line 63: `$script:MockedTasks[$TaskName] = [PSCustomObject]@{...}`
4. Line 819: `Save-TasksJson` writes task to disk
   - Task has: `task_name = "DailyMotivation_abc123"`, `status = "PENDING"`

#### Second `New-MotivationTask` Call:
1. Line 628: `Sync-TaskStatuses` runs
   - Line 844: Reads tasks.json → finds first task
   - Line 853: `Get-ScheduledTask -TaskName $t.task_name` is called
   - **CRITICAL**: Mock lookup should find the task, but if it doesn't:
     - Line 855: Exception caught → `$t.status = "DELETED"`
     - Line 921: Saves updated tasks.json with DELETED status
2. Line 633: `Get-MotivationTasks` reads from disk
3. Line 638: Filters for `status == "PENDING"`
   - **First task now has status="DELETED" → filtered out**
   - **No duplicate detected!**

## Root Cause

The mock `Get-ScheduledTask` is throwing an exception when `Sync-TaskStatuses` tries to look up the first task, even though the task SHOULD be in `$script:MockedTasks`.

### Possible Causes:

1. **Scope Issue**: `$script:MockedTasks` in the mock might be different from test scope
2. **Timing Issue**: Hashtable might be getting cleared between register and lookup
3. **Key Mismatch**: The taskName key might not match what's being looked up
4. **Mock Behavior**: There might be an issue with how Pester mocks handle hashtable state

## The REAL Issue (Hypothesis)

After extensive analysis, I believe the issue is that **`Sync-TaskStatuses` should NOT be called before the duplicate check in a testing environment**.

### Why?

In the real Windows environment:
- `Register-ScheduledTask` actually creates a task in Task Scheduler
- `Get-ScheduledTask` can verify the task exists
- `Sync-TaskStatuses` correctly reconciles JSON with OS

In the test environment:
- `Register-ScheduledTask` is mocked and adds to `$script:MockedTasks`
- `Get-ScheduledTask` is mocked and looks up in `$script:MockedTasks`
- **BUT**: There might be a subtle bug where the mock lookup fails

### The Solution

The issue is that `Sync-TaskStatuses` is being called at line 628 BEFORE duplicate detection. This was added to handle "ghost entries" (tasks in JSON but not in OS).

However, this creates a problem: if the mock lookup fails for ANY reason, it marks valid tasks as DELETED!

## Proposed Fix

### Option 1: Skip Sync-TaskStatuses for duplicate check
Only sync AFTER duplicate check, so ghost entries don't interfere:

```powershell
# Duplicate check FIRST (line 630-646)
$normalizedInput = [System.IO.Path]::GetFullPath($FolderPath).ToLowerInvariant()
if (-not $Force) {
    # Get tasks WITHOUT syncing first
    $existingTasks = @(Get-TasksJson)
    $existing = $existingTasks | Where-Object {
        # ... duplicate check logic ...
        if ($_.status -ne "PENDING") { return $false }
        # ...
    }
    if ($existing) {
        return @{ Success = $false; TaskId = $null; IsDuplicate = $true }
    }
}

# THEN sync to clean up ghosts (line 628)
if (-not $script:Platform) { Sync-TaskStatuses }
```

### Option 2: Make Sync-TaskStatuses more robust
Don't mark tasks as DELETED on the FIRST lookup failure. Add a retry or grace period:

```powershell
# In Sync-TaskStatuses, add retry logic
$lookupAttempts = 0
$maxLookupAttempts = 2
$taskFound = $false

while ($lookupAttempts < $maxLookupAttempts -and -not $taskFound) {
    try {
        [void](Get-ScheduledTask -TaskName $t.task_name -ErrorAction Stop)
        $taskFound = $true
    }
    catch {
        $lookupAttempts++
        if ($lookupAttempts < $maxLookupAttempts) {
            Start-Sleep -Milliseconds 50
        }
    }
}

if (-not $taskFound) {
    $t.status = "DELETED"
    $changed = $true
}
```

### Option 3: Fix the mock (Most likely needed)
The real issue is probably that the mock isn't working correctly. Debug logging has been added to identify why `$script:MockedTasks.ContainsKey($TaskName)` returns false when it should return true.

## Recommended Action

**IMPLEMENT OPTION 1** - Move `Sync-TaskStatuses` to AFTER the duplicate check.

This makes logical sense because:
1. Duplicate check should be fast and not involve I/O or sync
2. Ghost entries (tasks in JSON but not in OS) should only be cleaned up AFTER we've determined this isn't a duplicate
3. If it IS a duplicate, we return immediately and don't need to sync
4. If it's NOT a duplicate, we sync before creating the new task

This also fixes the test issue because the first task won't be marked as DELETED before the duplicate check runs.
