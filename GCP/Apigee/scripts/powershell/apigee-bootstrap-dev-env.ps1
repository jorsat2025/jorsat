<# 
Apigee hybrid bootstrap (Control Plane) - DEC - Windows PowerShell
Crea/actualiza recursos del control plane en GCP para el entorno dec:
- Habilita APIs (apigee + apigeeconnect)
- Crea ORG (runtimeType=HYBRID) si no existe y espera a que termine la operación
- Crea Environment (dec) si no existe
- Crea EnvGroup (eg-dec) si no existe
- Actualiza EnvGroup: hostnames + environments (PATCH con updateMask)
Notas:
- Para hybrid, el nombre de la ORG debe coincidir con el Project ID.
- Este script NO instala el runtime en OpenShift.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string]  $ProjectId,
  [Parameter(Mandatory=$true)] [string]  $AnalyticsRegion,      # ej: us-west1
  [string]  $EnvGroupName = "eg-dec",
  [Parameter(Mandatory=$true)] [string[]]$Hostnames,            # ej: @("api-dec.empresa.com")
  [string] $EnvironmentName = "dec",
  [int]    $OrgCreateTimeoutSeconds = 1200,  # 20 min
  [int]    $PollIntervalSeconds     = 10,
  [switch] $DryRun,
  [string] $LogFile = ""
)

$ErrorActionPreference = "Stop"

function Write-Log {
  param([string]$Message)
  $line = ("[0] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
  Write-Host $line
  if ($LogFile -and $LogFile.Trim() -ne "") {
    Add-Content -Path $LogFile -Value $line
  }
}

function Require-Cmd($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "No encuentro '$cmd' en PATH. Abrí 'Google Cloud SDK Shell' o inicializá cloud_env."
  }
}

function Get-AccessToken {
  $t = (gcloud auth print-access-token).Trim()
  if ([string]::IsNullOrWhiteSpace($t)) { throw "No pude obtener access token. Ejecutá: gcloud auth login" }
  return $t
}

function Invoke-ApigeeRest {
  param(
    [Parameter(Mandatory=$true)] [ValidateSet("GET","POST","PATCH","PUT","DELETE")] [string] $Method,
    [Parameter(Mandatory=$true)] [string] $Uri,
    [object] $Body = $null,
    [hashtable] $Headers
  )

  if ($DryRun) {
    Write-Log "DRYRUN: $Method $Uri"
    if ($Body -ne $null) { Write-Log ("DRYRUN BODY: " + ($Body | ConvertTo-Json -Depth 20)) }
    return $null
  }

  if ($Body -eq $null) {
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
  } else {
    $json = $Body | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $json
  }
}

Require-Cmd "gcloud"

if ($LogFile -and $LogFile.Trim() -ne "") {
  Write-Log "Logging habilitado: $LogFile"
}

Write-Log "==> Entorno: dec"
Write-Log "==> Proyecto: $ProjectId"
gcloud config set project $ProjectId | Out-Null

Write-Log "==> Habilitando APIs: apigee.googleapis.com, apigeeconnect.googleapis.com"
if (-not $DryRun) {
  gcloud services enable apigee.googleapis.com apigeeconnect.googleapis.com | Out-Null
} else {
  Write-Log "DRYRUN: gcloud services enable apigee.googleapis.com apigeeconnect.googleapis.com"
}

Write-Log "==> Obteniendo access token"
$token = Get-AccessToken
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

$orgName = $ProjectId
$base = "https://apigee.googleapis.com/v1"

Write-Log "==> Verificando ORG: $orgName"
$orgExists = $false
try {
  if (-not $DryRun) {
    Invoke-ApigeeRest -Method GET -Uri "$base/organizations/$orgName" -Headers $headers | Out-Null
    $orgExists = $true
    Write-Log "OK: ORG ya existe."
  } else {
    Write-Log "DRYRUN: asumimos ORG inexistente (para mostrar acciones)"
  }
} catch {
  Write-Log "ORG no existe (o no accesible). Se intentará crear."
}

if (-not $orgExists) {
  $createOrgUri = "$base/organizations?parent=projects/$ProjectId"
  $orgBody = @{ name = $orgName; runtimeType = "HYBRID"; analyticsRegion = $AnalyticsRegion }

  Write-Log "==> Creando ORG (HYBRID) en analyticsRegion=$AnalyticsRegion"
  $op = Invoke-ApigeeRest -Method POST -Uri $createOrgUri -Body $orgBody -Headers $headers

  if (-not $DryRun) {
    if (-not $op -or -not $op.name) { throw "No se recibió operation.name al crear la ORG." }
    $opName = $op.name
    $opUri  = "$base/$opName"
    Write-Log "Operación iniciada: $opName"

    $start = Get-Date
    while ($true) {
      $elapsed = (Get-Date) - $start
      if ($elapsed.TotalSeconds -gt $OrgCreateTimeoutSeconds) { throw "Timeout esperando creación de ORG ($opName)" }

      $opStatus = Invoke-ApigeeRest -Method GET -Uri $opUri -Headers $headers
      if ($opStatus.done -eq $true) {
        if ($opStatus.error) { throw ("Operación con error: " + $opStatus.error.message) }
        Write-Log "OK: ORG creada (DONE)."
        break
      }
      Start-Sleep -Seconds $PollIntervalSeconds
    }
  } else {
    Write-Log "DRYRUN: omitiendo polling de operación."
  }
}

Write-Log "==> Creando/verificando Environment: $EnvironmentName"
$envGetUri = "$base/organizations/$orgName/environments/$EnvironmentName"
$envCreateUri = "$base/organizations/$orgName/environments?name=$EnvironmentName"
$envExists = $false
if (-not $DryRun) {
  try { Invoke-ApigeeRest -Method GET -Uri $envGetUri -Headers $headers | Out-Null; $envExists = $true } catch { $envExists = $false }
}
if (-not $envExists) {
  $envBody = @{ displayName = $EnvironmentName; description = "Environment $EnvironmentName (bootstrap dec)" }
  Invoke-ApigeeRest -Method POST -Uri $envCreateUri -Body $envBody -Headers $headers | Out-Null
  Write-Log "OK: Environment creado (o solicitado)."
} else {
  Write-Log "OK: Environment ya existe."
}

Write-Log "==> Creando/verificando EnvGroup: $EnvGroupName"
$egGetUri = "$base/organizations/$orgName/envgroups/$EnvGroupName"
$egCreateUri = "$base/organizations/$orgName/envgroups?name=$EnvGroupName"
$eg = $null
if (-not $DryRun) {
  try { $eg = Invoke-ApigeeRest -Method GET -Uri $egGetUri -Headers $headers } catch { $eg = $null }
}
if (-not $eg) {
  Invoke-ApigeeRest -Method POST -Uri $egCreateUri -Headers $headers | Out-Null
  if (-not $DryRun) { $eg = Invoke-ApigeeRest -Method GET -Uri $egGetUri -Headers $headers } else { $eg = @{ hostnames=@(); environments=@() } }
  Write-Log "OK: EnvGroup creado (o solicitado)."
} else {
  Write-Log "OK: EnvGroup ya existe."
}

Write-Log "==> Actualizando EnvGroup: hostnames + environments"
$desiredHostnames = @($Hostnames | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() })
$existingHostnames = @(); if ($eg.hostnames) { $existingHostnames = @($eg.hostnames) }
$existingEnvs = @(); if ($eg.environments) { $existingEnvs = @($eg.environments) }

$envResourceName = "organizations/$orgName/environments/$EnvironmentName"
$mergedHostnames = @($existingHostnames + $desiredHostnames | Select-Object -Unique)
$mergedEnvs      = @($existingEnvs + @($envResourceName) | Select-Object -Unique)

$patchBody = @{ hostnames = $mergedHostnames; environments = $mergedEnvs }
$egPatchUri = "$egGetUri?updateMask=hostnames,environments"
Invoke-ApigeeRest -Method PATCH -Uri $egPatchUri -Body $patchBody -Headers $headers | Out-Null

Write-Log "==> Listo."
Write-Log "ORG       : $orgName"
Write-Log "ENV       : $EnvironmentName"
Write-Log "ENVGROUP  : $EnvGroupName"
Write-Log "HOSTNAMES : $($mergedHostnames -join ', ')"
