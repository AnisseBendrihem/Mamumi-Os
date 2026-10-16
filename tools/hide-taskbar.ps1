# Cache la barre des taches Windows (tous les ecrans) tant que GlazeWM tourne.
# Lance par GlazeWM au demarrage ; "-Show" la fait reapparaitre (a la fermeture de GlazeWM).
param([switch]$Show)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TaskbarCtl {
    [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
}
"@

function Set-Taskbars([bool]$visible) {
    foreach ($cls in 'Shell_TrayWnd', 'Shell_SecondaryTrayWnd') {
        $h = [IntPtr]::Zero
        while (($h = [TaskbarCtl]::FindWindowEx([IntPtr]::Zero, $h, $cls, $null)) -ne [IntPtr]::Zero) {
            if ([TaskbarCtl]::IsWindowVisible($h) -ne $visible) {
                [TaskbarCtl]::ShowWindow($h, $(if ($visible) { 5 } else { 0 })) | Out-Null
            }
        }
    }
}

if ($Show) {
    # Arrete la boucle de masquage puis reaffiche les barres.
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -match 'hide-taskbar\.ps1' -and $_.CommandLine -notmatch '-Show' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Set-Taskbars $true
    return
}

# Une seule instance de la boucle.
$others = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'hide-taskbar\.ps1' -and $_.CommandLine -notmatch '-Show' -and $_.ProcessId -ne $PID }
if ($others) { return }

# flyout.ps1 cree "taskbar.pause" quand un panneau Windows est ouvert :
# on laisse alors la barre visible (max 3 min, au cas ou le fichier resterait).
$pauseFlag = Join-Path $PSScriptRoot 'taskbar.pause'
$zebarExe = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
$tick = 0
$noGlaze = 0
while ($true) {
    $paused = (Test-Path $pauseFlag) -and ((Get-Date) - (Get-Item $pauseFlag).LastWriteTime).TotalMinutes -lt 3
    if (-not $paused) { Set-Taskbars $false }

    # Toutes les ~2 s : verifications de securite.
    $tick++
    if ($tick % 7 -eq 0) {
        if (Get-Process glazewm -ErrorAction SilentlyContinue) {
            $noGlaze = 0
            # La barre Zebar a plante -> on la relance.
            if (-not (Get-Process zebar -ErrorAction SilentlyContinue)) { Start-Process $zebarExe }
        }
        else {
            # GlazeWM ne tourne plus (plantage ou fermeture) : apres ~6 s,
            # on rend la barre Windows et on s'arrete, pour ne jamais rester sans barre.
            $noGlaze++
            if ($noGlaze -ge 3) { Set-Taskbars $true; break }
        }
    }
    Start-Sleep -Milliseconds 300
}
