using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using Microsoft.Win32;

namespace ViaVoiceSetup
{
    class Program
    {
    static string Repo = "tech-master33/viavoice";
    static string Version = "v1.0.0";
    static string LibrariesRepo = "";
    static string ZipUrl = "https://github.com/" + Repo + "/releases/download/" + Version + "/viavoice-" + Version + ".zip";
    static string InstDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "ViaVoice");

    static int Main(string[] args)
    {
        foreach (string arg in args)
        {
            if (arg == "-uninstall")
                return Uninstall();
            if (arg.StartsWith("-libraries:"))
                LibrariesRepo = arg.Substring("-libraries:".Length);
        }

            if (!IsAdmin())
            {
                var psi = new ProcessStartInfo();
                psi.FileName = Assembly.GetExecutingAssembly().Location;
                psi.UseShellExecute = true;
                psi.Verb = "runas";
                Process.Start(psi);
                return 0;
            }

            Console.WriteLine("=== ViaVoice Setup ===");
            string tempDir = Path.Combine(Path.GetTempPath(), "ViaVoiceSetup");
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            Directory.CreateDirectory(tempDir);

            string zipPath = Path.Combine(tempDir, "release.zip");
            string extractDir = Path.Combine(tempDir, "extract");

            try
            {
                Console.Write("Downloading release...");
                using (var wc = new WebClient())
                    wc.DownloadFile(ZipUrl, zipPath);
                Console.WriteLine(" OK");

                Console.Write("Extracting...");
                ZipFile.ExtractToDirectory(zipPath, extractDir);
                Console.WriteLine(" OK");

                // Clone/update libraries repo if configured
                if (LibrariesRepo != "")
                {
                    string libDir = Path.Combine(tempDir, "libraries");
                    if (Directory.Exists(libDir))
                    {
                        Console.Write("Updating libraries repo...");
                        Run("git -C \"" + libDir + "\" pull");
                    }
                    else
                    {
                        Console.Write("Cloning libraries repo...");
                        Run("git clone https://github.com/" + LibrariesRepo + ".git \"" + libDir + "\"");
                    }
                    Console.WriteLine(" OK");
                    // Copy IBMECI.dll from libraries if present
                    string libDll = Path.Combine(libDir, "IBMECI.dll");
                    if (File.Exists(libDll))
                    {
                        File.Copy(libDll, Path.Combine(extractDir, "bin", "IBMECI.dll"), true);
                        Console.WriteLine("IBMECI.dll updated from libraries repo");
                    }
                }

                InstallFromDir(extractDir);
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.WriteLine("Download failed: " + ex.Message);
                Console.WriteLine("Falling back to local files...");
                string selfDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                InstallFromDir(selfDir);
            }

            try { Directory.Delete(tempDir, true); } catch { }

            Console.WriteLine();
            Console.WriteLine("=== Install complete ===");
            Console.WriteLine("Installed to: " + InstDir);
            Console.WriteLine("Voice Manager: Start Menu > ViaVoice Manager");
            Console.WriteLine("Uninstall: Run this exe with -uninstall");
            return 0;
        }

        static bool IsAdmin()
        {
            var id = System.Security.Principal.WindowsIdentity.GetCurrent();
            var p = new System.Security.Principal.WindowsPrincipal(id);
            return p.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
        }

        static void InstallFromDir(string dir)
        {
            Console.WriteLine("Installing...");

            Directory.CreateDirectory(Path.Combine(InstDir, "bin"));
            Directory.CreateDirectory(Path.Combine(InstDir, "VoiceManager"));

            CopyFile(dir, "bin\\ttseng_dyn.dll", InstDir);
            CopyFile(dir, "bin\\IBMECI.dll", InstDir);
            CopyFile(dir, "VoiceManager\\voice_manager.py", InstDir);

            string dllPath = Path.Combine(InstDir, "bin", "ttseng_dyn.dll");
            string sys32 = Environment.SystemDirectory;
            Run("\"" + sys32 + "\\..\\SysWOW64\\regsvr32.exe\" /s \"" + dllPath + "\"");
            Console.WriteLine("DLL registered");

            string[] hives = {
                @"SOFTWARE\WOW6432Node\Microsoft\Speech\Voices\Tokens",
                @"SOFTWARE\Microsoft\Speech\Voices\Tokens"
            };
            string[] vnames = {
                "Wade","Shelly","Bobbie","Roko","Glenn","Female2","Grandma","Grandpa",
                "Smooth","Deep","Mix","Resonant","Cheerful","Warm","Marble","Echo",
                "Bold","Crystal","Mellow","Vibrant"
            };
            string clsid = "{301EDFC4-D65B-4823-A598-450EE4656837}";
            int count = 0;

            foreach (string hive in hives)
            {
                using (var baseKey = Registry.LocalMachine.CreateSubKey(hive))
                {
                    for (int i = 0; i < vnames.Length; i++)
                    {
                        int num = i + 1;
                        foreach (string rate in new[] { "22kHz", "8kHz" })
                        {
                            int rateVal = rate == "22kHz" ? 0 : 1;
                            string token = "VE_Voice" + num + "_" + vnames[i] + "_" + rate;
                            using (var key = baseKey.CreateSubKey(token))
                            {
                                key.SetValue("", "ViaVoice Voice " + num + " - " + vnames[i]);
                                key.SetValue("CLSID", clsid);
                                key.SetValue("Language", 1, RegistryValueKind.DWord);
                                key.SetValue("Voice", num, RegistryValueKind.DWord);
                                key.SetValue("SampleRate", rateVal, RegistryValueKind.DWord);
                                using (var attr = key.CreateSubKey("Attributes"))
                                {
                                    attr.SetValue("Name", vnames[i]);
                                    attr.SetValue("Gender", (i == 1 || i == 5 || i == 6) ? "Female" : "Male");
                                    attr.SetValue("Age", "Adult");
                                    attr.SetValue("Language", "409;9");
                                }
                            }
                            count++;
                        }
                    }
                }
            }
            Console.WriteLine(count + " voice tokens created");

            try
            {
                Type comType = Type.GetTypeFromProgID("WScript.Shell");
                dynamic shell = Activator.CreateInstance(comType);
                string shortcutPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
                    "Programs", "ViaVoice Manager.lnk");
                dynamic sc = shell.CreateShortcut(shortcutPath);
                sc.TargetPath = "pythonw.exe";
                sc.Arguments = "\"" + Path.Combine(InstDir, "VoiceManager", "voice_manager.py") + "\"";
                sc.WorkingDirectory = Path.Combine(InstDir, "VoiceManager");
                sc.Description = "Configure ViaVoice voice profiles";
                sc.Save();
                Console.WriteLine("Start Menu shortcut created");
            }
            catch (Exception ex)
            {
                Console.WriteLine("Warning: could not create Start Menu shortcut: " + ex.Message);
            }

            try
            {
                using (var root = Registry.CurrentUser.CreateSubKey(@"Software\ViaVoice\Voices"))
                {
                    for (int i = 0; i < vnames.Length; i++)
                    {
                        using (var key = root.CreateSubKey("Voice" + (i + 1)))
                        {
                            key.SetValue("Name", vnames[i]);
                            key.SetValue("Enabled", 1, RegistryValueKind.DWord);
                            key.SetValue("BaseVoice", i + 1, RegistryValueKind.DWord);
                            key.SetValue("PitchBaseline", 60, RegistryValueKind.DWord);
                            key.SetValue("PitchFluctuation", 50, RegistryValueKind.DWord);
                            key.SetValue("Speed", 50, RegistryValueKind.DWord);
                            key.SetValue("Roughness", 0, RegistryValueKind.DWord);
                            key.SetValue("Breathiness", 0, RegistryValueKind.DWord);
                            key.SetValue("HeadSize", 50, RegistryValueKind.DWord);
                            key.SetValue("Gender", 0, RegistryValueKind.DWord);
                            key.SetValue("Age", 0, RegistryValueKind.DWord);
                        }
                    }
                }
            }
            catch { }

            try
            {
                using (var key = Registry.LocalMachine.CreateSubKey(
                    @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\ViaVoice"))
                {
                    key.SetValue("DisplayName", "ViaVoice SAPI5 Engine");
                    key.SetValue("Publisher", "ViaVoice");
                    key.SetValue("DisplayVersion", "1.0");
                    key.SetValue("UninstallString",
                        "\"" + Assembly.GetExecutingAssembly().Location + "\" -uninstall");
                    key.SetValue("InstallLocation", InstDir);
                    key.SetValue("EstimatedSize", 2000, RegistryValueKind.DWord);
                }
            }
            catch { }
        }

        static int Uninstall()
        {
            if (!IsAdmin())
            {
                var psi = new ProcessStartInfo();
                psi.FileName = Assembly.GetExecutingAssembly().Location;
                psi.Arguments = "-uninstall";
                psi.UseShellExecute = true;
                psi.Verb = "runas";
                Process.Start(psi);
                return 0;
            }

            Console.WriteLine("=== Uninstalling ViaVoice ===");

            string dll = Path.Combine(InstDir, "bin", "ttseng_dyn.dll");
            if (File.Exists(dll))
            {
                string sys32 = Environment.SystemDirectory;
                Run("\"" + sys32 + "\\..\\SysWOW64\\regsvr32.exe\" /s /u \"" + dll + "\"");
            }

            string[] hives = {
                @"SOFTWARE\WOW6432Node\Microsoft\Speech\Voices\Tokens",
                @"SOFTWARE\Microsoft\Speech\Voices\Tokens"
            };
            foreach (string hive in hives)
            {
                try
                {
                    using (var key = Registry.LocalMachine.OpenSubKey(hive, true))
                    {
                        if (key != null)
                            foreach (string sub in key.GetSubKeyNames())
                                if (sub.StartsWith("VE_Voice"))
                                    key.DeleteSubKeyTree(sub);
                    }
                }
                catch { }
            }

            try { Registry.CurrentUser.DeleteSubKeyTree(@"Software\ViaVoice"); } catch { }

            try
            {
                string sc = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
                    "Programs", "ViaVoice Manager.lnk");
                if (File.Exists(sc)) File.Delete(sc);
            }
            catch { }

            try
            {
                Registry.LocalMachine.DeleteSubKeyTree(
                    @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\ViaVoice");
            }
            catch { }

            try { Directory.Delete(InstDir, true); } catch { }

            Console.WriteLine("Uninstall complete.");
            return 0;
        }

        static void CopyFile(string srcDir, string relPath, string destDir)
        {
            string src = Path.Combine(srcDir, relPath);
            string dst = Path.Combine(destDir, relPath);
            if (File.Exists(src))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(dst));
                File.Copy(src, dst, true);
            }
        }

        static void Run(string cmd)
        {
            var psi = new ProcessStartInfo("cmd.exe", "/c " + cmd);
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            Process.Start(psi).WaitForExit(30000);
        }
    }
}
