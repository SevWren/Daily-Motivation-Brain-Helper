# Getting Started with Daily Motivation Brain Helper

**Last Updated:** 2026-06-09

Welcome! This guide will help you get up and running with Daily Motivation Brain Helper in just a few minutes.

---

## 1. Welcome - What This App Does

Daily Motivation Brain Helper is a simple Windows tool that helps you start your work sessions. Here's how it works:

1. **You pick a folder** (like your project folder or work directory)
2. **You schedule it** for tomorrow at 2 PM (or today if it's before 2 PM)
3. **At 2 PM, a motivational popup appears** with an inspiring message
4. **You click "Open Folder"** and Windows Explorer opens your folder automatically

That's it. No coding. No config files. No manual steps.

**Why 2 PM?** Many people struggle with post-lunch focus. This tool gives you a gentle nudge right when you need it most. The motivational message helps you overcome that initial resistance to starting work.

---

## 2. Prerequisites

Before you begin, make sure you have:

- **Windows 10** (build 19041 or later) or **Windows 11**
- **PowerShell 5.1** - This is already included with Windows, so you're good to go
- **No internet connection required** - Everything runs locally on your computer

### Quick PowerShell Check (Optional)

Want to verify you have PowerShell? Here's how:

1. Press `Windows Key + R`
2. Type `powershell` and press Enter
3. A blue window should open - if it does, you're all set!

---

## 3. Quick Start - Download, Run, Schedule in 5 Minutes

### Step 1: Download

1. Go to the [Releases page](https://github.com/SevWren/Daily-Motivation-Brain-Helper/releases)
2. Download the latest ZIP file

### Step 2: Extract

1. Right-click the downloaded ZIP file
2. Select "Extract All..."
3. Choose a location like `C:\DailyMotivation\` or `C:\Users\YourName\DailyMotivation\`
4. Click "Extract"

### Step 3: Run the Setup Script

1. Open the extracted folder
2. Find the file named `UpdateScheduledTask.ps1`
3. **Right-click** on it
4. Select **"Run with PowerShell"**
5. If prompted, click **"Yes"** to run as Administrator

A PowerShell window will open briefly and then close. This one-time setup copies the necessary files to your computer.

### Step 4: Run the App

1. In the extracted folder, open the `src` folder
2. Find `MainApp.ps1`
3. **Right-click** on it
4. Select **"Run with PowerShell"**

The main application window will appear!

---

## 4. First Run Walkthrough

### What You'll See on First Launch

The first time you open the app, you'll see a **Welcome Screen** that explains how everything works:

```
┌────────────────────────────────────────────┐
│                                            │
│   Welcome to Daily Motivation             │
│   Brain Helper                             │
│                                            │
│   Here's how it works:                     │
│                                            │
│   Pick your working folder                 │
│   Schedule it for 2 PM tomorrow            │
│   At 2 PM, a popup opens it for you        │
│                                            │
│   That's it. No settings. No code.         │
│                                            │
│          [ Got it — Let's Go! ]            │
│                                            │
└────────────────────────────────────────────┘
```

Click **"Got it — Let's Go!"** to continue. You won't see this welcome screen again.

### The Main Application Window

After the welcome screen, you'll see the main window with several sections:

1. **Folder Selection Area** - A large box where you can:
   - Click **"Select Folder"** to choose a folder using a dialog
   - Or drag a folder from Windows Explorer and drop it into the box

2. **Schedule Options** - Radio buttons to choose when to open the folder:
   - "Today at 2:00 PM" (only visible if it's before 2 PM)
   - "Tomorrow at 2:00 PM"

3. **Schedule Button** - Click this to create your scheduled task

4. **Recent Folders** - Shows folders you've scheduled before (empty on first run)

5. **Scheduled Tasks** - Shows upcoming scheduled tasks (empty until you create one)

### Hover for Help

Don't know what a button does? Just hover your mouse over any button or control, and a helpful tooltip will appear within 1 second explaining what it does in plain English.

---

## 5. Scheduling Your First Folder - Complete Example

Let's schedule a folder step-by-step!

**Example:** You want to work on a project located at `D:\Projects\ClientA` tomorrow at 2 PM.

### Method 1: Using the Folder Picker (Easiest)

1. Click the **"Select Folder"** button
2. Navigate to your folder (e.g., `D:\Projects\ClientA`)
3. Click **"Select Folder"** in the dialog
4. Back in the app, you'll see "Folder selected: ClientA"
5. Make sure **"Tomorrow at 2:00 PM"** is selected (it's the default)
6. Click the **"Schedule"** button

Done! A green banner will appear at the top saying:
```
✓ Scheduled for tomorrow at 2:00 PM  [Undo]
```

### Method 2: Drag and Drop (Faster)

1. Open Windows Explorer
2. Navigate to your folder (e.g., `D:\Projects\ClientA`)
3. Drag the folder from Explorer
4. Drop it into the large box in the app that says "Drop a folder here, or..."
5. The folder path will appear automatically
6. Click the **"Schedule"** button

### The Undo Grace Period

After scheduling, you have **30 seconds** to change your mind:
- Click **"Undo"** in the green banner to cancel the schedule
- A progress bar shows how much time you have left
- If you don't click Undo, the task stays scheduled (which is what you want!)

---

## 6. Testing It Works - How to Verify Task Runs

You don't have to wait until tomorrow to test! Here's how to verify everything is working:

### Check Scheduled Tasks

1. In the main app window, look at the **"Scheduled Tasks"** section at the bottom
2. You should see your scheduled folder listed with the date and time
3. Example: `ClientA - Tomorrow 2:00 PM`

### Verify in Windows Task Scheduler (Optional)

Want to see it in Windows' built-in Task Scheduler?

1. Press `Windows Key + R`
2. Type `taskschd.msc` and press Enter
3. In the left panel, click **"Task Scheduler Library"**
4. Look for a task named `DailyMotivation_ClientA` or similar
5. Double-click it to see details like the trigger time (2:00 PM)

### What Happens at 2 PM

At the scheduled time:

1. A popup window appears with:
   - A motivational message (randomly selected)
   - The folder name you're opening
   - A countdown timer (auto-opens in 20 seconds if you don't click)
   - Three buttons: "Dismiss for Today", "Snooze", and "Open Folder"

2. Click **"Open Folder"** and Windows Explorer opens your folder

3. The task completes and is recorded in your history

---

## 7. Customizing Messages - Editing messages.json

The app comes with 10 default motivational messages like:
- "Time to Show Up - Every great outcome starts with showing up..."
- "One Step Forward - You don't have to see the whole staircase..."
- "Small Progress Counts - Small progress is still progress..."

### Where the Messages Are Stored

Messages are stored in a JSON file at:
```
C:\DailyMotivation\src\data\messages.json
```

### How to Edit Messages (For Advanced Users)

**Note:** Most users don't need to edit this file - the default messages work great! But if you want to customize them:

1. Navigate to `C:\DailyMotivation\src\data\`
2. Right-click `messages.json`
3. Select **"Edit with Notepad"** (or any text editor)
4. Each message has this format:
   ```json
   {
     "message_id": "default-001",
     "glyph": "[+]",
     "title": "Time to Show Up",
     "body": "Every great outcome starts with showing up...",
     "is_default": true
   }
   ```
5. You can change the `title` and `body` text
6. Save the file
7. Your changes will appear in the next popup

**Important:** Don't delete the file or break the JSON structure (keep all the commas and brackets), or the app may not work properly.

---

## 8. Managing Tasks - Add, Remove, View

### Adding More Tasks

You can schedule multiple folders! Just repeat the scheduling process:

1. Open the app again
2. Select a different folder
3. Click "Schedule"

Each folder gets its own scheduled task.

### Removing a Scheduled Task

Changed your mind about a scheduled folder?

1. Open the app
2. Look at the **"Scheduled Tasks"** section at the bottom
3. Find the task you want to remove
4. Click the **"Delete"** button next to it
5. Confirm when prompted

The task is immediately removed from Windows Task Scheduler.

### Rescheduling the Same Folder

The app remembers your last scheduled folder! When you open the app a second time, you'll see a banner at the top:

```
💡 Schedule same as last time?
D:\Projects\ClientA  [Yes, Schedule] [✕]
```

Click **"Yes, Schedule"** to instantly schedule the same folder again - no folder picker needed!

### Recent Folders List

The app shows your **top 5 most recently scheduled folders** in the middle section. Click the arrow button **[→]** next to any folder to schedule it again instantly.

### Viewing Task History

Want to see which folders you've opened in the past?

1. Click the **"View History"** button at the bottom
2. A panel opens showing past tasks with:
   - Date
   - Folder name
   - Outcome (Opened, Snoozed, or Dismissed)

Example:
```
2026-06-08  ClientA    ✅ Opened
2026-06-07  GameDev    💤 Snoozed 3x
2026-06-06  Archive    ✖ Dismissed
```

---

## 9. Troubleshooting Quick Tips - 5 Most Common Issues

### Issue 1: "Nothing happens when I click Schedule"

**Solution:** Make sure you've selected a folder first. The Schedule button only works after you've picked a folder using the picker or drag-and-drop.

### Issue 2: "The popup didn't appear at 2 PM"

**Possible causes:**
1. Your computer was asleep or shut down at 2 PM
2. The scheduled task was accidentally deleted

**Solution:**
- Check if the task still exists in Task Scheduler (press `Windows Key + R`, type `taskschd.msc`)
- Reschedule the folder using the app

### Issue 3: "I can't run the setup script (UpdateScheduledTask.ps1)"

**Solution:**
- Make sure you're right-clicking and selecting **"Run with PowerShell"** (not just double-clicking)
- Click **"Yes"** when prompted to run as Administrator
- If you get a security warning, you may need to unblock the file:
  - Right-click `UpdateScheduledTask.ps1`
  - Select "Properties"
  - Check "Unblock" at the bottom
  - Click "OK" and try again

### Issue 4: "The folder I scheduled was moved, and now the popup shows an error"

**Solution:** The app has you covered! When the popup appears and detects the folder is missing, it will show:
```
⚠️ Folder Not Found
This folder was moved or deleted.
[Choose New Location]  [Dismiss]
```
Click **"Choose New Location"** to pick the folder's new location.

### Issue 5: "I accidentally scheduled the same folder twice"

**Solution:** The app warns you before creating duplicate tasks! If you try to schedule the same folder for the same time, you'll see a warning dialog. You can:
- Cancel to avoid the duplicate
- Or continue if you really want two reminders

---

## 10. Next Steps - Link to Advanced Docs

Congratulations! You now know everything you need to use Daily Motivation Brain Helper effectively.

### Want to Learn More?

Check out these additional resources in the `docs` folder:

- **[USER_STORIES.md](USER_STORIES.md)** - All the features explained as user stories
- **[INSTALL.md](INSTALL.md)** - Detailed installation instructions and developer setup
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - How the application works under the hood (for technical users)
- **[UX_SPEC.md](UX_SPEC.md)** - Complete UI specification with wireframes

### Optional Advanced Features

Want even more productivity power?

**Explorer Right-Click Integration:** Schedule folders directly from Windows Explorer without opening the app.

To enable:
1. Navigate to `src\ShellExtension\`
2. Right-click `Register-ShellExtension.ps1`
3. Select "Run with PowerShell" (as Administrator)

Now you can right-click any folder in Windows Explorer and select **"Schedule with Daily Motivation"** to schedule it in 2 clicks!

---

## Quick Reference Card

Print this out and keep it handy:

| Task | How To Do It |
|------|-------------|
| **Schedule a folder** | Open app → Select folder → Click Schedule |
| **Schedule same folder again** | Open app → Click "Yes, Schedule" in banner |
| **Remove a scheduled task** | Open app → Find task in list → Click Delete |
| **See what's scheduled** | Open app → Look at "Scheduled Tasks" section |
| **View past openings** | Open app → Click "View History" |
| **Test if it's working** | Check Task Scheduler: `Win+R` → `taskschd.msc` |
| **Snooze the popup** | When popup appears → Click "Snooze" → Pick duration |
| **Get help** | Hover over any button for a tooltip |

---

## Need Help?

- **Check the logs:** If something goes wrong, check `%TEMP%\DailyMotivation_debug.log` for detailed error messages
- **Ask for support:** Open an issue on the [GitHub repository](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues)
- **Read the docs:** Explore the `docs` folder for detailed technical documentation

---

**You're all set!** Schedule your first folder and see how much easier it is to start your work sessions with a little motivation and automation. Good luck!
