# ============================================================
#  Mamumi-Os - Sauvegarder mon setup
#  Copie la config (GlazeWM, barre, terminal, raccourcis) dans :
#    D:\Sauvegarde_Mamumi-Os            si un disque D: existe
#    %USERPROFILE%\Sauvegarde_Mamumi-Os sinon
#  "derniere" = copie utilisee par "Reparer Mamumi-Os". Garde les 5 dernieres versions.
# ============================================================
$d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:' AND DriveType=3" -ErrorAction SilentlyContinue
$root = if ($d) { 'D:\Sauvegarde_Mamumi-Os' } else { Join-Path $env:USERPROFILE 'Sauvegarde_Mamumi-Os' }
$dst = Join-Path $root (Get-Date -Format 'yyyy-MM-dd_HHmm')
New-Item -ItemType Directory -Force "$dst\glzr", "$dst\terminal" | Out-Null

robocopy "$env:USERPROFILE\.glzr" "$dst\glzr" /E /XF *.log /NFL /NDL /NJH /NJS /NP | Out-Null
foreach ($wt in "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json") {
    if (Test-Path $wt) { Copy-Item $wt "$dst\terminal\settings.json" -Force; break }
}
Copy-Item "$env:ProgramData\Mamumi-Os\keys.txt" "$dst\keys.txt" -Force -ErrorAction SilentlyContinue
Copy-Item "$env:ProgramData\Mamumi-Os\theme-current.txt" "$dst\theme-current.txt" -Force -ErrorAction SilentlyContinue

$latest = Join-Path $root 'derniere'
if (Test-Path $latest) { Remove-Item $latest -Recurse -Force }
robocopy $dst $latest /E /NFL /NDL /NJH /NJS /NP | Out-Null

Get-ChildItem $root -Directory | Where-Object Name -match '^\d{4}-\d{2}-\d{2}_\d{4}$' |
    Sort-Object Name -Descending | Select-Object -Skip 5 | Remove-Item -Recurse -Force

Write-Host "   Sauvegarde : $((Get-ChildItem $dst -Recurse -File).Count) fichiers dans $dst" -ForegroundColor Green
