[CmdletBinding()]
param(
  [switch]$Aggressive,      # borra credenciales cmdkey filtradas (más drástico)
  [switch]$SkipWamReset     # no borra WAM/AAD Broker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Ok($m){   Write-Host "[OK]   $m" -ForegroundColor Green }

function Stop-AppProcesses {
  param([string[]]$Names)

  foreach ($n in $Names) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    if ($procs) {
      Write-Info "Cerrando: $n"
      try { $procs | ForEach-Object { $_.CloseMainWindow() | Out-Null } } catch {}
      Start-Sleep -Milliseconds 800
      Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
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

function Clear-TeamsClassicCache {
  Write-Info "Limpiando caché de Teams CLÁSICO..."
  $roam = $env:APPDATA
  @(
    "$roam\Microsoft\Teams\application cache\cache",
    "$roam\Microsoft\Teams\blob_storage",
    "$roam\Microsoft\Teams\Cache",
    "$roam\Microsoft\Teams\databases",
    "$roam\Microsoft\Teams\GPUCache",
    "$roam\Microsoft\Teams\IndexedDB",
    "$roam\Microsoft\Teams\Local Storage",
    "$roam\Microsoft\Teams\tmp"
  ) | ForEach-Object { Remove-PathSafe $_ }
}

function Clear-TeamsNewCache {
  Write-Info "Limpiando caché de Teams NUEVO (MSIX)..."
  $pkg = Join-Path $env:LOCALAPPDATA "Packages\MSTeams_8wekyb3d8bbwe"
  @(
    (Join-Path $pkg "LocalCache"),
    (Join-Path $pkg "LocalState"),
    (Join-Path $pkg "TempState")
  ) | ForEach-Object { Remove-PathSafe $_ }
}

function Clear-OfficeOutlookAuthCaches {
  Write-Info "Limpiando cachés Office/Outlook/Identity/OneAuth/WebCache..."
  $local = $env:LOCALAPPDATA
  $roam  = $env:APPDATA

  @(
    "$local\Microsoft\Office\16.0\Wef",
    "$local\Microsoft\Office\16.0\Identity",
    "$local\Microsoft\Office\16.0\OfficeFileCache",
    "$local\Microsoft\OneAuth",
    "$local\Microsoft\TokenBroker",
    "$local\Microsoft\Windows\WebCache",
    "$roam\Microsoft\Outlook\RoamCache",
    "$roam\Microsoft\Forms"
  ) | ForEach-Object { Remove-PathSafe $_ }
}

function Reset-WamTokens {
  if ($SkipWamReset) {
    Write-Warn "SkipWamReset activado: NO se resetean tokens WAM/AAD Broker."
    return
  }
  Write-Info "Reseteando WAM / AAD BrokerPlugin (tokens)..."
  $aad = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy"
  @(
    (Join-Path $aad "AC\TokenBroker"),
    (Join-Path $aad "LocalState")
  ) | ForEach-Object { Remove-PathSafe $_ }
}

function Remove-WindowsCredentialsFiltered {
  if (-not $Aggressive) {
    Write-Info "Modo normal: NO se borran credenciales guardadas (cmdkey)."
    return
  }

  Write-Warn "Modo AGRESIVO: borrando credenciales cmdkey relacionadas con Office/Teams/AAD..."
  try {
    $raw = cmdkey /list 2>$null
    $targets = @()

    foreach ($line in $raw) {
      if ($line -match "Target:\s*(.+)$") {
        $t = $Matches[1].Trim()
        if ($t -match "MicrosoftOffice|Office|Outlook|Teams|ADAL|OneAuth|TokenBroker|AzureAD|msteams|MSOID|login\.microsoftonline") {
          $targets += $t
        }
      }
    }

    $targets = $targets | Sort-Object -Unique
    if (-not $targets) {
      Write-Info "No encontré targets relevantes en cmdkey."
      return
    }

    foreach ($t in $targets) {
      Write-Info "Borrando credencial: $t"
      cmdkey /delete:$t | Out-Null
    }
    Write-Ok "Credenciales cmdkey (filtradas) borradas."
  } catch {
    Write-Warn "No se pudo listar/borrar credenciales con cmdkey: $($_.Exception.Message)"
  }
}

function Restart-CoreServices {
  Write-Info "Reiniciando servicios (si aplica / si hay permisos)..."
  foreach ($s in @("WebAccountManager","WpnService")) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc) {
      try {
        Restart-Service -Name $s -Force -ErrorAction Stop
        Write-Ok "Servicio reiniciado: $s"
      } catch {
        Write-Warn "No pude reiniciar ${s}: $($_.Exception.Message)"
      }
    }
  }
}

function Start-TeamsNew {
  try {
    Start-Process -FilePath "ms-teams:" -ErrorAction Stop
    Write-Ok "Teams NUEVO iniciado."
  } catch {
    Write-Warn "No pude abrir Teams nuevo con ms-teams: (¿no está instalado?)."
  }
}

function Start-TeamsClassic {
  $exe = Join-Path $env:LOCALAPPDATA "Microsoft\Teams\current\Teams.exe"
  if (Test-Path $exe) {
    Start-Process $exe | Out-Null
    Write-Ok "Teams CLÁSICO iniciado."
  } else {
    Write-Warn "No encontré Teams clásico en: $exe"
  }
}

function Start-OutlookClassic {
  $outlook = Join-Path $env:ProgramFiles "Microsoft Office\root\Office16\OUTLOOK.EXE"
  if (-not (Test-Path $outlook)) {
    $outlook = Join-Path ${env:ProgramFiles(x86)} "Microsoft Office\root\Office16\OUTLOOK.EXE"
  }

  if (Test-Path $outlook) {
    Start-Process $outlook | Out-Null
    Write-Ok "Outlook clásico iniciado."
  } else {
    Write-Warn "No encontré OUTLOOK.EXE (Office16). Si usás Outlook (New)/Store, abrilo manual."
  }
}

# ---------------- MAIN ----------------
Write-Info "Windows 11 - Fix login Teams (clásico+nuevo) + Outlook"
Write-Info "Cerrando apps (Teams/Outlook/Office/WebView)..."

Stop-AppProcesses -Names @(
  "Teams","ms-teams","OUTLOOK","EXCEL","WINWORD","POWERPNT",
  "OneDrive","Microsoft.AAD.BrokerPlugin","MicrosoftEdgeWebView2","msedge","WebViewHost"
)

Remove-WindowsCredentialsFiltered
Clear-TeamsClassicCache
Clear-TeamsNewCache
Clear-OfficeOutlookAuthCaches
Reset-WamTokens
Restart-CoreServices

Write-Ok "Limpieza finalizada."
Write-Warn "Recomendado: reiniciar Windows antes de reintentar login si estabas en loop."

Write-Info "Abriendo apps..."
Start-TeamsNew
Start-TeamsClassic
Start-OutlookClassic

Write-Ok "Listo."
