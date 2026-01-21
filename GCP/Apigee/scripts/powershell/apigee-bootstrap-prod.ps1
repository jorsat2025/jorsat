param(
  [Parameter(Mandatory=$true)] [string] $ProjectId,              # Debe coincidir con el nombre de la ORG en hybrid
  [Parameter(Mandatory=$true)] [string] $AnalyticsRegion,        # Ej: "us-west1" (según Apigee locations)
  [Parameter(Mandatory=$true)] [string] $EnvGroupName,           # Ej: "eg-prod"
  [Parameter(Mandatory=$true)] [string[]] $Hostnames,            # Ej: @("api.tu-dominio.com")
  [string] $EnvironmentName = "prod"
)

$ErrorActionPreference = "Stop"

function Require-Cmd($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "No encuentro '$cmd' en PATH. Abrí 'Google Cloud SDK Shell' o inicializá cloud_env."
  }
}

Require-Cmd "gcloud"

Write-Host "==> Configurando proyecto: $ProjectId"
gcloud config set project $ProjectId | Out-Null

Write-Host "==> Habilitando APIs mínimas"
gcloud services enable apigee.googleapis.com apigeeconnect.googleapis.com | Out-Null

# (Opcional) Chequeo billing rápido
Write-Host "==> Chequeando billing (opcional)"
try {
  $billing = gcloud beta billing projects describe $ProjectId --format="value(billingEnabled)" 2>$null
  Write-Host "    billingEnabled=$billing"
} catch {
  Write-Host "    No se pudo chequear billing por CLI (permiso/beta). Continuo..."
}

Write-Host "==> Obteniendo access token"
$token = (gcloud auth print-access-token).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { throw "No pude obtener access token. Ejecutá: gcloud auth login" }

$headers = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json"
}

# ---------- 1) Crear ORG (HYBRID) ----------
# Doc: POST https://apigee.googleapis.com/v1/organizations?parent=projects/PROJECT_ID  (runtimeType=HYBRID) :contentReference[oaicite:3]{index=3}
$orgName = $ProjectId
$orgUrl  = "https://apigee.googleapis.com/v1/organizations?parent=projects/$ProjectId"

Write-Host "==> Verificando si la org existe: $orgName"
$orgExists = $false
try {
  Invoke-RestMethod -Method GET -Uri "https://apigee.googleapis.com/v1/organizations/$orgName" -Headers $headers | Out-Null
  $orgExists = $true
  Write-Host "    OK: org ya existe."
} catch {
  Write-Host "    Org no existe (o no accesible). Intento crear..."
}

if (-not $orgExists) {
  $orgBody = @{
    name          = $orgName
    runtimeType   = "HYBRID"
    analyticsRegion = $AnalyticsRegion
  } | ConvertTo-Json

  $resp = Invoke-RestMethod -Method POST -Uri $orgUrl -Headers $headers -Body $orgBody
  Write-Host "    Solicitud enviada. Operación: $($resp.name)"
  Write-Host "    Nota: la creación puede tardar varios minutos."
}

# ---------- 2) Crear Environment (prod) ----------
# Environments se crean a nivel org. (La guía hybrid indica crear environment antes del envgroup). :contentReference[oaicite:4]{index=4}
$envUrl = "https://apigee.googleapis.com/v1/organizations/$orgName/environments?name=$EnvironmentName"

Write-Host "==> Creando/verificando environment: $EnvironmentName"
try {
  Invoke-RestMethod -Method GET -Uri "https://apigee.googleapis.com/v1/organizations/$orgName/environments/$EnvironmentName" -Headers $headers | Out-Null
  Write-Host "    OK: environment ya existe."
} catch {
  $envBody = @{
    displayName = $EnvironmentName
    description = "Environment $EnvironmentName (bootstrap)"
  } | ConvertTo-Json

  Invoke-RestMethod -Method POST -Uri $envUrl -Headers $headers -Body $envBody | Out-Null
  Write-Host "    OK: environment creado."
}

# ---------- 3) Crear EnvGroup ----------
# Doc muestra el patrón: POST /envgroups?name=new-group-name :contentReference[oaicite:5]{index=5}
$egCreateUrl = "https://apigee.googleapis.com/v1/organizations/$orgName/envgroups?name=$EnvGroupName"

Write-Host "==> Creando/verificando envgroup: $EnvGroupName"
$eg = $null
try {
  $eg = Invoke-RestMethod -Method GET -Uri "https://apigee.googleapis.com/v1/organizations/$orgName/envgroups/$EnvGroupName" -Headers $headers
  Write-Host "    OK: envgroup ya existe."
} catch {
  Invoke-RestMethod -Method POST -Uri $egCreateUrl -Headers $headers | Out-Null
  $eg = Invoke-RestMethod -Method GET -Uri "https://apigee.googleapis.com/v1/organizations/$orgName/envgroups/$EnvGroupName" -Headers $headers
  Write-Host "    OK: envgroup creado."
}

# ---------- 4) Actualizar hostnames + asociar environment al envgroup (PATCH) ----------
# Estrategia: leer envgroup actual y "mergear" hostnames + environments.
Write-Host "==> Actualizando envgroup (hostnames + environments adjuntos)"
$desiredHostnames = @($Hostnames | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() })

# Normalizar arrays existentes
$existingHostnames = @()
if ($eg.hostnames) { $existingHostnames = @($eg.hostnames) }

$existingEnvs = @()
if ($eg.environments) { $existingEnvs = @($eg.environments) }

$envResourceName = "organizations/$orgName/environments/$EnvironmentName"

# Merge sin duplicados
$mergedHostnames = @($existingHostnames + $desiredHostnames | Select-Object -Unique)
$mergedEnvs = @($existingEnvs + @($envResourceName) | Select-Object -Unique)

$patchBody = @{
  hostnames    = $mergedHostnames
  environments = $mergedEnvs
} | ConvertTo-Json -Depth 10

$patchUrl = "https://apigee.googleapis.com/v1/organizations/$orgName/envgroups/$EnvGroupName"
Invoke-RestMethod -Method PATCH -Uri $patchUrl -Headers $headers -Body $patchBody | Out-Null

Write-Host "==> Listo."
Write-Host "    Org: $orgName"
Write-Host "    Env: $EnvironmentName"
Write-Host "    EnvGroup: $EnvGroupName"
Write-Host "    Hostnames: $($mergedHostnames -join ', ')"
