<# 
.SYNOPSIS
  Setup completo de WSL2 con Ubuntu 22.04 importado desde rootfs oficial.
  - Limpia instalaciones rotas y claves legacy
  - Habilita features de WSL2
  - Descarga rootfs oficial de Canonical
  - Importa distro como WSL2 en C:\WSL\Ubuntu-22.04
  - Crea usuario 'jorsat' y lo deja como predeterminado

.Requisitos
  Ejecutar en PowerShell como Administrador.
#>

[CmdletBinding()]
param(
  [string]$DistroName   = "Ubuntu-22.04",
  [string]$InstallDir   = "C:\WSL\Ubuntu-22.04",
  [string]$LinuxUser    = "jorsat",
  [string]$ChannelBase  = "https://cloud-images.ubuntu.com/wsl/jammy/current/"
)

# --- Config básica estricta y preferencia de errores
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info   { param([string]$m) Write-Host "[INFO]  $m" -ForegroundColor Cyan }
function Write-OK     { param([string]$m) Write-Host "[OK]    $m" -ForegroundColor Green }
function Write-Warn   { param([string]$m) Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Write-Err    { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# --- Verificar admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Err "Ejecutá este script como **Administrador**."
  exit 1
}

# --- Forzar TLS 1.2 para descargas
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# --- 0) Apagar WSL
try {
  wsl --shutdown | Out-Null
  Write-OK "WSL apagado."
} catch { Write-Warn "No se pudo ejecutar 'wsl --shutdown' (posible si WSL no estaba corriendo)." }

# --- 1) Habilitar features WSL y VM Platform (si faltan)
Write-Info "Habilitando características de Windows para WSL..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart  | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart            | Out-Null
Write-OK "Características habilitadas."

# --- 2) Asegurar WSL2
Write-Info "Actualizando WSL y configurando versión 2 como predeterminada..."
try { wsl --update   | Out-Null } catch { Write-Warn "wsl --update lanzó advertencia: $($_.Exception.Message)" }
wsl --set-default-version 2 | Out-Null
Write-OK "WSL2 listo como predeterminado."

# --- 3) Limpieza de distros rotas / registro legacy
Write-Info "Limpiando distros heredadas/rotas si existieran..."
$names = @("Ubuntu-22.04","Ubuntu 22.04 LTS","Ubuntu")
foreach ($n in $names) {
  try { wsl --unregister $n 2>$null | Out-Null; Write-OK "Unregistered '$n' (si existía)." }
  catch { Write-Warn "No se pudo 'unregister' $n (posiblemente no existía)." }
}

# Remover paquetes Ubuntu (Store) si quedaron
try {
  Get-AppxPackage *Ubuntu* -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
  Write-OK "Paquetes Ubuntu removidos (si había)."
} catch { Write-Warn "No se pudieron remover paquetes Ubuntu: $($_.Exception.Message)" }

# Limpiar claves HKCU Lxss que apunten a un usuario distinto al actual (evita rutas tipo C:\Users\jbisc\...)
$lxss = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
if (Test-Path $lxss) {
  $currentUser = $env:USERNAME
  Get-ChildItem $lxss | ForEach-Object {
    try {
      $p = Get-ItemProperty $_.PsPath -ErrorAction Stop
      if ($p.BasePath -and ($p.BasePath -match 'C:\\Users\\([^\\]+)\\')) {
        $userInPath = $Matches[1]
        if ($userInPath -ne $currentUser) {
          Remove-Item $_.PsPath -Recurse -Force
          Write-OK "Eliminada entrada legacy de Lxss que apuntaba a otro usuario: $userInPath"
        }
      }
    } catch { }
  }
} else {
  Write-Info "Sin claves Lxss en HKCU (perfecto)."
}

# --- 4) Preparar carpeta destino
Write-Info "Creando carpeta de instalación: $InstallDir"
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Write-OK "Carpeta lista."

# --- 5) Descargar rootfs oficial (detectando el nombre correcto)
$tempTar = Join-Path $env:TEMP "ubuntu-22.04-rootfs.tar.gz"
Write-Info "Descargando índice de Canonical: $ChannelBase"
try {
  $idx = Invoke-WebRequest -Uri $ChannelBase -UseBasicParsing
} catch {
  Write-Err "No se pudo acceder a $ChannelBase. Revisa tu conectividad/Firewall/Proxy."
  exit 1
}

# Buscar el primer .rootfs.tar.gz en el índice
$rel = ($idx.Links | Where-Object href -match 'rootfs\.tar\.gz$' | Select-Object -First 1).href
if (-not $rel) {
  Write-Err "No se encontró un archivo *.rootfs.tar.gz en el índice de $ChannelBase"
  exit 1
}

$rootfsUrl = if ($rel -match '^https?://') { $rel } else { "$ChannelBase$rel" }
Write-Info "Descargando rootfs: $rootfsUrl"
Invoke-WebRequest -Uri $rootfsUrl -OutFile $tempTar -UseBasicParsing
Write-OK "Rootfs descargado en: $tempTar"

# --- 6) Importar distro en WSL2
Write-Info "Importando distro '$DistroName' en WSL2..."
wsl --import $DistroName $InstallDir $tempTar --version 2
Write-OK "Distro importada."

# --- 7) Crear usuario Linux y dejarlo como predeterminado
Write-Info "Creando usuario '$LinuxUser' como predeterminado..."
wsl -d $DistroName -e bash -lc @"
set -e
if ! id -u "$LinuxUser" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$LinuxUser"
fi
usermod -aG sudo "$LinuxUser"
printf "[user]\ndefault=$LinuxUser\n" > /etc/wsl.conf
"@
Write-OK "Usuario '$LinuxUser' creado y seteado como default."

# --- 8) Reiniciar WSL y validar
wsl --shutdown
Start-Sleep -Seconds 2
Write-Info "Validando instalación..."
$ls = & wsl -l -v
$ls | ForEach-Object { Write-Host $_ }
if (-not ($ls -match $DistroName)) {
  Write-Err "No se encuentra '$DistroName' en la lista. Revisá pasos anteriores."
  exit 1
}

# --- 9) Establecer distro por defecto y abrirla una vez
Write-Info "Estableciendo '$DistroName' como predeterminada..."
wsl --set-default $DistroName | Out-Null

Write-OK "Todo listo. Abriendo la distro por primera vez..."
wsl -d $DistroName -e bash -lc "echo 'WSL listo con $DistroName (usuario: $LinuxUser)'; uname -a; cat /etc/os-release | head -n 2"

Write-OK "Instalación completa. Si Windows Terminal tenía un perfil viejo, ajustá Settings → Profiles para usar '$DistroName' como default."
