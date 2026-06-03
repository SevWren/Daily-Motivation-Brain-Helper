// =============================================================================
// MotivationShellExt.cs -- Daily Motivation Brain Helper Shell Extension
// TASK-NEW-02 / B-13: Adds "Schedule for Tomorrow at 2 PM" to Explorer right-click
//
// Build: csc /target:library /out:MotivationShellExt.dll MotivationShellExt.cs
//        (or use Register-ShellExtension.ps1 which handles compilation)
//
// Registration: Register-ShellExtension.ps1 (run once as Administrator)
// =============================================================================

using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using Microsoft.Win32;

namespace DailyMotivationBrainHelper
{
    // Shell extension CLSID -- generated once, stable across installs
    [ComVisible(true)]
    [Guid("A1B2C3D4-E5F6-7890-ABCD-EF1234567890")]
    [ClassInterface(ClassInterfaceType.None)]
    public class MotivationContextMenu : IShellExtInit, IContextMenu
    {
        private string _folderPath = string.Empty;
        private const int IDM_SCHEDULE = 0;

        // ----------------------------------------------------------------
        // IShellExtInit: called by Explorer to initialize the extension
        // ----------------------------------------------------------------
        public void Initialize(IntPtr pidlFolder, IDataObject dataObject, IntPtr hKeyProgId)
        {
            if (dataObject == null) return;

            FORMATETC fmt = new FORMATETC
            {
                cfFormat = (short)CLIPFORMAT.CF_HDROP,
                ptd      = IntPtr.Zero,
                dwAspect = DVASPECT.DVASPECT_CONTENT,
                lindex   = -1,
                tymed    = TYMED.TYMED_HGLOBAL
            };

            STGMEDIUM medium;
            dataObject.GetData(ref fmt, out medium);

            try
            {
                uint count = DragQueryFile(medium.unionmember, 0xFFFFFFFF, null, 0);
                if (count > 0)
                {
                    System.Text.StringBuilder sb = new System.Text.StringBuilder(260);
                    DragQueryFile(medium.unionmember, 0, sb, (uint)sb.Capacity);
                    string path = sb.ToString();
                    if (Directory.Exists(path))
                        _folderPath = path;
                }
            }
            finally
            {
                ReleaseStgMedium(ref medium);
            }
        }

        // ----------------------------------------------------------------
        // IContextMenu: add menu item
        // ----------------------------------------------------------------
        public int QueryContextMenu(IntPtr hMenu, uint indexMenu, uint idCmdFirst,
                                    uint idCmdLast, uint uFlags)
        {
            if (string.IsNullOrEmpty(_folderPath)) return 0;
            if ((uFlags & 0x000F) != 0) return 0; // CMF_DEFAULTONLY etc.

            InsertMenu(hMenu, indexMenu, MF_BYPOSITION | MF_STRING,
                       idCmdFirst + IDM_SCHEDULE,
                       "Schedule for Tomorrow at 2 PM");

            return 1; // number of items added
        }

        public void GetCommandString(UIntPtr idCmd, uint uType, IntPtr pReserved,
                                     System.Text.StringBuilder pszName, uint cchMax)
        {
            if (idCmd.ToUInt32() == IDM_SCHEDULE && (uType & GCS_VERBW) != 0)
                pszName.Append("ScheduleForTomorrow");
        }

        public void InvokeCommand(IntPtr pici)
        {
            if (string.IsNullOrEmpty(_folderPath)) return;

            // Call the PowerShell bridge script
            string appData   = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string bridge    = Path.Combine(appData, "DailyMotivationBrainHelper", "ShellBridge.ps1");
            string psExe     = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                @"WindowsPowerShell\v1.0\powershell.exe");

            if (!File.Exists(bridge)) return;

            string args = string.Format(
                "-NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass " +
                "-File \"{0}\" \"{1}\"", bridge, _folderPath);

            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName        = psExe,
                Arguments       = args,
                UseShellExecute = false,
                CreateNoWindow  = true
            });
        }

        // ----------------------------------------------------------------
        // P/Invoke declarations
        // ----------------------------------------------------------------
        [DllImport("shell32.dll", CharSet = CharSet.Auto)]
        private static extern uint DragQueryFile(IntPtr hDrop, uint iFile,
            System.Text.StringBuilder lpszFile, uint cch);

        [DllImport("ole32.dll")]
        private static extern void ReleaseStgMedium(ref STGMEDIUM pmedium);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern bool InsertMenu(IntPtr hMenu, uint uPosition, uint uFlags,
            uint uIDNewItem, string lpNewItem);

        private const uint MF_BYPOSITION = 0x00000400;
        private const uint MF_STRING     = 0x00000000;
        private const uint GCS_VERBW     = 0x00000004;

        private enum CLIPFORMAT : short { CF_HDROP = 15 }
    }

    // ----------------------------------------------------------------
    // COM registration helpers (called by regasm / Register-ShellExtension.ps1)
    // ----------------------------------------------------------------
    [ComRegisterFunction]
    public static void RegisterServer(Type t)
    {
        string clsid = "{" + t.GUID.ToString().ToUpper() + "}";
        // Register for all folders
        using (var key = Registry.ClassesRoot.CreateSubKey(
            @"Directory\shellex\ContextMenuHandlers\DailyMotivation"))
        {
            key.SetValue(null, clsid);
        }
        // Approve the extension
        using (var key = Registry.LocalMachine.OpenSubKey(
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved", true))
        {
            key?.SetValue(clsid, "Daily Motivation Brain Helper");
        }
    }

    [ComUnregisterFunction]
    public static void UnregisterServer(Type t)
    {
        Registry.ClassesRoot.DeleteSubKeyTree(
            @"Directory\shellex\ContextMenuHandlers\DailyMotivation", false);
        string clsid = "{" + t.GUID.ToString().ToUpper() + "}";
        using (var key = Registry.LocalMachine.OpenSubKey(
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved", true))
        {
            key?.DeleteValue(clsid, false);
        }
    }
}
