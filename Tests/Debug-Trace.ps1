# Debug script for tracing Get-TasksJson behavior
$TestDir = "C:\temp\DM_Debug"
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path "$TestDir/DailyMotivationBrainHelper" -Force | Out-Null
"not valid" | Out-File "$TestDir/DailyMotivationBrainHelper/tasks.json" -Encoding utf8

$env:APPDATA = $TestDir

Import-Module "C:\login\daily_moti\Daily-Motivation-Brain-Helper\src\Modules\TaskScheduler.psm1" -Force

# Direct call
$tasks = Get-TasksJson
Write-Output "Get-TasksJson count: $($tasks.Count)"
if ($tasks.Count -gt 0) {
    Write-Output "Tasks[0] type: $($tasks[0].GetType().FullName)"
    Write-Output "Tasks[0] value: $($tasks[0])"
}

# Now call Get-MotivationTasks
$motivTasks = Get-MotivationTasks
Write-Output "Get-MotivationTasks count: $($motivTasks.Count)"