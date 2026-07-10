using System;
using System.Diagnostics;
using System.IO;

internal static class Program
{
    [STAThread]
    private static int Main()
    {
        try
        {
            string localAppData = Environment.GetFolderPath(
                Environment.SpecialFolder.LocalApplicationData
            );
            string scriptPath = Path.Combine(
                localAppData,
                "Codex-5.6-Launcher",
                "Launch-Codex-Model-Menu.ps1"
            );
            string workingDirectory = Path.Combine(
                localAppData,
                "Programs",
                "Codex-5.6"
            );

            var startInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments =
                    "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" +
                    scriptPath +
                    "\"",
                WorkingDirectory = workingDirectory,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
            };

            Process.Start(startInfo);
            return 0;
        }
        catch
        {
            return 1;
        }
    }
}
