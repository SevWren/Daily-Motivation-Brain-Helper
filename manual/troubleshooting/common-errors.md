# Common errors

## Popup does not appear at the scheduled time

**Symptom:** The folder was scheduled successfully but no popup appeared when the time passed.

**Causes and fixes:**

1. **Windows Task Scheduler service is stopped.**
   Open `services.msc`, find "Task Scheduler", and ensure it is Running and set to Automatic.

2. **The exe was moved or renamed after scheduling.**
   Task Scheduler stores the path to `DailyMotivation.exe` at schedule time. If you move the exe, the OS Task points to a missing file. Re-schedule the folder from the new location.

3. **The task was deleted from Task Scheduler outside the app.**
   Open the main window and click **Refresh**. Tasks whose OS Task entries are gone will show status `DELETED`. Re-schedule the folder.

4. **You are running the `.ps1` source directly instead of the compiled exe.**
   Task Scheduler tasks are registered to call the `.exe`. Running the `.ps1` directly in the same session does not trigger the registered OS Task. Use `DailyMotivation.exe`.

---

## "Path Missing" shown in popup

**Symptom:** The popup fires but shows a "path not found" panel instead of the normal motivational message.

**Cause:** The folder path stored at schedule time no longer exists on disk (renamed, deleted, network drive unavailable).

**Fix:** In the path-missing panel, click **Change Folder** to pick a replacement path, or click **Dismiss** to cancel this reminder. Re-schedule the correct folder from the main window.

---

## Scheduled task shows status DELETED

**Symptom:** In the main window task list, a task shows `DELETED`.

**Cause:** The corresponding OS Task in Windows Task Scheduler was removed (manually, by another app, or by a system policy) while the `tasks.json` record still exists.

**Fix:** This is informational — the task will not fire again. You can delete the record from the main window list and re-schedule if needed.

---

## "Access Denied" error when scheduling

**Symptom:** An error dialog says "Access Denied" or the task fails to register.

**Causes and fixes:**

1. **Task Scheduler restrictions via Group Policy.**
   Some enterprise Group Policy configurations prevent non-admin users from creating tasks. Contact your IT administrator.

2. **Running from a restricted path.**
   Move `DailyMotivation.exe` to a folder under your user profile (e.g. `%USERPROFILE%\Apps\`) rather than a system folder. The exe must be at a path Task Scheduler can access as your user.

---

## Context menu entry does not appear

**Symptom:** Right-clicking a folder in Explorer does not show "Set as tomorrow's folder (Daily Motivation)".

**Cause:** The entry is registered after your first successful schedule. It may not be present if you have never scheduled a folder.

**Fix:** Open the main window, schedule any folder, and the context menu entry will be registered. Restart Explorer if it does not appear immediately (`explorer.exe` via Task Manager > File > Run new task).

---

## Multiple popups appearing

**Symptom:** More than one popup window appears at the same time.

**Cause:** The popup mutex (`Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`) prevents duplicate popups within the same user session. Multiple popups can appear across different user sessions (e.g. Remote Desktop sessions) because they are intentionally isolated.

**Fix:** If you see duplicates in the same session, check Task Scheduler for duplicate `DailyMotivation_*` tasks and remove the extras using the main window.

---

## Logs and diagnostic information

The outcome log is at `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt`. It records pipe-delimited entries:

```
[yyyy-MM-dd HH:mm:ss] | {task_id} | {folder_name} | HASH:{sha256} | {Outcome} | {snooze_count}
```

Note: folder paths are stored as SHA-256 hashes, not plaintext. Include relevant lines when opening a bug report (paths are safe to share).
