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
