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

Describe 'Message title and body validation' {
    Context 'AG12-004: Title and body length limits' {
        It 'All message titles should be 40 characters or less' {
            foreach ($msg in $Messages) {
                $msg.Title.Length | Should -BeLessOrEqual 40 -Because "Title '$($msg.Title)' exceeds 40 char limit"
            }
        }

        It 'All message bodies should be 150 characters or less' {
            foreach ($msg in $Messages) {
                $msg.Body.Length | Should -BeLessOrEqual 150 -Because "Body for '$($msg.Title)' exceeds 150 char limit"
            }
        }
    }
}

Describe 'Snooze refreshes popup_config.json task_id (BUG-B, issue #183)' {
    Context 'Stale task_id cleanup gap' {
        BeforeAll {
            $src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
            $functionStart = $src.IndexOf('function Show-PopupWindow')
            $functionEnd   = $src.IndexOf('# ============================================================', $functionStart + 100)
            $script:popupBody = $src.Substring($functionStart, $functionEnd - $functionStart)

            $snoozeStart  = $script:popupBody.IndexOf('$snoozeBtn.Add_Click({')
            $dismissStart = $script:popupBody.IndexOf('$dismissBtn.Add_Click({')
            $script:snoozeHandler = $script:popupBody.Substring($snoozeStart, $dismissStart - $snoozeStart)
        }

        It 'The Snooze handler refreshes popup_config.json after creating the snoozed task' {
            # BUG-B: New-MotivationTask in the snooze path creates a NEW TaskId, but
            # if popup_config.json is not refreshed it still holds the original id.
            # The next popup's post-close Remove-MotivationTask then targets the
            # already-removed id (a no-op) and the snoozed OS task is never deleted.
            $script:snoozeHandler -match 'Set-PopupConfig' | Should -Be $true -Because `
                'the snooze handler must write the new TaskId to popup_config.json so the snoozed task is cleaned up when it fires'
        }
    }
}

Describe 'Strip-MarkupText' {
    Context 'AG12-005: Remove markdown and HTML formatting' {
        It 'Should strip markdown bold syntax' {
            $result = Strip-MarkupText '**bold text**'
            $result | Should -Be 'bold text'
        }

        It 'Should strip markdown italic syntax' {
            $result = Strip-MarkupText '*italic text*'
            $result | Should -Be 'italic text'
        }

        It 'Should strip markdown links' {
            $result = Strip-MarkupText '[link text](http://example.com)'
            $result | Should -Be 'link text'
        }

        It 'Should strip HTML tags' {
            $result = Strip-MarkupText '<b>bold</b> and <a href="url">link</a>'
            $result | Should -Be 'bold and link'
        }

        It 'Should strip multiple markdown formats' {
            $result = Strip-MarkupText '**bold** and *italic* and ~~strike~~'
            $result | Should -Be 'bold and italic and strike'
        }

        It 'Should handle text with no markup' {
            $result = Strip-MarkupText 'plain text'
            $result | Should -Be 'plain text'
        }

        It 'Should handle empty string' {
            $result = Strip-MarkupText ''
            $result | Should -Be ''
        }

        It 'Should handle null input gracefully' {
            $result = Strip-MarkupText $null
            $result | Should -Be ''
        }
    }
}
