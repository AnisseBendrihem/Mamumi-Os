# ============================================================
#  Mamumi-Os - partie administrateur (lancee par setup.ps1, une seule validation UAC)
#  Point de restauration, strategies systeme (Copilot, Recall, telemetrie, pubs),
#  services de telemetrie, planification GPU, nettoyage des fichiers temporaires systeme.
# ============================================================
param([switch]$Repair)

$log = Join-Path $env:ProgramData 'Mamumi-Os\admin.log'
"=== $(Get-Date) (Repair=$Repair) ===" | Out-File $log -Encoding utf8
function L($m) { $m | Out-File $log -Append -Encoding utf8 }
function Set-Reg($path, $name, $value, $type = 'DWord') {
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -ErrorAction Stop
    } catch { L "[ERR] $path\$name : $($_.Exception.Message)" }
}

# --- Point de restauration (premiere installation seulement) ---
if (-not $Repair) {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        Set-ItemProperty $k -Name SystemRestorePointCreationFrequency -Value 0 -Type DWord
        Checkpoint-Computer -Description 'Avant Mamumi-Os' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Remove-ItemProperty $k -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue
        L "[OK] Point de restauration 'Avant Mamumi-Os'"
    } catch { L "[ERR] Point de restauration : $_" }
}

# --- Copilot, Recall, pubs, telemetrie (strategies machine) ---
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' DisableAIDataAnalysis 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' AllowRecallEnablement 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' DisableWindowsConsumerFeatures 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' DisableConsumerAccountStateContent 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' AllowTelemetry 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' DoNotShowFeedbackNotifications 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' AllowDeviceNameInTelemetry 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' EnableActivityFeed 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' PublishUserActivities 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' UploadUserActivities 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' DisabledByGroupPolicy 1
foreach ($s in 'DiagTrack', 'dmwappushservice') {
    Stop-Service $s -Force -ErrorAction SilentlyContinue
    Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
    L "[OK] Service $s : $((Get-Service $s -ErrorAction SilentlyContinue).StartType)"
}

# --- Planification GPU acceleree (HAGS), active au prochain redemarrage ---
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' HwSchMode 2

# --- Nettoyage des fichiers temporaires systeme (premiere installation) ---
if (-not $Repair) {
    $before = (Get-PSDrive C).Free
    foreach ($d in "$env:windir\Temp", "$env:windir\SoftwareDistribution\Download") {
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    try { Clear-RecycleBin -Force -ErrorAction Stop } catch {}
    L ("[OK] Nettoyage systeme : {0:N1} Go liberes" -f (((Get-PSDrive C).Free - $before) / 1GB))
}
L "=== fin ==="
