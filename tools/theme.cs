// Changeur de theme facon Omarchy (Win + Shift + T / Win + Ctrl + Shift + T).
//   mamumi-theme.exe next | prev | apply | set "<nom>"
// Lit themes.json (meme dossier) et applique le theme a :
//   la barre Zebar (theme.css, recharge a chaud), les bordures GlazeWM, l'accent et le mode
//   clair/sombre de Windows, Windows Terminal, le panneau Win + K (theme.ini). Affiche une notification.
// Compile : csc /target:winexe /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll
//           /out:mamumi-theme.exe theme.cs
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

public static class ThemeTool
{
    // Dir : dossier du programme (themes.json, theme-current.txt, theme.ini).
    // Glzr : config GlazeWM + barre Zebar (toujours %USERPROFILE%\.glzr).
    static string Dir = AppDomain.CurrentDomain.BaseDirectory;
    static string Glzr = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".glzr");
    static readonly Stopwatch Startup = Stopwatch.StartNew();
    static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);

    [STAThread]
    static void Main(string[] args)
    {
        using (var mutex = new Mutex(false, "MamumiOsTheme"))
        {
            if (!mutex.WaitOne(5000)) return;
            try { Run(args); } finally { mutex.ReleaseMutex(); }
        }
    }

    public static void Run(string[] args)
    {
        var js = new JavaScriptSerializer();
        var root = (Dictionary<string, object>)js.DeserializeObject(File.ReadAllText(Path.Combine(Dir, "themes.json"), Encoding.UTF8));
        var themes = new List<Dictionary<string, object>>();
        foreach (var t in (object[])root["themes"]) themes.Add((Dictionary<string, object>)t);

        string currentFile = Path.Combine(Dir, "theme-current.txt");
        string current = File.Exists(currentFile) ? File.ReadAllText(currentFile, Encoding.UTF8).Trim() : (string)themes[0]["name"];
        int idx = Math.Max(0, themes.FindIndex(t => (string)t["name"] == current));

        string mode = args.Length > 0 ? args[0] : "next";
        if (mode == "next") idx = (idx + 1) % themes.Count;
        else if (mode == "prev") idx = (idx - 1 + themes.Count) % themes.Count;
        else if (mode == "set" && args.Length > 1)
        {
            int i = themes.FindIndex(t => string.Equals((string)t["name"], args[1], StringComparison.OrdinalIgnoreCase));
            if (i >= 0) idx = i;
        }
        var th = themes[idx];
        File.WriteAllText(currentFile, (string)th["name"], Utf8);

        // La barre d'abord (c'est ce qu'on voit), puis le reste en parallele de la notification.
        var sw = Stopwatch.StartNew(); var log = new StringBuilder("chargement=" + Startup.ElapsedMilliseconds + "ms ");
        Try(() => ApplyBar(th)); log.Append("barre=" + sw.ElapsedMilliseconds + "ms ");
        var work = new Thread(() =>
        {
            var w = Stopwatch.StartNew();
            var jobs = new[] {
                new Thread(() => Try(() => ApplyWindows(th))),
                new Thread(() => Try(() => ApplyGlaze(th))),
                new Thread(() => Try(() => ApplyTerminal(th, new JavaScriptSerializer()))),
                new Thread(() => Try(() => ApplyKeysPanel(th))) };
            foreach (var j in jobs) j.Start();
            foreach (var j in jobs) j.Join();
            log.Append("reste-en-parallele=" + w.ElapsedMilliseconds + "ms");
            if (Array.IndexOf(args, "--timing") >= 0) File.WriteAllText(Path.Combine(Dir, "theme-timing.log"), log.ToString());
        });
        work.Start();
        if (mode != "apply") Toast(th, idx + 1, themes.Count);
        work.Join();
    }

    static void Try(Action a) { try { a(); } catch { } }
    static string S(Dictionary<string, object> t, string k) { return (string)t[k]; }
    static bool Light(Dictionary<string, object> t) { return t.ContainsKey("light") && (bool)t["light"]; }

    // ---------- couleurs ----------
    static Color Hex(string h) { return ColorTranslator.FromHtml(h); }
    static string ToHex(Color c) { return string.Format("#{0:x2}{1:x2}{2:x2}", c.R, c.G, c.B); }
    static Color Mix(Color a, Color b, double t)
    {
        return Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));
    }
    static int Abgr(Color c, byte alpha) { return BitConverter.ToInt32(new byte[] { c.R, c.G, c.B, alpha }, 0); }
    static string Rgb(Color c) { return c.R + " " + c.G + " " + c.B; }

    // ---------- barre Zebar : theme.css recharge a chaud par la barre ----------
    static void ApplyBar(Dictionary<string, object> t)
    {
        var bg = Hex(S(t, "bg"));
        string css = string.Format(
            ":root {{\n  --bg: rgba({0} / {1}%);\n  --bg-alt: {2};\n  --fg: {3};\n  --fg-dim: {4};\n" +
            "  --accent: {5};\n  --pink: {6};\n  --purple: {6};\n  --blue: {5};\n  --cyan: {6};\n" +
            "  --green: {7};\n  --red: {8};\n  --border: {9};\n}}\n",
            Rgb(bg), Light(t) ? 90 : 82, S(t, "bgAlt"), S(t, "fg"), S(t, "dim"),
            S(t, "accent"), S(t, "accent2"), S(t, "green"), S(t, "red"), S(t, "border"));
        File.WriteAllText(Path.Combine(Glzr, @"zebar\tokyo-night\theme.css"), css, Utf8);
    }

    // ---------- GlazeWM : bordures (fenetre active puis les autres) ----------
    static void ApplyGlaze(Dictionary<string, object> t)
    {
        string cfg = Path.Combine(Glzr, @"glazewm\config.yaml");
        string text = File.ReadAllText(cfg, Encoding.UTF8);
        var re = new Regex("color: '#[0-9a-fA-F]{6}'");
        int n = 0;
        text = re.Replace(text, m => n++ == 0 ? "color: '" + S(t, "accent") + "'" : "color: '" + S(t, "border") + "'", 2);
        File.WriteAllText(cfg, text, Utf8);
        string cli = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"glzr.io\GlazeWM\cli\glazewm.exe");
        if (File.Exists(cli))
            using (var p = Process.Start(new ProcessStartInfo(cli, "command wm-reload-config") { CreateNoWindow = true, UseShellExecute = false }))
                p.WaitForExit(3000);
    }

    // ---------- Windows : accent, menu Demarrer / panneaux, clair ou sombre ----------
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool SendNotifyMessage(IntPtr h, uint msg, UIntPtr w, string l);

    static void ApplyWindows(Dictionary<string, object> t)
    {
        Color accent = Hex(S(t, "accent")), menu = Hex(S(t, "menu")), bg = Hex(S(t, "bg")), dim = Hex(S(t, "dim"));
        bool light = Light(t);
        Color white = Color.White;
        Color[] pal = {
            Mix(accent, white, 0.6), Mix(accent, white, 0.4), Mix(accent, white, 0.2), accent,
            Mix(accent, bg, 0.75), menu, bg, dim };
        var bytes = new List<byte>();
        foreach (var c in pal) { bytes.Add(c.R); bytes.Add(c.G); bytes.Add(c.B); bytes.Add(0); }

        using (var k = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"))
        {
            k.SetValue("AccentPalette", bytes.ToArray(), RegistryValueKind.Binary);
            k.SetValue("AccentColorMenu", Abgr(menu, 0xFF), RegistryValueKind.DWord);
            k.SetValue("StartColorMenu", Abgr(menu, 0xFF), RegistryValueKind.DWord);
        }
        using (var k = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\DWM"))
        {
            k.SetValue("AccentColor", Abgr(accent, 0xFF), RegistryValueKind.DWord);
            int argb = BitConverter.ToInt32(new byte[] { accent.B, accent.G, accent.R, 0xC4 }, 0);
            k.SetValue("ColorizationColor", argb, RegistryValueKind.DWord);
            k.SetValue("ColorizationAfterglow", argb, RegistryValueKind.DWord);
        }
        using (var k = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
        {
            k.SetValue("AppsUseLightTheme", light ? 1 : 0, RegistryValueKind.DWord);
            k.SetValue("SystemUsesLightTheme", light ? 1 : 0, RegistryValueKind.DWord);
            k.SetValue("ColorPrevalence", light ? 0 : 1, RegistryValueKind.DWord);   // teinte du menu Demarrer en sombre
        }
        // Asynchrone : previent toutes les fenetres sans attendre leur reponse (avant : ~280 ms).
        SendNotifyMessage((IntPtr)0xffff, 0x001A, UIntPtr.Zero, "ImmersiveColorSet");
    }

    // ---------- Windows Terminal : schema "Mamumi" ----------
    static void ApplyTerminal(Dictionary<string, object> t, JavaScriptSerializer js)
    {
        string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string path = Path.Combine(local, @"Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json");
        if (!File.Exists(path)) path = Path.Combine(local, @"Microsoft\Windows Terminal\settings.json");
        if (!File.Exists(path)) return;

        string raw = Regex.Replace(File.ReadAllText(path, Encoding.UTF8), @"(?m)^\s*//.*$", "");
        var s = (Dictionary<string, object>)js.DeserializeObject(raw);
        var term = (object[])t["term"];
        string[] names = { "black", "red", "green", "yellow", "blue", "purple", "cyan", "white",
                           "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightPurple", "brightCyan", "brightWhite" };
        var scheme = new Dictionary<string, object> {
            { "name", "Mamumi" }, { "background", S(t, "bg") }, { "foreground", S(t, "fg") },
            { "cursorColor", S(t, "accent") }, { "selectionBackground", ToHex(Mix(Hex(S(t, "accent")), Hex(S(t, "bg")), 0.7)) } };
        for (int i = 0; i < 16; i++) scheme[names[i]] = (string)term[i];

        var schemes = new List<object>();
        if (s.ContainsKey("schemes") && s["schemes"] is object[])
            foreach (var o in (object[])s["schemes"])
                if (!(o is Dictionary<string, object>) || (string)((Dictionary<string, object>)o)["name"] != "Mamumi") schemes.Add(o);
        schemes.Add(scheme);
        s["schemes"] = schemes.ToArray();

        var profiles = (Dictionary<string, object>)s["profiles"];
        if (!profiles.ContainsKey("defaults") || !(profiles["defaults"] is Dictionary<string, object>)) profiles["defaults"] = new Dictionary<string, object>();
        ((Dictionary<string, object>)profiles["defaults"])["colorScheme"] = "Mamumi";

        // Onglets aux couleurs du theme
        var ui = new Dictionary<string, object> {
            { "name", "Mamumi UI" },
            { "tab", new Dictionary<string, object> { { "background", S(t, "bg") + "FF" }, { "unfocusedBackground", S(t, "menu") + "FF" }, { "showCloseButton", "hover" } } },
            { "tabRow", new Dictionary<string, object> { { "background", S(t, "menu") + "FF" }, { "unfocusedBackground", S(t, "menu") + "FF" } } },
            { "window", new Dictionary<string, object> { { "applicationTheme", Light(t) ? "light" : "dark" }, { "useMica", false } } } };
        var uis = new List<object>();
        if (s.ContainsKey("themes") && s["themes"] is object[])
            foreach (var o in (object[])s["themes"])
                if (!(o is Dictionary<string, object>) || (string)((Dictionary<string, object>)o)["name"] != "Mamumi UI") uis.Add(o);
        uis.Add(ui);
        s["themes"] = uis.ToArray();
        s["theme"] = "Mamumi UI";

        js.MaxJsonLength = int.MaxValue;
        File.WriteAllText(path, js.Serialize(s), Utf8);
    }

    // ---------- Panneau Win + K ----------
    static void ApplyKeysPanel(Dictionary<string, object> t)
    {
        var sb = new StringBuilder();
        foreach (var k in new[] { "bg", "bgAlt", "fg", "dim", "accent", "accent2", "border", "menu" }) sb.AppendLine(k + "=" + S(t, k));
        File.WriteAllText(Path.Combine(Dir, "theme.ini"), sb.ToString(), Utf8);
    }

    // ---------- Notification ----------
    class ToastForm : Form
    {
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams
        {
            get { var cp = base.CreateParams; cp.ExStyle |= 0x08000000 /*NOACTIVATE*/ | 0x00000080 /*TOOLWINDOW*/ | 0x00000008 /*TOPMOST*/; return cp; }
        }
    }

    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

    static void Toast(Dictionary<string, object> t, int pos, int count)
    {
        SetProcessDPIAware();
        Color bg = Hex(S(t, "bg")), accent = Hex(S(t, "accent")), fg = Hex(S(t, "fg")), dim = Hex(S(t, "dim"));
        var f = new ToastForm { FormBorderStyle = FormBorderStyle.None, StartPosition = FormStartPosition.Manual, ShowInTaskbar = false, TopMost = true, BackColor = bg, Text = "Mamumi-Os - Theme" };
        string mono = "Consolas";
        foreach (var fam in FontFamily.Families) if (fam.Name == "Cascadia Mono") { mono = fam.Name; break; }
        var title = new Font(mono, 13f, FontStyle.Bold);
        var sub = new Font(mono, 9.5f);
        string name = S(t, "name"), info = "Thème " + pos + "/" + count + "  ·  Win+Shift+T suivant";
        Size sz;
        using (var g = f.CreateGraphics())
        {
            var a = g.MeasureString(name, title); var b = g.MeasureString(info, sub);
            sz = new Size((int)Math.Max(a.Width, b.Width) + 56, (int)(a.Height + b.Height) + 36);
        }
        Rectangle scr = Screen.FromPoint(Cursor.Position).Bounds;
        f.Bounds = new Rectangle(scr.X + (scr.Width - sz.Width) / 2, scr.Y + 70, sz.Width, sz.Height);
        f.Paint += (s, e) =>
        {
            e.Graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            using (var p = new Pen(accent, 2)) e.Graphics.DrawRectangle(p, 1, 1, f.ClientSize.Width - 2, f.ClientSize.Height - 2);
            using (var p = new SolidBrush(accent)) e.Graphics.FillRectangle(p, 1, 1, 5, f.ClientSize.Height - 2);
            using (var br = new SolidBrush(fg)) e.Graphics.DrawString(name, title, br, 24, 12);
            using (var br = new SolidBrush(dim)) e.Graphics.DrawString(info, sub, br, 26, 16 + title.GetHeight(e.Graphics));
        };
        var timer = new System.Windows.Forms.Timer { Interval = 1600 };
        timer.Tick += (s, e) => { timer.Stop(); f.Close(); };
        f.Shown += (s, e) => timer.Start();
        Application.Run(f);
    }
}
