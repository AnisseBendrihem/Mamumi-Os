// Garde de la barre des taches + disposition en spirale (remplace hide-taskbar.ps1).
//   taskbar-guard.exe        cache la barre Windows tant que GlazeWM tourne,
//                            relance la barre Zebar si elle plante,
//                            rend la barre Windows si GlazeWM disparait (~6 s),
//                            et range les nouvelles fenetres en spirale facon Hyprland "dwindle" :
//                            fenetre active plus large que haute -> la suivante s'ouvre a cote,
//                            plus haute que large -> en dessous.
//   taskbar-guard.exe show   arrete la garde et reaffiche la barre Windows.
// Pause : tant que le fichier "taskbar.pause" (meme dossier) a moins de 3 min, la barre reste visible.
// Spirale desactivee si le fichier "autotiling.off" existe (meme dossier).
// Compile : csc /target:winexe /out:taskbar-guard.exe taskbar-guard.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

static class TaskbarGuard
{
    [DllImport("user32.dll")] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);

    static void SetTaskbars(bool visible)
    {
        foreach (var cls in new[] { "Shell_TrayWnd", "Shell_SecondaryTrayWnd" })
        {
            IntPtr h = IntPtr.Zero;
            while ((h = FindWindowEx(IntPtr.Zero, h, cls, null)) != IntPtr.Zero)
                if (IsWindowVisible(h) != visible) ShowWindow(h, visible ? 5 : 0);
        }
    }

    // --- Spirale (autotiling) via l'IPC de GlazeWM (ws://localhost:6123) ---
    static readonly Regex Focused = new Regex(
        "\"focusedContainer\":\\{\"type\":\"window\",\"id\":\"([^\"]+)\".*?\"width\":(\\d+),\"height\":(\\d+).*?\"state\":\\{\"type\":\"(\\w+)\"",
        RegexOptions.Compiled | RegexOptions.Singleline);

    static readonly object ThemeLock = new object();

    static void AutoTiling(string offFlag)
    {
        while (true)
        {
            try
            {
                using (var ws = new ClientWebSocket())
                {
                    ws.ConnectAsync(new Uri("ws://localhost:6123"), CancellationToken.None).Wait();
                    Send(ws, "sub -e focus_changed focused_container_moved binding_modes_changed");
                    string lastKey = null;
                    var buf = new byte[65536];
                    while (ws.State == WebSocketState.Open)
                    {
                        var sb = new StringBuilder();
                        WebSocketReceiveResult r;
                        do
                        {
                            r = ws.ReceiveAsync(new ArraySegment<byte>(buf), CancellationToken.None).Result;
                            if (r.MessageType == WebSocketMessageType.Close) break;
                            sb.Append(Encoding.UTF8.GetString(buf, 0, r.Count));
                        } while (!r.EndOfMessage);
                        if (r.MessageType == WebSocketMessageType.Close) break;
                        string msg = sb.ToString();

                        // Themes (Win + Shift + T) : GlazeWM active un mode "theme-next"/"theme-prev",
                        // on le referme et on applique le theme ici, sans lancer de programme.
                        if (msg.Contains("binding_modes_changed"))
                        {
                            string dirTheme = msg.Contains("\"theme-next\"") ? "next" : msg.Contains("\"theme-prev\"") ? "prev" : null;
                            if (dirTheme != null)
                            {
                                Send(ws, "command wm-disable-binding-mode --name theme-" + dirTheme);
                                var th = new Thread(() => { lock (ThemeLock) { try { ThemeTool.Run(new[] { dirTheme }); } catch { } } });
                                th.SetApartmentState(ApartmentState.STA);
                                th.IsBackground = true;
                                th.Start();
                            }
                            continue;
                        }
                        if (File.Exists(offFlag)) continue;

                        var m = Focused.Match(msg);
                        if (!m.Success || m.Groups[4].Value != "tiling") continue;
                        int w = int.Parse(m.Groups[2].Value), h = int.Parse(m.Groups[3].Value);
                        string dir = w >= h ? "horizontal" : "vertical";
                        string key = m.Groups[1].Value + dir;
                        if (key == lastKey) continue;          // deja regle pour cette fenetre
                        lastKey = key;
                        Send(ws, "command set-tiling-direction " + dir);
                    }
                }
            }
            catch { }
            Thread.Sleep(3000);                                // GlazeWM pas (encore) la : on reessaie
        }
    }

    static void Send(ClientWebSocket ws, string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None).Wait();
    }

    static bool Running(string name)
    {
        var p = Process.GetProcessesByName(name);
        foreach (var x in p) x.Dispose();
        return p.Length > 0;
    }

    static void Main(string[] args)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string stopFlag = Path.Combine(dir, "taskbar-guard.stop");
        string pauseFlag = Path.Combine(dir, "taskbar.pause");

        if (args.Length > 0 && args[0] == "show")
        {
            // Demande a l'instance en cours de s'arreter, puis reaffiche la barre.
            File.WriteAllText(stopFlag, DateTime.Now.ToString("o"));
            Thread.Sleep(700);
            SetTaskbars(true);
            return;
        }

        bool isNew;
        using (var mutex = new Mutex(true, "MamumiTaskbarGuard", out isNew))
        {
            if (!isNew) return;                       // une seule garde a la fois
            try { File.Delete(stopFlag); } catch { }

            var tiler = new Thread(() => AutoTiling(Path.Combine(dir, "autotiling.off"))) { IsBackground = true };
            tiler.Start();

            string zebar = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"glzr.io\Zebar\zebar.exe");
            int tick = 0, noGlaze = 0;
            while (true)
            {
                if (File.Exists(stopFlag)) { try { File.Delete(stopFlag); } catch { } SetTaskbars(true); return; }

                bool paused = File.Exists(pauseFlag) && (DateTime.Now - File.GetLastWriteTime(pauseFlag)).TotalMinutes < 3;
                if (!paused) SetTaskbars(false);

                // Toutes les ~2 s : verifications de securite.
                if (++tick % 7 == 0)
                {
                    if (Running("glazewm"))
                    {
                        noGlaze = 0;
                        if (!Running("zebar") && File.Exists(zebar))
                            try { Process.Start(zebar); } catch { }
                    }
                    else if (++noGlaze >= 3)
                    {
                        SetTaskbars(true);            // jamais sans barre
                        return;
                    }
                }
                Thread.Sleep(300);
            }
        }
    }
}
