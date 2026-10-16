// Ouvre un panneau natif de Windows via son raccourci clavier (lance par la barre Zebar).
//   flyout.exe quick     -> Parametres rapides (Win+A)
//   flyout.exe volume    -> Sortie audio / volume (Win+Ctrl+V)
//   flyout.exe calendar  -> Calendrier / notifications (Win+N), ou le ferme s'il est ouvert
// Compile avec : csc.exe /target:winexe /out:flyout.exe flyout.cs
using System;
using System.Text;
using System.Runtime.InteropServices;

static class Flyout
{
    [DllImport("user32.dll")]
    static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);

    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int value, int size);

    const byte LWIN = 0x5B, CTRL = 0x11;
    const uint KEYUP = 2;
    const int DWMWA_CLOAKED = 14;

    static void Press(params byte[] keys)
    {
        foreach (byte k in keys) keybd_event(k, 0, 0, UIntPtr.Zero);
        for (int i = keys.Length - 1; i >= 0; i--) keybd_event(keys[i], 0, KEYUP, UIntPtr.Zero);
    }

    // Le panneau notifications/calendrier est-il affiche a l'ecran ?
    static bool NotificationCenterShown()
    {
        bool shown = false;
        EnumWindows((h, l) =>
        {
            var cls = new StringBuilder(256); GetClassName(h, cls, 256);
            if (cls.ToString() != "Windows.UI.Core.CoreWindow") return true;
            var title = new StringBuilder(256); GetWindowText(h, title, 256);
            string t = title.ToString().ToLowerInvariant();
            if (!t.Contains("notification")) return true;
            int cloaked;
            DwmGetWindowAttribute(h, DWMWA_CLOAKED, out cloaked, sizeof(int));
            if (IsWindowVisible(h) && cloaked == 0) { shown = true; return false; }
            return true;
        }, IntPtr.Zero);
        return shown;
    }

    static void Main(string[] args)
    {
        string panel = args.Length > 0 ? args[0] : "quick";
        switch (panel)
        {
            case "noop":
                return;
            case "volume":
                Press(LWIN, CTRL, 0x56);   // Win + Ctrl + V
                return;
            case "calendar":
                // Le clic sur la barre lui fait perdre le focus : s'il est encore
                // affiche, c'est qu'il etait ouvert -> on le laisse se fermer.
                if (!NotificationCenterShown()) Press(LWIN, 0x4E);   // Win + N
                return;
            default:
                Press(LWIN, 0x41);         // Win + A
                return;
        }
    }
}
