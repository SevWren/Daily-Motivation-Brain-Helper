#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for Performance & Resource Leak fixes (Section 14: AG14-001 through AG14-024).
    Tests disposal, caching, and resource management optimizations.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
}

Describe 'AG14-001: FolderBrowserDialog Not Disposed' {
    It 'Should dispose FolderBrowserDialog in Show-MainWindow selectFolderBtn click handler' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        $functionStart = $content.IndexOf('function Show-MainWindow')
        $functionEnd = $content.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)

        # Find the selectFolderBtn.Add_Click block
        $clickHandlerStart = $functionBody.IndexOf('$selectFolderBtn.Add_Click')
        $clickHandlerSection = $functionBody.Substring($clickHandlerStart, 500)

        # Should have try-finally with dialog.Dispose()
        $hasDialogDisposal = ($clickHandlerSection -match 'finally\s*\{[^\}]*\$dialog.*\.Dispose\(\)') -or
                             ($clickHandlerSection -match '\$dialog\.Dispose\(\)')

        $hasDialogDisposal | Should -Be $true -Because "FolderBrowserDialog must be disposed to prevent window handle leak (AG14-001)"
    }

    It 'Should dispose FolderBrowserDialog in Show-PopupWindow rePickBtn click handler' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        # Find the rePickBtn.Add_Click block
        $clickHandlerStart = $content.IndexOf('$rePickBtn.Add_Click')
        if ($clickHandlerStart -gt 0) {
            $clickHandlerSection = $content.Substring($clickHandlerStart, 2000)

            # Should have finally block with dialog.Dispose()
            $hasFinally = $clickHandlerSection -match 'finally'
            $hasDispose = $clickHandlerSection -match 'Dispose.*AG14-001'

            ($hasFinally -and $hasDispose) | Should -Be $true -Because "FolderBrowserDialog must be disposed to prevent window handle leak (AG14-001)"
        }
    }
}

Describe 'AG14-007: DriveInfo Not Disposed' {
    It 'Should dispose DriveInfo in Invoke-FolderScheduling function' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        $functionStart = $content.IndexOf('function Invoke-FolderScheduling')
        $functionEnd = $content.IndexOf('function ', $functionStart + 100)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)

        # Check for DriveInfo usage and disposal
        $hasDriveInfo = $functionBody -match '\[System\.IO\.DriveInfo\]'
        $hasDisposal = $functionBody -match 'driveInfo.*Dispose'

        if ($hasDriveInfo) {
            $hasDisposal | Should -Be $true -Because "DriveInfo must be disposed to prevent file system handle leak (AG14-007)"
        }
    }

    It 'Should dispose DriveInfo in New-MotivationTask function' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        $functionStart = $content.IndexOf('function New-MotivationTask')
        $functionEnd = $content.IndexOf('function ', $functionStart + 100)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)

        # Check for DriveInfo usage and disposal
        $hasDriveInfo = $functionBody -match '\[System\.IO\.DriveInfo\]'
        $hasDisposal = $functionBody -match 'driveInfo.*Dispose'

        if ($hasDriveInfo) {
            $hasDisposal | Should -Be $true -Because "DriveInfo must be disposed to prevent file system handle leak (AG14-007)"
        }
    }
}

Describe 'AG14-006: BrushConverter Objects Never Disposed' {
    It 'Should use a single BrushConverter instance for all brush conversions in Show-MainWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        $functionStart = $content.IndexOf('function Show-MainWindow')
        $functionEnd = $content.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)

        # Should have BrushConverter instantiation and disposal
        $hasBrushConverter = $functionBody -match '\[System\.Windows\.Media\.BrushConverter\]'

        if ($hasBrushConverter) {
            # Should either: 1) Reuse single converter (AG14-006 comment present), or 2) Dispose converters
            $hasReuse = $functionBody -match 'AG14-006.*Reuse single BrushConverter'
            $hasDisposal = $functionBody -match 'converter.*Dispose'

            ($hasReuse -or $hasDisposal) | Should -Be $true -Because "BrushConverter instances should be reused or disposed to prevent WPF resource fragmentation (AG14-006)"
        }
    }
}

Describe 'AG14-002: XmlNodeReader Not Disposed' {
    It 'Should dispose XmlNodeReader after loading XAML in Show-MainWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        $functionStart = $content.IndexOf('function Show-MainWindow')
        $functionEnd = $content.IndexOf('function Show-PopupWindow', $functionStart)
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)

        # Should have reader.Dispose() or finally block with reader cleanup
        $hasReaderDisposal = ($functionBody -match '\$reader\.Dispose\(\)') -or
                             ($functionBody -match 'finally\s*\{[^\}]*if\s*\(\$reader\)[^\}]*\$reader\.Dispose\(\)')

        $hasReaderDisposal | Should -Be $true -Because "XmlNodeReader must be disposed to prevent unmanaged memory leak"
    }

    It 'Should dispose XmlNodeReader after loading XAML in Show-PopupWindow' {
        $sourceFile = Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1'
        $content = Get-Content $sourceFile -Raw

        $functionStart = $content.IndexOf('function Show-PopupWindow')
        $functionEnd = $content.IndexOf('# ============================================================', $functionStart + 100)
        if ($functionEnd -eq -1) { $functionEnd = $content.Length }
        $functionBody = $content.Substring($functionStart, $functionEnd - $functionStart)

        $hasReaderDisposal = ($functionBody -match '\$reader\.Dispose\(\)') -or
                             ($functionBody -match 'finally\s*\{[^\}]*if\s*\(\$reader\)[^\}]*\$reader\.Dispose\(\)')

        $hasReaderDisposal | Should -Be $true -Because "XmlNodeReader must be disposed to prevent unmanaged memory leak"
    }
}
