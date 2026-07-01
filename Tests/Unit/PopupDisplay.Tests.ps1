#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Unit tests for popup display functions and text rendering in DailyMotivation.ps1.
    Covers: AG12-001 (XML escaping), AG12-003 (text truncation), AG12-005 (markup stripping)
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
}

Describe 'Escape-XmlText' {
    Context 'AG12-001: XML character escaping for WPF TextBlock' {
        It 'Should escape less-than symbol' {
            $result = Escape-XmlText '<test'
            $result | Should -Be '&lt;test'
        }

        It 'Should escape greater-than symbol' {
            $result = Escape-XmlText 'test>'
            $result | Should -Be 'test&gt;'
        }

        It 'Should escape ampersand' {
            $result = Escape-XmlText 'Project & Marketing'
            $result | Should -Be 'Project &amp; Marketing'
        }

        It 'Should escape double quotes' {
            $result = Escape-XmlText 'My "Special" Folder'
            $result | Should -Be 'My &quot;Special&quot; Folder'
        }

        It 'Should escape single quotes' {
            $result = Escape-XmlText "It's working"
            $result | Should -Be "It&apos;s working"
        }

        It 'Should handle multiple special characters in one string' {
            $result = Escape-XmlText 'Project <Q4> & "Marketing"'
            $result | Should -Be 'Project &lt;Q4&gt; &amp; &quot;Marketing&quot;'
        }

        It 'Should return unchanged text if no special characters' {
            $result = Escape-XmlText 'Normal Folder Name'
            $result | Should -Be 'Normal Folder Name'
        }

        It 'Should handle empty string' {
            $result = Escape-XmlText ''
            $result | Should -Be ''
        }

        It 'Should handle null input gracefully' {
            $result = Escape-XmlText $null
            $result | Should -Be ''
        }
    }
}

Describe 'Truncate-TextForDisplay' {
    Context 'AG12-003: Text length truncation for popup body' {
        It 'Should not truncate text under 150 characters' {
            $text = "This is a normal message that fits within limits"
            $result = Truncate-TextForDisplay -Text $text -MaxLength 150
            $result | Should -Be $text
        }

        It 'Should truncate text over 150 characters with ellipsis' {
            $text = "A" * 160
            $result = Truncate-TextForDisplay -Text $text -MaxLength 150
            $result.Length | Should -Be 150
            $result | Should -Match '\.\.\.$'
        }

        It 'Should preserve content and add ellipsis at exactly 150 chars' {
            $text = "A" * 160
            $result = Truncate-TextForDisplay -Text $text -MaxLength 150
            $result | Should -Be (("A" * 147) + "...")
        }

        It 'Should handle empty string' {
            $result = Truncate-TextForDisplay -Text "" -MaxLength 150
            $result | Should -Be ""
        }

        It 'Should handle null input gracefully' {
            $result = Truncate-TextForDisplay -Text $null -MaxLength 150
            $result | Should -Be ''
        }

        It 'Should handle text exactly at max length' {
            $text = "A" * 150
            $result = Truncate-TextForDisplay -Text $text -MaxLength 150
            $result | Should -Be $text
        }

        It 'Should handle custom max length' {
            $text = "A" * 100
            $result = Truncate-TextForDisplay -Text $text -MaxLength 50
            $result.Length | Should -Be 50
            $result | Should -Match '\.\.\.$'
        }
    }
}
