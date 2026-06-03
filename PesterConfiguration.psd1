@{
    Run = @{
        Path = 'Tests'
        Exit = $true
        PassThru = $true
    }
    Filter = @{
        Tag = @()
        ExcludeTag = @()
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = 'TestResults.xml'
    }
    CodeCoverage = @{
        Enabled = $true
        Path = @(
            'src/Modules/*.psm1'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = 'coverage.xml'
    }
    Should = @{
        ErrorAction = 'Stop'
    }
}
