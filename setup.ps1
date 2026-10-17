# ============================================================
#  Mamumi-Os - installation (Windows 10/11, Windows PowerShell 5.1)
#
#  setup.ps1            installation complete
#  setup.ps1 -Repair    reparation apres une mise a jour Windows :
#                       reapplique les reglages, restaure les fichiers manquants,
#                       ne reinstalle rien et n'ecrase pas tes modifications.
#  setup.ps1 -Yes       pas de question de confirmation
# ============================================================
param([switch]$Repair, [switch]$Yes)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$RepoDir = $PSScriptRoot
$Tools = Join-Path $env:ProgramData 'Mamumi-Os'          # chemin sans espace (requis par GlazeWM)
$Glzr = Join-Path $env:USERPROFILE '.glzr'
$GlazeExe = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\glazewm.exe'
$ZebarExe = Join-Path $env:ProgramFiles 'glzr.io\Zebar\zebar.exe'

function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "   [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "   [!]  $m" -ForegroundColor Yellow }
function Set-Reg($path, $name, $value, $type = 'DWord') {
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -ErrorAction Stop
    } catch { Warn "$path\$name : $($_.Exception.Message)" }
}
function Abgr([string]$hex) {
    $r = [Convert]::ToByte($hex.Substring(1, 2), 16); $g = [Convert]::ToByte($hex.Substring(3, 2), 16); $b = [Convert]::ToByte($hex.Substring(5, 2), 16)
    [BitConverter]::ToInt32([byte[]]($r, $g, $b, 0xFF), 0)
}
function Get-BackupDir {
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:' AND DriveType=3" -ErrorAction SilentlyContinue
    if ($d) { 'D:\Sauvegarde_Mamumi-Os' } else { Join-Path $env:USERPROFILE 'Sauvegarde_Mamumi-Os' }
}
function Save-Json($obj, $path) {
    # UTF-8 sans BOM (Windows Terminal le prefere).
    [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
}
function New-Shortcut($path, $target, $arguments = '', $icon = '') {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($path)
    $s.TargetPath = $target
    if ($arguments) { $s.Arguments = $arguments }
    if ($icon) { $s.IconLocation = $icon }
    $s.Save()
}

Clear-Host
Write-Host @'

   M A M U M I - O S
   Windows facon Omarchy - theme Tokyo Night
'@ -ForegroundColor Magenta

if (-not $Repair -and -not $Yes) {
    Write-Host @"
 Ce script va :
   - installer GlazeWM (+ sa barre Zebar) via winget : le seul logiciel ajoute
   - appliquer le theme Tokyo Night (Windows, menu Demarrer, terminal)
   - ranger les fenetres en spirale facon Hyprland, panneau des raccourcis (Win + K)
   - cacher la barre des taches Windows et la remplacer par une barre en haut
   - configurer les raccourcis clavier facon Omarchy (touche Windows)
   - supprimer les pubs, suggestions, Copilot, Recall, Widgets, la telemetrie
   - desinstaller des applis Microsoft (Outlook new, Teams, OneNote, Lien mobile,
     Clipchamp, Actualites, Meteo, Cartes...)
   - couper le lancement auto de launchers (Epic, GOG, Riot client, Teams, OneDrive...)
   - optimiser le jeu (Game DVR coupe, Mode Jeu, planification GPU)
   - nettoyer les fichiers temporaires
 Un point de restauration Windows est cree avant (une fenetre admin va s'ouvrir).

"@
    $a = Read-Host ' Continuer ? (o/n)'
    if ($a -notmatch '^[oOyY]') { Write-Host ' Annule.'; return }
}

# ------------------------------------------------------------
Step "1. Dossier des outils ($Tools)"
New-Item -ItemType Directory -Force $Tools | Out-Null
$repoCopy = Join-Path $Tools 'repo'
if ((Resolve-Path $RepoDir).Path -ne $repoCopy) {
    if (Test-Path $repoCopy) { Remove-Item $repoCopy -Recurse -Force }
    Copy-Item $RepoDir $repoCopy -Recurse -Force
}
Ok "Depot copie dans $repoCopy"

# ------------------------------------------------------------
Step "2. Partie administrateur (point de restauration, strategies, telemetrie)"
$adminArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$repoCopy\admin.ps1`""
if ($Repair) { $adminArgs += ' -Repair' }
try {
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList $adminArgs -ErrorAction Stop
    Get-Content (Join-Path $Tools 'admin.log') -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\[' } | ForEach-Object { Write-Host "   $_" }
} catch { Warn "Partie admin refusee ou impossible : $_" }

# ------------------------------------------------------------
if (-not $Repair) {
    Step "3. Installation des logiciels (winget)"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Warn "winget introuvable. Installe 'App Installer' depuis le Microsoft Store puis relance."
        return
    }
    Write-Host "   Installation de GlazeWM (inclut la barre Zebar)..."
    winget install --id glzr-io.glazewm --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
    if (Test-Path $GlazeExe) { Ok 'GlazeWM installe' } else { Warn 'GlazeWM introuvable apres installation' }
    if (Test-Path $ZebarExe) { Ok 'Zebar installe' } else { Warn 'Zebar introuvable apres installation' }
}

# ------------------------------------------------------------
Step "4. Outils Mamumi-Os (barre cachee, spirale, panneaux Windows, raccourcis)"
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
# Garde : cache la barre Windows, relance la barre si elle plante, spirale facon Hyprland.
Get-Process taskbar-guard -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
if (-not (Test-Path "$Tools\taskbar-guard.exe") -or -not $Repair) {
    & $csc /nologo /target:winexe /optimize+ /out:"$Tools\taskbar-guard.exe" "$repoCopy\tools\taskbar-guard.cs" | Out-Null
}
if (Test-Path "$Tools\taskbar-guard.exe") { Ok 'taskbar-guard.exe compile (barre cachee + spirale)' } else { Warn 'Compilation de taskbar-guard.exe echouee' }
if (-not (Test-Path "$Tools\flyout.exe") -or -not $Repair) {
    & $csc /nologo /target:winexe /optimize+ /out:"$Tools\flyout.exe" "$repoCopy\tools\flyout.cs" | Out-Null
}
if (Test-Path "$Tools\flyout.exe") { Ok 'flyout.exe compile (ouvre les panneaux Windows depuis la barre)' } else { Warn 'Compilation de flyout.exe echouee' }

# Panneau des raccourcis (Win + K) : liste dans keys.txt, modifiable
Get-Process mamumi-keys -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
if (-not (Test-Path "$Tools\mamumi-keys.exe") -or -not $Repair) {
    & $csc /nologo /target:winexe /optimize+ /codepage:65001 /r:System.Windows.Forms.dll /r:System.Drawing.dll /out:"$Tools\mamumi-keys.exe" "$repoCopy\tools\keys.cs" | Out-Null
}
if (-not (Test-Path "$Tools\keys.txt")) {
    $fromBackup = Join-Path (Get-BackupDir) 'derniere\keys.txt'
    if ($Repair -and (Test-Path $fromBackup)) { Copy-Item $fromBackup "$Tools\keys.txt" -Force }
    else { Copy-Item "$repoCopy\config\keys.txt" "$Tools\keys.txt" -Force }
}
if (Test-Path "$Tools\mamumi-keys.exe") { Ok 'Panneau des raccourcis compile (Win + K)' } else { Warn 'Compilation du panneau des raccourcis echouee' }

# Navigateur par defaut -> raccourci Browser.lnk (Win + B)
$browser = $null
$progId = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction SilentlyContinue).ProgId
if ($progId) {
    $cmd = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
    if ($cmd -match '^"([^"]+\.exe)"') { $browser = $Matches[1] } elseif ($cmd -match '^(\S+\.exe)') { $browser = $Matches[1] }
}
if (-not $browser -or -not (Test-Path $browser)) { $browser = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" }
New-Shortcut "$Tools\Browser.lnk" $browser
Ok "Win + B ouvrira : $(Split-Path $browser -Leaf)"

# ------------------------------------------------------------
Step "5. Configuration GlazeWM + barre du haut"
$cfg = @(
    @{ Src = 'config\glazewm\config.yaml';          Dst = 'glazewm\config.yaml' },
    @{ Src = 'config\zebar\settings.json';          Dst = 'zebar\settings.json' },
    @{ Src = 'config\zebar\tokyo-night\zpack.json'; Dst = 'zebar\tokyo-night\zpack.json' },
    @{ Src = 'config\zebar\tokyo-night\bar.html';   Dst = 'zebar\tokyo-night\bar.html' },
    @{ Src = 'config\zebar\tokyo-night\styles.css'; Dst = 'zebar\tokyo-night\styles.css' }
)
$backupLatest = Join-Path (Get-BackupDir) 'derniere\glzr'
if (-not $Repair -and (Test-Path $Glzr) -and -not (Test-Path "$Glzr.avant-mamumi")) {
    Copy-Item $Glzr "$Glzr.avant-mamumi" -Recurse -Force
    Ok "Ancienne config sauvegardee dans $Glzr.avant-mamumi"
}
foreach ($c in $cfg) {
    $dst = Join-Path $Glzr $c.Dst
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    if ($Repair -and (Test-Path $dst)) { continue }               # reparation : on garde tes modifs
    $fromBackup = Join-Path $backupLatest $c.Dst
    if ($Repair -and (Test-Path $fromBackup)) { Copy-Item $fromBackup $dst -Force; Ok "Restaure depuis la sauvegarde : $($c.Dst)" }
    else { Copy-Item (Join-Path $repoCopy $c.Src) $dst -Force }
}
Ok 'Config GlazeWM et barre en place'

# ------------------------------------------------------------
Step "6. Bibliotheques de la barre (embarquees : aucune dependance Internet)"
$vendorDst = Join-Path $Glzr 'zebar\tokyo-night\vendor'
if (-not $Repair -or -not (Test-Path "$vendorDst\zebar@3.3.1\es2022\zebar.bundle.js")) {
    if (Test-Path $vendorDst) { Remove-Item $vendorDst -Recurse -Force }
    Copy-Item (Join-Path $repoCopy 'config\zebar\tokyo-night\vendor') $vendorDst -Recurse -Force
}
if (Test-Path "$vendorDst\zebar@3.3.1\es2022\zebar.bundle.js") { Ok 'Bibliotheques et icones de la barre en place' } else { Warn 'Bibliotheques de la barre manquantes' }

# ------------------------------------------------------------
Step "7. Windows Terminal (theme Tokyo Night)"
$wt = @("$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($wt) {
    try {
        $raw = Get-Content $wt -Raw
        $clean = [regex]::Replace($raw, '(?m)^\s*//.*$', '')                    # PowerShell 5 ne lit pas les commentaires
        $j = $clean | ConvertFrom-Json
        $t = Get-Content "$repoCopy\config\terminal\tokyo-night.json" -Raw | ConvertFrom-Json
        if (-not (Test-Path "$wt.avant-mamumi")) { Copy-Item $wt "$wt.avant-mamumi" -Force }
        $schemes = @($j.schemes | Where-Object { $_.name -ne 'Tokyo Night' }) + $t.scheme
        $j | Add-Member -NotePropertyName schemes -NotePropertyValue $schemes -Force
        $themes = @($j.themes | Where-Object { $_.name -ne 'Tokyo Night UI' }) + $t.theme
        $j | Add-Member -NotePropertyName themes -NotePropertyValue $themes -Force
        $j | Add-Member -NotePropertyName theme -NotePropertyValue 'Tokyo Night UI' -Force
        if (-not $j.profiles.defaults) { $j.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force }
        foreach ($p in $t.defaults.PSObject.Properties) { $j.profiles.defaults | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
        Save-Json $j $wt
        Ok 'Terminal en Tokyo Night (ancienne config : settings.json.avant-mamumi)'
    } catch { Warn "Config du terminal non modifiee : $_" }
} else { Warn "Windows Terminal pas encore lance sur ce PC : ouvre-le une fois puis lance 'Reparer Mamumi-Os'" }

# ------------------------------------------------------------
Step "8. Apparence Windows (sombre, accent Tokyo Night, menu Demarrer, barre)"
$pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-Reg $pers AppsUseLightTheme 0
Set-Reg $pers SystemUsesLightTheme 0
Set-Reg $pers EnableTransparency 1
Set-Reg $pers ColorPrevalence 1
$acc = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$pal = @('#e6d9ff', '#d6c2ff', '#c8adfb', '#bb9af7', '#2a2440', '#221e35', '#1a1b26', '#565f89')
$bytes = foreach ($c in $pal) { [Convert]::ToByte($c.Substring(1, 2), 16); [Convert]::ToByte($c.Substring(3, 2), 16); [Convert]::ToByte($c.Substring(5, 2), 16); 0 }
Set-Reg $acc AccentPalette ([byte[]]$bytes) Binary
Set-Reg $acc AccentColorMenu (Abgr '#221e35')
Set-Reg $acc StartColorMenu (Abgr '#221e35')
$dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
Set-Reg $dwm AccentColor (Abgr '#bb9af7')
Set-Reg $dwm ColorizationColor ([BitConverter]::ToInt32([byte[]](0xF7, 0x9A, 0xBB, 0xC4), 0))
Set-Reg $dwm ColorizationAfterglow ([BitConverter]::ToInt32([byte[]](0xF7, 0x9A, 0xBB, 0xC4), 0))
Set-Reg $dwm ColorPrevalence 0
Set-Reg 'HKCU:\Control Panel\Desktop' AutoColorization 0
$sr = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
try { $v = (Get-ItemProperty $sr).Settings; $v[8] = 3; Set-ItemProperty $sr Settings $v } catch { Warn "Masquage auto de la barre : $_" }
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
foreach ($p in @{ TaskbarAl = 1; ShowTaskViewButton = 0; HideIcons = 1; Start_Layout = 1; Start_TrackDocs = 0; Start_TrackProgs = 0; Start_IrisRecommendations = 0; Start_RecoPersonalizedSites = 0; Start_AccountNotifications = 0; ShowSyncProviderNotifications = 0; ShowCopilotButton = 0 }.GetEnumerator()) { Set-Reg $adv $p.Key $p.Value }
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start' ShowRecentList 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start' ShowFrequentList 0
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' HideRecommendedSection 1
Ok 'Apparence appliquee'

# ------------------------------------------------------------
Step "9. Pubs, suggestions, Bing, Copilot, vie privee"
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'ContentDeliveryAllowed', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled', 'RotatingLockScreenOverlayEnabled', 'SubscribedContentEnabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-310093Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled', 'SubscribedContent-353698Enabled') { Set-Reg $cdm $n 0 }
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' BingSearchEnabled 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' IsDynamicSearchBoxEnabled 0
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' DisableSearchBoxSuggestions 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' DisableAIDataAnalysis 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' DisableTailoredExperiencesWithDiagnosticData 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' TailoredExperiencesWithDiagnosticDataEnabled 0
Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' NumberOfSIUFInPeriod 0
Ok 'Pubs et suggestions coupees'

# ------------------------------------------------------------
Step "10. Jeu (Game DVR coupe, Mode Jeu)"
Set-Reg 'HKCU:\System\GameConfigStore' GameDVR_Enabled 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' AppCaptureEnabled 0
Set-Reg 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled 1
Set-Reg 'HKCU:\Software\Microsoft\GameBar' AllowAutoGameMode 1
Ok 'Reglages jeu appliques (Xbox / Game Pass gardes)'

# ------------------------------------------------------------
Step "11. Applis Microsoft inutiles"
$bloat = 'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.WindowsMaps', 'Microsoft.WindowsFeedbackHub', 'Microsoft.GetHelp', 'Microsoft.Microsoft3DViewer', 'Microsoft.MixedReality.Portal', 'Microsoft.People', 'microsoft.windowscommunicationsapps', 'Clipchamp.Clipchamp', 'Microsoft.PowerAutomateDesktop', 'Microsoft.Windows.DevHome', 'Microsoft.MicrosoftOfficeHub', 'MicrosoftWindows.Client.WebExperience', 'Microsoft.OutlookForWindows', 'MSTeams', 'Microsoft.Office.OneNote', 'Microsoft.YourPhone', 'MicrosoftWindows.CrossDevice', 'Microsoft.ZuneVideo', 'MicrosoftCorporationII.QuickAssist', 'Microsoft.Edge.GameAssist', 'Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.Todos', 'Microsoft.549981C3F5F10'
$n = 0
foreach ($a in $bloat) {
    $p = Get-AppxPackage -Name $a -ErrorAction SilentlyContinue
    if ($p) { try { $p | Remove-AppxPackage -ErrorAction Stop; $n++; Write-Host "   - $a" } catch { Warn "$a : $($_.Exception.Message.Split([Environment]::NewLine)[0])" } }
}
Ok "$n appli(s) supprimee(s) (Xbox, Photos, Calculatrice, Store... gardes)"

# ------------------------------------------------------------
Step "12. Lancement automatique au demarrage"
$approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$off = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
$runKey = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
$patterns = '^(EpicGamesLauncher|GogGalaxy|RiotClient|Teams|com\.squirrel\.Teams\.Teams|OneDrive|MicrosoftEdgeAutoLaunch_.*|Adobe Acrobat Synchronizer|Figma Agent|Spotify|EADM|Origin|Ubisoft.*)$'
if ($runKey) {
    foreach ($p in $runKey.PSObject.Properties) {
        if ($p.Name -match $patterns) { Set-Reg $approved $p.Name $off Binary; Write-Host "   - $($p.Name) ne demarre plus tout seul" }
    }
}
Set-Reg 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe\TeamsTfwStartupTask' State 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' GlazeWM "`"$GlazeExe`"" String
Ok 'GlazeWM demarre avec Windows'

# ------------------------------------------------------------
if (-not $Repair) {
    Step "13. Nettoyage des fichiers temporaires"
    $before = (Get-PSDrive C).Free
    Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($d in "$env:LOCALAPPDATA\CrashDumps", "$env:LOCALAPPDATA\Microsoft\Windows\INetCache") {
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Ok ("{0:N1} Go liberes" -f (((Get-PSDrive C).Free - $before) / 1GB))
}

# ------------------------------------------------------------
Step "14. Raccourcis 'Reparer' et 'Sauvegarder' (menu Demarrer)"
$sm = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
New-Shortcut "$sm\Reparer Mamumi-Os.lnk" $ps "-NoProfile -ExecutionPolicy Bypass -File `"$repoCopy\setup.ps1`" -Repair" "$env:SystemRoot\System32\shell32.dll,238"
New-Shortcut "$sm\Sauvegarder Mamumi-Os.lnk" $ps "-NoProfile -ExecutionPolicy Bypass -File `"$repoCopy\tools\backup.ps1`"" "$env:SystemRoot\System32\shell32.dll,258"
New-Shortcut "$sm\Raccourcis clavier.lnk" "$Tools\mamumi-keys.exe" '' "$env:SystemRoot\System32\main.cpl,0"
New-Shortcut "$sm\Desinstaller Mamumi-Os.lnk" $ps "-NoProfile -ExecutionPolicy Bypass -File `"$repoCopy\tools\uninstall.ps1`"" "$env:SystemRoot\System32\shell32.dll,131"
& $ps -NoProfile -ExecutionPolicy Bypass -File "$repoCopy\tools\backup.ps1"
Ok "Sauvegarde dans $(Get-BackupDir)"

# ------------------------------------------------------------
Step "15. Demarrage de GlazeWM et de la barre"
Get-Process taskbar-guard, glazewm, zebar -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 3
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
Start-Sleep 3
Start-Process explorer.exe -ArgumentList "`"$GlazeExe`""        # via l'Explorateur : sans droits admin
Start-Sleep 8
if (Get-Process glazewm -ErrorAction SilentlyContinue) { Ok 'GlazeWM lance' } else { Warn "GlazeWM ne s'est pas lance (redemarre le PC)" }
if (Get-Process zebar -ErrorAction SilentlyContinue) { Ok 'Barre du haut lancee' } else { Warn "La barre ne s'est pas lancee (redemarre le PC)" }

Write-Host @"

 =========================================================
  Termine ! Redemarre le PC pour tout finaliser.

  Win + K          TOUS les raccourcis (navigable, Entree = executer)
  Win + Entree     terminal         Win + Espace   menu Demarrer
  Win + B          navigateur       Win + W        fermer
  Win + fleches    changer de fenetre
  Win + 1..9       espaces de travail
  Win + Shift + P  pause (pour jouer)
  Win + Shift + Echap  quitter (la barre Windows revient)

  Probleme apres une mise a jour Windows :
  touche Win -> "Reparer Mamumi-Os"
 =========================================================
"@ -ForegroundColor Magenta
if (-not $Yes) { Read-Host ' Appuie sur Entree pour fermer' | Out-Null }
