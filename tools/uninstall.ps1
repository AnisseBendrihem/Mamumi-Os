# ============================================================
#  Mamumi-Os - desinstallation
#  Arrete et desinstalle GlazeWM / Zebar, rend la barre Windows,
#  remet le bureau et le terminal comme avant. Les reglages vie privee / pubs
#  restent (pour TOUT annuler : point de restauration "Avant Mamumi-Os").
# ============================================================
$a = Read-Host 'Desinstaller Mamumi-Os ? (o/n)'
if ($a -notmatch '^[oOyY]') { return }

$Tools = Join-Path $env:ProgramData 'Mamumi-Os'

# 1. Arret de GlazeWM, de la barre et du masquage de la barre Windows
Get-Process taskbar-guard, glazewm, zebar, mamumi-keys -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name GlazeWM -ErrorAction SilentlyContinue

# 2. Barre Windows normale, icones du bureau, menu Demarrer a gauche
$sr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
try { $v = (Get-ItemProperty $sr).Settings; $v[8] = 2; Set-ItemProperty $sr Settings $v } catch {}
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $adv HideIcons 0 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence 0 -Type DWord

# 3. Ancienne config du terminal et de GlazeWM
foreach ($wt in "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json") {
    if (Test-Path "$wt.avant-mamumi") { Copy-Item "$wt.avant-mamumi" $wt -Force; Write-Host 'Terminal restaure' }
}
$glzr = Join-Path $env:USERPROFILE '.glzr'
if (Test-Path "$glzr.avant-mamumi") { Remove-Item $glzr -Recurse -Force; Rename-Item "$glzr.avant-mamumi" $glzr }

# 4. Desinstallation des logiciels
foreach ($id in 'glzr-io.glazewm', 'glzr-io.zebar') {
    winget uninstall --id $id --exact --silent 2>$null | Out-Null
}

# 5. Raccourcis et outils
$sm = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
Remove-Item "$sm\Reparer Mamumi-Os.lnk", "$sm\Sauvegarder Mamumi-Os.lnk", "$sm\Desinstaller Mamumi-Os.lnk", "$sm\Raccourcis clavier.lnk" -ErrorAction SilentlyContinue
Start-Process powershell.exe -ArgumentList "-NoProfile -Command Start-Sleep 2; Remove-Item '$Tools' -Recurse -Force"

# 6. Relance de l'Explorateur (la barre Windows revient)
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 3
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }

Write-Host "`nMamumi-Os desinstalle. Redemarre le PC." -ForegroundColor Green
Write-Host "Pour annuler AUSSI les reglages vie privee / pubs / applis : Panneau de configuration >"
Write-Host "Recuperation > Restauration du systeme > point 'Avant Mamumi-Os'."
Read-Host 'Entree pour fermer' | Out-Null
