using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

internal static class GodotProjectLauncher
{
    private const string EnginePath = @"F:\Program Files\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64.exe";

    [STAThread]
    private static int Main(string[] args)
    {
        if (!File.Exists(EnginePath))
        {
            MessageBox.Show(
                "Godot engine was not found:\n" + EnginePath,
                "Godot launcher",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }

        string exePath = Assembly.GetExecutingAssembly().Location;
        string projectDir = Path.GetDirectoryName(exePath);
        if (String.IsNullOrEmpty(projectDir) || !File.Exists(Path.Combine(projectDir, "project.godot")))
        {
            MessageBox.Show(
                "project.godot was not found next to this launcher.",
                "Godot launcher",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }

        var arguments = new StringBuilder();
        arguments.Append("--path ");
        arguments.Append(Quote(projectDir));
        foreach (string arg in args)
        {
            arguments.Append(' ');
            arguments.Append(Quote(arg));
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = EnginePath,
            Arguments = arguments.ToString(),
            WorkingDirectory = projectDir,
            UseShellExecute = false
        };
        Process.Start(startInfo);
        return 0;
    }

    private static string Quote(string value)
    {
        if (value == null)
        {
            return "\"\"";
        }
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
