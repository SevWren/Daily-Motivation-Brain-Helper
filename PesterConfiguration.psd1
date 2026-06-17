@{
    Run = @{
        Path    = 'Tests'
        Exit    = $true
        PassThru = $true
    }
    Filter = @{
        Tag        = @()
        ExcludeTag = @()
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    TestResult = @{
        Enabled      = $true
        OutputFormat = 'NUnitXml'
        OutputPath   = 'TestResults.xml'
    }
    CodeCoverage = @{
        Enabled      = $true
        Path         = @('DailyMotivation.ps1')
        OutputFormat = 'JaCoCo'
        OutputPath   = 'coverage.xml'
    }
    Should = @{
        ErrorAction = 'Stop'
    }
}
