[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)


$testsDirectory = Join-Path $ProjectRoot 'Tests'
$outputPath = Join-Path $testsDirectory 'tests_line_count.txt'

if (-not (Test-Path -LiteralPath $testsDirectory -PathType Container)) {
    throw "Tests directory was not found: $testsDirectory"
}

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add(('Time Of Line Count: {0}' -f (Get-Date -Format 'M/d/yyyy h:mm tt')))
$reportLines.Add([Environment]::NewLine)

$testFiles = Get-ChildItem -LiteralPath $testsDirectory -File -Recurse |
    Where-Object { $_.Name -like '*.Tests.ps1' } |
    Sort-Object FullName

foreach ($testFile in $testFiles) {
    $lineCount = @(Get-Content -LiteralPath $testFile.FullName).Count
    $reportLines.Add(('File: {0}' -f $testFile.Name))
    $reportLines.Add(('Line Count: {0}' -f $lineCount))
    $reportLines.Add('')
}

Set-Content -LiteralPath $outputPath -Value $reportLines -Encoding UTF8
Write-Output "Wrote $outputPath"
