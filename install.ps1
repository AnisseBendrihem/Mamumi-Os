# ============================================================
#  Mamumi-Os - installation en une ligne :
#    irm https://raw.githubusercontent.com/AnisseBendrihem/Mamumi-Os/main/install.ps1 | iex
#  Telecharge le depot puis lance setup.ps1.
# ============================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$zip = Join-Path $env:TEMP 'Mamumi-Os.zip'
$dir = Join-Path $env:TEMP 'Mamumi-Os-src'
Write-Host 'Telechargement de Mamumi-Os...' -ForegroundColor Cyan
Invoke-WebRequest 'https://github.com/AnisseBendrihem/Mamumi-Os/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
Expand-Archive $zip $dir -Force
$src = Get-ChildItem $dir -Directory | Select-Object -First 1

& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src.FullName 'setup.ps1')
