# Debug script for tracing the exact issue
$TestDir = 'C:\temp\DM_Debug3'
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path '$TestDir/DailyMotivationBrainHelper' -Force | Out-Null
'not valid' | Out-File '$TestDir/DailyMotivationBrainHelper/tasks.json' -Encoding utf8

$env:APPDATA = $TestDir

# Import module
Import-Module 'C:\login\daily_moti\Daily-Motivation-Brain-Helper\src\Modules\TaskScheduler.psm1' -Force

# Check what Get-TasksJson actually returns
$tasks = Get-TasksJson
Write-Output 'Get-TasksJson returned count: ' $tasks.Count
Write-Output 'Get-TasksJson returned type: ' $tasks.GetType().FullName

# Check what @(Get-TasksJson) produces
$wrapped = @(Get-TasksJson)
Write-Output 'After @(...) wrapper count: ' $wrapped.Count

# The foreach iterates
foreach ($t in $wrapped) {
    Write-Output 't type: ' ($t).GetType().FullName
    Write-Output 't.status: ' $t.status
    Write-Output 't.folder_path: ' $t.folder_path
    
    # Check what GetFullPath does on null/empty
    try {
        [System.IO.Path]::GetFullPath($t.folder_path)
    } catch {
        Write-Output 'GetFullPath ERROR: ' $_.Exception.Message
    }
}
