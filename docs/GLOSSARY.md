# Glossary

| Term | Definition |
|------|-----------|
| Scheduled Task | A Windows Task Scheduler entry that fires the popup at a specific time |
| Popup | The WPF motivational notification window |
| Snooze | Dismissing the popup temporarily; it reappears in 5 minutes |
| Accept / Open Folder | The action that completes a scheduled task and opens Windows Explorer |
| Folder Path | The absolute Windows filesystem path to the user's target folder |
| Explorer Launcher | The component that calls `explorer.exe` with the target folder path |
| Snooze Loop | The cycle of popup → snooze → reappear that repeats until acceptance |
| Task Completion | The state reached when the user clicks "Open Folder" |
| popup_config.json | The local config file read by the PowerShell popup script (never edited by user) |
| Motivation Repository | The store of motivational messages available for popup display |
