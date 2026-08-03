@{
    Severity = @('Warning', 'Error')

    ExcludeRules = @(
        # DailyMotivation.ps1 is a standalone script, not a module.
        # The rules below flag patterns that are intentional for this app type.

        # Empty catch blocks are intentional in UI/WPF cleanup paths where silent
        # error suppression is correct behavior (e.g. disposing optional resources).
        'PSAvoidUsingEmptyCatchBlock'

        # ShouldProcess is not applicable to a standalone WPF GUI app; these
        # functions are internal helpers, not public cmdlets.
        'PSUseShouldProcessForStateChangingFunctions'

        # Helper functions use verbs like Do-, Escape-, Truncate-, Strip- which
        # are internal to the script and not public cmdlet names.
        'PSUseApprovedVerbs'

        # Plural nouns in function names (e.g. Sync-TaskStatuses, Get-MotivationTasks)
        # are part of the established domain language for this app.
        'PSUseSingularNouns'

        # BOM is intentionally omitted; .gitattributes enforces eol=lf UTF-8.
        'PSUseBOMForUnicodeEncodedFile'

        # Unused parameters may be part of delegate/event handler signatures.
        'PSReviewUnusedParameter'

        # Variable assigned but used indirectly (e.g. via XAML binding or closure).
        'PSUseDeclaredVarsMoreThanAssignments'
    )
}
