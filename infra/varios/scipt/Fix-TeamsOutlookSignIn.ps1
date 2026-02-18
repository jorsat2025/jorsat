<#
.SYNOPSIS
  Reset de inicio de sesión para Microsoft Teams y Outlook (cache + WAM + credenciales).
  Útil cuando las credenciales son correctas pero Teams/Outlook no inicia sesión / queda en loop.

.NOTES
  - Ejecutar con el usuario afectado (no hace falta admin, salvo para algunos servicios).
  - Cierra Teams/Outlook antes de limpiar.
  - Opcional: limpia credenciales del Administrador de Credenciales relacionadas con Microsoft/Office/AAD/Teams.

.USAGE
  .\Fix-TeamsOutlookSignIn.ps1
  .\Fix-TeamsOutlookSignIn.ps1 -PurgeWindowsCredentials
  .\Fix-TeamsOutlookSignIn.ps1 -SkipWamReset
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [switch]$PurgeWindowsCredentials,
  [switch]$SkipWamReset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info($msg){ Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Ok($msg){   Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Fail($msg){ Write-Host "[FAIL]  $msg" -ForegroundColor Red }

function Stop-Processes {
  param([string[]]$Names)

  foreach ($n in $Names) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    if ($procs) {
      Write-Info "Cerrando proceso: $n"
      foreach ($p in $procs) {
        try { $p.CloseMainWindow() | Out-Null } catch {}
      }
      Start-Sleep -Milliseconds 800
      $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
      if ($procs) {
        Write-Info "Forzando cierre: $n"
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
      }
    }
  }
}

function Remove-PathSafe {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) { return }
  if (Test-Path $Path) {
    try {
      Write-Info "Borrando: $Path"
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      Write-Ok "Borrado: $Path"
    } catch {
      Write-Warn "No se pudo borrar $Path : $($_.Exception.Message)"
    }
  }
}

function Clear-TeamsCache {
  Write-Info "Limpiando caché de Teams (nuevo y clásico si existieran)..."

  $local = $env:LOCALAPPDATA
  $roam  = $env:APPDATA

  # Teams "clásico"
  $classic = @(
    Join-Path $roam  "Microsoft\Teams\application cache\cache",
    Join-Path $roam  "Microsoft\Teams\blob_storage",
    Join-Path $roam  "Microsoft\Teams\Cache",
    Join-Path $roam  "Microsoft\Teams\databases",
    Join-Path $roam  "Microsoft\Teams\GPUCache",
    Join-Path $roam  "Microsoft\Teams\IndexedDB",
    Join-Path $roam  "Microsoft\Teams\Local Storage",
    Join-Path $roam  "Microsoft\Teams\tmp"
  )

  # Nuevo Teams (MSIX / WebView2)
  $newTeams = @(
    Join-Path $local "Packages\MSTeams_8wekyb3d8bbwe\LocalCache",
    Join-Path $local "Packages\MSTeams_8wekyb3d8bbwe\LocalState",
    Join-Path $local "Packages\MSTeams_8wekyb3d8bbwe\TempState"
  )

  foreach ($p in $classic + $newTeams) { Remove-PathSafe -Path $p }
}

function Clear-OfficeOutlookCache {
  Write-Info "Limpiando cachés de Office/Outlook (Forms, WebCache, Identity)..."

  $local = $env:LOCALAPPDATA
  $roam  = $env:APPDATA

  # Outlook/Office WebCache (muy común en loops de auth)
  $paths = @(
    Join-Path $local "Microsoft\Office\16.0\Wef",
    Join-Path $local "Microsoft\Office\16.0\OfficeFileCache",
    Join-Path $local "Microsoft\Office\16.0\Identity",
    Join-Path $local "Microsoft\OneAuth",
    Join-Path $local "Microsoft\TokenBroker",
    Join-Path $local "Microsoft\Windows\WebCache",
    Join-Path $roam  "Microsoft\Forms",
    Join-Path $roam  "Microsoft\Outlook\RoamCache"
  )

  foreach ($p in $paths) { Remove-PathSafe -Path $p }
}

function Reset-WamTokens {
  if ($SkipWamReset) {
    Write-Warn "SkipWamReset activado: NO se resetean tokens WAM."
    return
  }

  Write-Info "Reseteando tokens WAM / AAD Broker (común para Teams/Office)..."
  $local = $env:LOCALAPPDATA

  $wamPaths = @(
    Join-Path $local "Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker",
    Join-Path $local "Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\LocalState"
  )

  foreach ($p in $wamPaths) { Remove-PathSafe -Path $p }
}

function Purge-WindowsCredentials {
  if (-not $PurgeWindowsCredentials) {
    Write-Info "PurgeWindowsCredentials NO activado: no se borran credenciales guardadas."
    return
  }

  Write-Warn "Vas a borrar credenciales del Administrador de Credenciales relacionadas con Microsoft/Office/Teams/AAD."
  Write-Warn "Esto puede pedirte re-login en apps Microsoft. Continúo..."

  try {
    $raw = cmdkey /list 2>$null
    $targets = @()

    foreach ($line in $raw) {
      if ($line -match "Target:\s*(.+)$") {
        $t = $Matches[1].Trim()
        # Filtramos lo típico que rompe auth: ADAL/WAM/Office/Teams/OneAuth/AzureAD
        if ($t -match "MicrosoftOffice|Office|Outlook|Teams|ADAL|OneAuth|TokenBroker|AzureAD|msteams|MSOID|login\.microsoftonline|https://.*microsoft") {
          $targets += $t
        }
      }
    }

    $targets = $targets | Sort-Object -Unique
    if (-not $targets) {
      Write-Info "No encontré targets relevantes para borrar en cmdkey."
      return
    }

    foreach ($t in $targets) {
      Write-Info "Borrando credencial: $t"
      cmdkey /delete:$t | Out-Null
    }
    Write-Ok "Credenciales (filtradas) borradas."
  } catch {
    Write-Warn "No se pudo listar/borrar credenciales con cmdkey: $($_.Exception.Message)"
  }
}

function Restart-ServicesSafe {
  Write-Info "Reiniciando servicios clave (si existen / si tenés permisos)..."

  $svcNames = @(
    "WebAccountManager",   # WAM
    "TokenBroker",         # puede no existir como servicio en algunas versiones
    "WpnService"           # push notifications, a veces impacta WAM/Office
  )

  foreach ($s in $svcNames) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) {
      try {
        Write-Info "Reiniciando servicio: $s"
        Restart-Service -Name $s -Force -ErrorAction Stop
        Write-Ok "Servicio reiniciado: $s"
      } catch {
        Write-Warn "No pude reiniciar $s (probable falta de permisos o no aplica): $($_.Exception.Message)"
      }
    }
  }
}

function Start-Apps {
  Write-Info "Abriendo Teams y Outlook..."

  # Teams nuevo (ms-teams) o clásico
  $startedTeams = $false
  try {
    Start-Process "ms-teams:" -ErrorAction Stop
    $startedTeams = $true
  } catch { }

  if (-not $startedTeams) {
    $classicTeams = Join-Path $env:LOCALAPPDATA "Microsoft\Teams\current\Teams.exe"
    if (Test-Path $classicTeams) {
      Start-Process $classicTeams | Out-Null
      $startedTeams = $true
    }
  }

  if ($startedTeams) { Write-Ok "Teams iniciado." } else { Write-Warn "No pude iniciar Teams automáticamente." }

  # Outlook
  try {
    $outlook = Join-Path $env:ProgramFiles "Microsoft Office\root\Office16\OUTLOOK.EXE"
    if (-not (Test-Path $outlook)) {
      $outlook = Join-Path ${env:ProgramFiles(x86)} "Microsoft Office\root\Office16\OUTLOOK.EXE"
    }
    if (Test-Path $outlook) {
      Start-Process $outlook | Out-Null
      Write-Ok "Outlook iniciado."
    } else {
      Write-Warn "No encontré OUTLOOK.EXE (Office16). Si usás Outlook (New) / Store, abrilo manual."
    }
  } catch {
    Write-Warn "No pude iniciar Outlook: $($_.Exception.Message)"
  }
}

# ---------------- MAIN ----------------
Write-Info "Fix Teams/Outlook sign-in - Inicio"
Write-Info "Cerrando apps..."

Stop-Processes -Names @(
  "Teams","ms-teams","OUTLOOK","EXCEL","WINWORD","POWERPNT",
  "OneDrive","Microsoft.AAD.BrokerPlugin","MicrosoftEdgeWebView2","msedge","WebViewHost"
)

Purge-WindowsCredentials
Clear-TeamsCache
Clear-OfficeOutlookCache
Reset-WamTokens
Restart-ServicesSafe

Write-Ok "Limpieza completada."
Write-Warn "Si seguís con loop de login, reiniciá Windows (recomendado) y probá de nuevo."

Start-Apps
Write-Ok "Listo."
