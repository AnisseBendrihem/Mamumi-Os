// Panneau des raccourcis (Win + K), facon menu Omarchy, theme Tokyo Night.
//   - tape pour filtrer, fleches haut/bas pour naviguer, Entree pour executer
//   - souris : survol = selection, clic = executer
//   - Echap, clic ailleurs ou Win + K a nouveau = fermer
// Lit keys.txt (meme dossier) :
//   // commentaire
//   # Section
//   Touches | Action | glaze:<cmd GlazeWM>  ou  run:<programme> [args]  ou  send:<touches>
// Compile : csc /target:winexe /r:System.Windows.Forms.dll /r:System.Drawing.dll /out:mamumi-keys.exe keys.cs
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Text;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

class Item
{
    public string Section;     // non nul = en-tete de section
    public string Keys, Action, Command;
    public bool Runnable { get { return Section == null && !string.IsNullOrEmpty(Command); } }
}

class KeysForm : Form
{
    const string Title = "Mamumi-Os - Raccourcis";
    static readonly Color Bg = Color.FromArgb(0x1a, 0x1b, 0x26);
    static readonly Color BgSel = Color.FromArgb(0x29, 0x2e, 0x42);
    static readonly Color BgSearch = Color.FromArgb(0x16, 0x16, 0x1e);
    static readonly Color Border = Color.FromArgb(0x7a, 0xa2, 0xf7);
    static readonly Color Fg = Color.FromArgb(0xc0, 0xca, 0xf5);
    static readonly Color Dim = Color.FromArgb(0x56, 0x5f, 0x89);
    static readonly Color KeyCol = Color.FromArgb(0x7a, 0xa2, 0xf7);
    static readonly Color Head = Color.FromArgb(0xbb, 0x9a, 0xf7);
    static readonly Color Cyan = Color.FromArgb(0x7d, 0xcf, 0xff);

    readonly List<Item> all;
    List<Item> view = new List<Item>();
    string filter = "";
    int sel = -1, scroll = 0;
    readonly Font fKey, fText, fHead, fSearch, fHint;
    readonly int rowH, keyW, pad = 22, searchH, visibleRows;

    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);

    KeysForm(List<Item> items)
    {
        all = items;
        string mono = FontExists("Cascadia Mono") ? "Cascadia Mono" : "Consolas";
        fKey = new Font(mono, 11f, FontStyle.Bold);
        fText = new Font(mono, 11f);
        fHead = new Font(mono, 10f, FontStyle.Bold);
        fSearch = new Font(mono, 13f);
        fHint = new Font(mono, 9f);

        int keyMax = 0, actMax = 0;
        using (var g = CreateGraphics())
        {
            rowH = (int)(fText.GetHeight(g) * 1.75f);
            searchH = (int)(fSearch.GetHeight(g) * 2.1f);
            foreach (var it in all)
            {
                if (it.Section != null) continue;
                keyMax = Math.Max(keyMax, (int)g.MeasureString(it.Keys, fKey).Width);
                actMax = Math.Max(actMax, (int)g.MeasureString(it.Action, fText).Width);
            }
        }
        keyW = keyMax + 28;

        // Centre sur l'ecran de la souris, hauteur max 80 % de l'ecran.
        Rectangle screen = Screen.FromPoint(Cursor.Position).Bounds;
        int width = Math.Max(pad * 2 + keyW + actMax + 40, 560);
        int maxList = (int)(screen.Height * 0.8) - pad * 3 - searchH - rowH;
        visibleRows = Math.Max(5, Math.Min(all.Count, maxList / rowH));
        int height = pad * 3 + searchH + visibleRows * rowH + rowH;

        Text = Title;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        Bounds = new Rectangle(screen.X + (screen.Width - width) / 2, screen.Y + (screen.Height - height) / 2, width, height);
        ShowInTaskbar = false;
        TopMost = true;
        BackColor = Bg;
        DoubleBuffered = true;
        KeyPreview = true;

        ApplyFilter();
        KeyDown += OnKey;
        KeyPress += OnChar;
        MouseMove += (s, e) => { int i = RowAt(e.Location); if (i >= 0 && view[i].Runnable && i != sel) { sel = i; Invalidate(); } };
        MouseClick += (s, e) => { int i = RowAt(e.Location); if (i >= 0 && view[i].Runnable) { sel = i; Execute(); } };
        MouseWheel += (s, e) => { scroll = Math.Max(0, Math.Min(Math.Max(0, view.Count - visibleRows), scroll - Math.Sign(e.Delta) * 3)); Invalidate(); };
        Deactivate += (s, e) => Close();
        Shown += (s, e) => ForceForeground();
    }

    // Prend vraiment le focus clavier (Windows le refuse parfois aux nouvelles fenetres).
    void ForceForeground()
    {
        uint fg = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero), me = GetCurrentThreadId();
        if (fg != me) AttachThreadInput(me, fg, true);
        BringWindowToTop(Handle); SetForegroundWindow(Handle); Activate();
        if (fg != me) AttachThreadInput(me, fg, false);
    }

    static string Fold(string s)
    {
        // minuscules sans accents, pour filtrer "ecran" = "Écran"
        var n = s.ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (var c in n) if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark) sb.Append(c);
        return sb.ToString();
    }

    void ApplyFilter()
    {
        view = new List<Item>();
        string f = Fold(filter);
        Item pendingHead = null;
        foreach (var it in all)
        {
            if (it.Section != null) { pendingHead = it; continue; }
            if (f.Length > 0 && !Fold(it.Keys + " " + it.Action).Contains(f)) continue;
            if (pendingHead != null && f.Length == 0) { view.Add(pendingHead); }
            pendingHead = null;
            view.Add(it);
        }
        scroll = 0;
        sel = view.FindIndex(x => x.Runnable);
        Invalidate();
    }

    void MoveSel(int dir)
    {
        if (view.Count == 0) return;
        int i = sel;
        for (int n = 0; n < view.Count; n++)
        {
            i = (i + dir + view.Count) % view.Count;
            if (view[i].Runnable) { sel = i; break; }
        }
        if (sel < scroll) scroll = sel;
        if (sel >= scroll + visibleRows) scroll = sel - visibleRows + 1;
        if (sel >= 0 && sel <= 1) scroll = 0;
        Invalidate();
    }

    void OnKey(object s, KeyEventArgs e)
    {
        switch (e.KeyCode)
        {
            case System.Windows.Forms.Keys.Escape:
                if (filter.Length > 0) { filter = ""; ApplyFilter(); } else Close();
                e.Handled = true; break;
            case System.Windows.Forms.Keys.Down: MoveSel(1); e.Handled = true; break;
            case System.Windows.Forms.Keys.Up: MoveSel(-1); e.Handled = true; break;
            case System.Windows.Forms.Keys.Tab: MoveSel(e.Shift ? -1 : 1); e.Handled = true; break;
            case System.Windows.Forms.Keys.Enter: Execute(); e.Handled = true; break;
            case System.Windows.Forms.Keys.Back:
                if (filter.Length > 0) { filter = filter.Substring(0, filter.Length - 1); ApplyFilter(); }
                e.Handled = true; break;
        }
    }

    void OnChar(object s, KeyPressEventArgs e)
    {
        if (char.IsControl(e.KeyChar)) return;
        filter += e.KeyChar; ApplyFilter(); e.Handled = true;
    }

    int RowAt(Point p)
    {
        int top = pad * 2 + searchH;
        if (p.Y < top) return -1;
        int i = scroll + (p.Y - top) / rowH;
        return (i >= 0 && i < view.Count && i < scroll + visibleRows) ? i : -1;
    }

    // --- Execution de l'action selectionnee ---
    void Execute()
    {
        if (sel < 0 || sel >= view.Count || !view[sel].Runnable) return;
        string cmd = view[sel].Command;
        Hide();
        Close();
        // Laisse le focus revenir a la fenetre precedente avant d'agir dessus.
        Thread.Sleep(180);
        try
        {
            if (cmd.StartsWith("glaze:")) RunGlaze(cmd.Substring(6).Trim());
            else if (cmd.StartsWith("run:")) RunProgram(Environment.ExpandEnvironmentVariables(cmd.Substring(4).Trim()));
            else if (cmd.StartsWith("send:")) SendKeysCombo(cmd.Substring(5).Trim());
        }
        catch { }
    }

    static void RunGlaze(string args)
    {
        string cli = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"glzr.io\GlazeWM\cli\glazewm.exe");
        var psi = new ProcessStartInfo(cli, "command " + args) { CreateNoWindow = true, UseShellExecute = false };
        using (var p = Process.Start(psi)) p.WaitForExit(3000);
    }

    static void RunProgram(string line)
    {
        // "C:\chemin avec espaces\app.exe arg1 arg2" -> programme + arguments
        string prog = line, args = "";
        int exe = line.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
        if (exe > 0 && exe + 4 < line.Length) { prog = line.Substring(0, exe + 4); args = line.Substring(exe + 4).Trim(); }
        Process.Start(new ProcessStartInfo(prog, args) { UseShellExecute = true });
    }

    void SendKeysCombo(string combo)
    {
        var vks = new List<byte>();
        foreach (var part in combo.ToUpperInvariant().Split('+'))
        {
            string k = part.Trim();
            switch (k)
            {
                case "LWIN": case "WIN": vks.Add(0x5B); break;
                case "SHIFT": vks.Add(0x10); break;
                case "CTRL": vks.Add(0x11); break;
                case "ALT": vks.Add(0x12); break;
                case "TAB": vks.Add(0x09); break;
                case "ENTER": vks.Add(0x0D); break;
                case "SPACE": vks.Add(0x20); break;
                case "ESC": vks.Add(0x1B); break;
                default: if (k.Length == 1) vks.Add((byte)k[0]); break;
            }
        }
        foreach (var v in vks) keybd_event(v, 0, 0, UIntPtr.Zero);
        for (int i = vks.Count - 1; i >= 0; i--) keybd_event(vks[i], 0, 2, UIntPtr.Zero);
    }

    // --- Dessin ---
    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        using (var pen = new Pen(Border, 2)) g.DrawRectangle(pen, 1, 1, ClientSize.Width - 2, ClientSize.Height - 2);

        // Barre de recherche
        var sr = new Rectangle(pad, pad, ClientSize.Width - pad * 2, searchH);
        using (var b = new SolidBrush(BgSearch)) g.FillRectangle(b, sr);
        using (var p = new Pen(Color.FromArgb(0x41, 0x48, 0x68))) g.DrawRectangle(p, sr);
        float ty = sr.Y + (searchH - fSearch.GetHeight(g)) / 2;
        if (filter.Length == 0)
            using (var b = new SolidBrush(Dim)) g.DrawString("  Rechercher un raccourci...", fSearch, b, sr.X + 6, ty);
        else
            using (var b = new SolidBrush(Fg)) g.DrawString("  " + filter + "_", fSearch, b, sr.X + 6, ty);
        using (var b = new SolidBrush(KeyCol)) g.DrawString(">", fSearch, b, sr.X + 6, ty);

        // Liste
        int top = pad * 2 + searchH;
        for (int r = 0; r < visibleRows && scroll + r < view.Count; r++)
        {
            int i = scroll + r;
            var it = view[i];
            int y = top + r * rowH;
            float textY = y + (rowH - fText.GetHeight(g)) / 2;
            if (it.Section != null)
            {
                using (var b = new SolidBrush(Head)) g.DrawString(it.Section.ToUpperInvariant(), fHead, b, pad + 4, textY + 2);
                continue;
            }
            if (i == sel)
            {
                using (var b = new SolidBrush(BgSel)) g.FillRectangle(b, pad, y, ClientSize.Width - pad * 2, rowH);
                using (var b = new SolidBrush(Border)) g.FillRectangle(b, pad, y, 3, rowH);
            }
            Color kc = it.Runnable ? KeyCol : Dim, ac = it.Runnable ? Fg : Dim;
            if (i == sel) { kc = Cyan; }
            using (var b = new SolidBrush(kc)) g.DrawString(it.Keys, fKey, b, pad + 14, textY);
            using (var b = new SolidBrush(ac)) g.DrawString(it.Action, fText, b, pad + 14 + keyW, textY);
        }
        if (view.Count == 0)
            using (var b = new SolidBrush(Dim)) g.DrawString("Aucun raccourci ne correspond", fText, b, pad + 14, top + 4);

        // Aide en bas
        using (var b = new SolidBrush(Dim))
            g.DrawString("↑↓ naviguer   Entrée exécuter   Échap fermer   (gris = aide seulement)", fHint, b, pad, ClientSize.Height - pad - fHint.GetHeight(g));
    }

    static bool FontExists(string name)
    {
        using (var fonts = new InstalledFontCollection())
            foreach (var f in fonts.Families) if (f.Name == name) return true;
        return false;
    }

    [STAThread]
    static void Main()
    {
        bool isNew;
        using (var mutex = new Mutex(true, "MamumiOsKeys", out isNew))
        {
            if (!isNew)
            {
                var h = FindWindow(null, Title);
                if (h != IntPtr.Zero) PostMessage(h, 0x0010 /* WM_CLOSE */, IntPtr.Zero, IntPtr.Zero);
                return;
            }
            SetProcessDPIAware();
            Application.EnableVisualStyles();

            string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "keys.txt");
            var items = new List<Item>();
            if (File.Exists(path))
            {
                foreach (var raw in File.ReadAllLines(path, Encoding.UTF8))
                {
                    var t = raw.Trim();
                    if (t.Length == 0 || t.StartsWith("//")) continue;
                    if (t.StartsWith("#")) { items.Add(new Item { Section = t.TrimStart('#').Trim() }); continue; }
                    var parts = t.Split('|');
                    if (parts.Length < 2) continue;
                    items.Add(new Item
                    {
                        Keys = parts[0].Trim(),
                        Action = parts[1].Trim(),
                        Command = parts.Length > 2 ? parts[2].Trim() : null
                    });
                }
            }
            if (items.Count == 0) items.Add(new Item { Keys = "keys.txt introuvable", Action = path });
            Application.Run(new KeysForm(items));
        }
    }
}
