#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for the messages array and Get-RandomMessage in DailyMotivation.ps1.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
}

Describe 'Messages array ($Messages)' {
    It 'Should contain at least one message' {
        $Messages | Should -Not -BeNullOrEmpty
        @($Messages).Count | Should -BeGreaterThan 0
    }

    It 'Each message should have a non-empty glyph' {
        foreach ($msg in $Messages) {
            $msg.glyph | Should -Not -BeNullOrEmpty
        }
    }

    It 'Each message should have a non-empty title' {
        foreach ($msg in $Messages) {
            $msg.title | Should -Not -BeNullOrEmpty
        }
    }

    It 'Each message should have a non-empty body' {
        foreach ($msg in $Messages) {
            $msg.body | Should -Not -BeNullOrEmpty
        }
    }

    It 'Should contain the expected 10 default messages' {
        @($Messages).Count | Should -Be 10
    }
}

Describe 'Get-RandomMessage' {
    It 'Should return a non-null object' {
        $msg = Get-RandomMessage
        $msg | Should -Not -BeNullOrEmpty
    }

    It 'Should return an object with glyph, title, and body' {
        $msg = Get-RandomMessage
        $msg.glyph | Should -Not -BeNullOrEmpty
        $msg.title | Should -Not -BeNullOrEmpty
        $msg.body  | Should -Not -BeNullOrEmpty
    }

    It 'Should return a message whose glyph is in the expected bracket format' {
        $msg = Get-RandomMessage
        # AG8-015: Use -Match for regex validation
        $msg.glyph | Should -Match '^\[.\]$'
    }

    # AG8-015: Add strict glyph validation tests
    It 'Should return glyphs without trailing spaces (strict validation)' {
        $msg = Get-RandomMessage
        # Verify glyph doesn't have trailing space: '[+] ' should fail
        $msg.glyph | Should -Not -Match '\s$'
    }

    It 'Should use exact glyph format from known set' {
        # AG8-015: Test that glyphs match expected exact values
        $knownGlyphs = @('[+]', '[♦]', '[●]', '[■]', '[▲]', '[★]', '[◆]', '[○]', '[□]', '[☼]')
        $msg = Get-RandomMessage
        # Glyph should be exactly one of the known values (case-sensitive)
        $knownGlyphs | Should -Contain $msg.glyph
    }

    It 'Each message glyph should be exactly 3 characters long' {
        # AG8-015: Strict length validation
        foreach ($msg in $Messages) {
            $msg.glyph.Length | Should -BeExactly 3 -Because "Glyphs are '[char]' format"
        }
    }

    It 'Should return different messages across multiple calls (randomness check)' {
        # With 10 messages, 20 draws should include at least 2 distinct titles
        $titles = 1..20 | ForEach-Object { (Get-RandomMessage).title }
        ($titles | Select-Object -Unique).Count | Should -BeGreaterThan 1
    }
}
