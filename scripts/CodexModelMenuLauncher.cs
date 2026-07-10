using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

internal static class Program
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(
        IntPtr window,
        string text,
        string caption,
        uint type
    );

    [STAThread]
    private static int Main()
    {
        string localAppData = Environment.GetFolderPath(
            Environment.SpecialFolder.LocalApplicationData
        );
        try
        {
            string scriptPath = Path.Combine(
                localAppData,
                "Codex-5.6-Launcher",
                "Launch-Codex-Model-Menu.ps1"
            );
            string workingDirectory = Path.Combine(
                localAppData,
                "Codex-5.6-Launcher"
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
        catch (Exception error)
        {
            string message = "Codex Model Menu could not start.\n\n" + error.Message;
            try
            {
                string launcherDirectory = Path.Combine(
                    localAppData,
                    "Codex-5.6-Launcher"
                );
                Directory.CreateDirectory(launcherDirectory);
                File.AppendAllText(
                    Path.Combine(launcherDirectory, "launcher.log"),
                    DateTime.UtcNow.ToString("u") +
                        " C# launcher ERROR: " +
                        error.Message +
                        Environment.NewLine,
                    Encoding.UTF8
                );
            }
            catch
            {
                // The visible error below is still useful if local logging fails.
            }
            MessageBox(IntPtr.Zero, message, "Codex Model Menu", 0x10);
            return 1;
        }
    }
}
