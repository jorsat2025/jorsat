template = r'''<# 
Apigee hybrid bootstrap (Control Plane) - {ENV_LABEL} - Windows PowerShell
Crea/actualiza recursos del control plane en GCP para el entorno {ENV_NAME}:
- Habilita APIs (apigee + apigeeconnect)
- Crea ORG (runtimeType=HYBRID) si no existe y espera a que termine la operación
- Crea Environment ({ENV_NAME}) si no existe
- Crea EnvGroup ({ENVGROUP_DEFAULT}) si no existe
- Actualiza EnvGroup: hostnames + environments (PATCH con updateMask)
Notas:
- Para hybrid, el nombre de la ORG debe coincidir con el Project ID.
- Este script NO instala el runtime en OpenShift.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string]  $ProjectId,
  [Parameter(Mandatory=$true)] [string]  $AnalyticsRegion,      # ej: us-west1
  [string]  $EnvGroupName = "{ENVGROUP_DEFAULT}",
  [Parameter(Mandatory=$true)] [string[]]$Hostnames,            # ej: @("api-{ENV_NAME}.empresa.com")
  [string] $EnvironmentName = "{ENV_NAME}",
  [int]    $OrgCreateTimeoutSeconds = 1200,  # 20 min
  [int]    $PollIntervalSeconds     = 10,
  [switch] $DryRun,
  [string] $LogFile = ""
)

$ErrorActionPreference = "Stop"

function Write-Log {{
  param([string]$Message)
  $line = ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
  Write-Host $line
  if ($LogFile -and $LogFile.Trim() -ne "") {{
    Add-Content -Path $LogFile -Value $line
  }}
}}

function Require-Cmd($cmd) {{
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {{
    throw "No encuentro '$cmd' en PATH. Abrí 'Google Cloud SDK Shell' o inicializá cloud_env."
  }}
}}

function Get-AccessToken {{
  $t = (gcloud auth print-access-token).Trim()
  if ([string]::IsNullOrWhiteSpace($t)) {{ throw "No pude obtener access token. Ejecutá: gcloud auth login" }}
  return $t
}}

function Invoke-ApigeeRest {{
  param(
    [Parameter(Mandatory=$true)] [ValidateSet("GET","POST","PATCH","PUT","DELETE")] [string] $Method,
    [Parameter(Mandatory=$true)] [string] $Uri,
    [object] $Body = $null,
    [hashtable] $Headers
  )

  if ($DryRun) {{
    Write-Log "DRYRUN: $Method $Uri"
    if ($Body -ne $null) {{ Write-Log ("DRYRUN BODY: " + ($Body | ConvertTo-Json -Depth 20)) }}
    return $null
  }}

  if ($Body -eq $null) {{
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
  }} else {{
    $json = $Body | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $json
  }}
}}

# -------------------- Preflight --------------------
Require-Cmd "gcloud"

if ($LogFile -and $LogFile.Trim() -ne "") {{
  Write-Log "Logging habilitado: $LogFile"
}}

Write-Log "==> Entorno: {ENV_NAME}"
Write-Log "==> Proyecto: $ProjectId"
gcloud config set project $ProjectId | Out-Null

Write-Log "==> Habilitando APIs: apigee.googleapis.com, apigeeconnect.googleapis.com"
if (-not $DryRun) {{
  gcloud services enable apigee.googleapis.com apigeeconnect.googleapis.com | Out-Null
}} else {{
  Write-Log "DRYRUN: gcloud services enable apigee.googleapis.com apigeeconnect.googleapis.com"
}}

# Billing (opcional, best effort)
Write-Log "==> Chequeando billing (best effort)"
try {{
  if (-not $DryRun) {{
    $billing = gcloud beta billing projects describe $ProjectId --format="value(billingEnabled)" 2>$null
    Write-Log "billingEnabled=$billing"
  }} else {{
    Write-Log "DRYRUN: gcloud beta billing projects describe $ProjectId --format=value(billingEnabled)"
  }}
}} catch {{
  Write-Log "WARN: No se pudo chequear billing por CLI (permiso/beta). Continuo..."
}}

# Auth headers
Write-Log "==> Obteniendo access token"
$token = Get-AccessToken
$headers = @{
  Authorization = "Bearer $token"
  "Content-Type" = "application/json"
}

$orgName = $ProjectId
$base = "https://apigee.googleapis.com/v1"

# -------------------- 1) ORG --------------------
Write-Log "==> Verificando ORG: $orgName"
$orgExists = $false
try {{
  if (-not $DryRun) {{
    Invoke-ApigeeRest -Method GET -Uri "$base/organizations/$orgName" -Headers $headers | Out-Null
    $orgExists = $true
    Write-Log "OK: ORG ya existe."
  }} else {{
    Write-Log "DRYRUN: asumimos ORG inexistente (para mostrar acciones)"
  }}
}} catch {{
  Write-Log "ORG no existe (o no accesible). Se intentará crear."
}}

if (-not $orgExists) {{
  $createOrgUri = "$base/organizations?parent=projects/$ProjectId"
  $orgBody = @{
    name            = $orgName
    runtimeType     = "HYBRID"
    analyticsRegion = $AnalyticsRegion
  }

  Write-Log "==> Creando ORG (HYBRID) en analyticsRegion=$AnalyticsRegion"
  $op = Invoke-ApigeeRest -Method POST -Uri $createOrgUri -Body $orgBody -Headers $headers

  if ($DryRun) {{
    Write-Log "DRYRUN: ORG creada (simulada). Se omite polling."
  }} else {{
    if (-not $op -or -not $op.name) {{
      throw "No se recibió operation.name al crear la ORG. Revisar permisos/errores de la API."
    }}

    $opName = $op.name
    $opUri  = "$base/$opName"

    Write-Log "Operación de creación iniciada: $opName"
    Write-Log "==> Esperando a que la ORG quede lista (timeout=${{OrgCreateTimeoutSeconds}}s, poll=${{PollIntervalSeconds}}s)"

    $start = Get-Date
    while ($true) {{
      $elapsed = (Get-Date) - $start
      if ($elapsed.TotalSeconds -gt $OrgCreateTimeoutSeconds) {{
        throw "Timeout esperando creación de ORG. Recomendación: revisar operación $opName en logs/console y reintentar."
      }}

      $opStatus = Invoke-ApigeeRest -Method GET -Uri $opUri -Headers $headers
      if ($opStatus.done -eq $true) {{
        if ($opStatus.error) {{
          $errMsg = $opStatus.error.message
          throw "La operación finalizó con error: $errMsg"
        }}
        Write-Log "OK: ORG creada y operación DONE."
        break
      }}

      Write-Log ("Aún en progreso... (elapsed={{0}}s)" -f [int]$elapsed.TotalSeconds)
      Start-Sleep -Seconds $PollIntervalSeconds
    }}
  }}
}}

# -------------------- 2) Environment --------------------
Write-Log "==> Creando/verificando Environment: $EnvironmentName"
$envGetUri = "$base/organizations/$orgName/environments/$EnvironmentName"
$envCreateUri = "$base/organizations/$orgName/environments?name=$EnvironmentName"

$envExists = $false
if (-not $DryRun) {{
  try {{
    Invoke-ApigeeRest -Method GET -Uri $envGetUri -Headers $headers | Out-Null
    $envExists = $true
    Write-Log "OK: Environment ya existe."
  }} catch {{
    $envExists = $false
  }}
}}

if (-not $envExists) {{
  $envBody = @{
    displayName = $EnvironmentName
    description = "Environment $EnvironmentName (bootstrap {ENV_NAME})"
  }
  Write-Log "Creando Environment..."
  Invoke-ApigeeRest -Method POST -Uri $envCreateUri -Body $envBody -Headers $headers | Out-Null
  Write-Log "OK: Environment creado (o solicitado)."
}}

# -------------------- 3) EnvGroup --------------------
Write-Log "==> Creando/verificando EnvGroup: $EnvGroupName"
$egGetUri = "$base/organizations/$orgName/envgroups/$EnvGroupName"
$egCreateUri = "$base/organizations/$orgName/envgroups?name=$EnvGroupName"

$eg = $null
if (-not $DryRun) {{
  try {{
    $eg = Invoke-ApigeeRest -Method GET -Uri $egGetUri -Headers $headers
    Write-Log "OK: EnvGroup ya existe."
  }} catch {{
    $eg = $null
  }}
}}

if (-not $eg) {{
  Write-Log "Creando EnvGroup..."
  Invoke-ApigeeRest -Method POST -Uri $egCreateUri -Headers $headers | Out-Null
  if (-not $DryRun) {{
    $eg = Invoke-ApigeeRest -Method GET -Uri $egGetUri -Headers $headers
  }} else {{
    $eg = @{ hostnames = @(); environments = @() }
  }}
  Write-Log "OK: EnvGroup creado (o solicitado)."
}}

# -------------------- 4) PATCH EnvGroup --------------------
Write-Log "==> Actualizando EnvGroup: hostnames + environments"

$desiredHostnames = @(
  $Hostnames | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
)

$existingHostnames = @()
if ($eg.hostnames) { $existingHostnames = @($eg.hostnames) }

$existingEnvs = @()
if ($eg.environments) { $existingEnvs = @($eg.environments) }

$envResourceName = "organizations/$orgName/environments/$EnvironmentName"

$mergedHostnames = @($existingHostnames + $desiredHostnames | Select-Object -Unique)
$mergedEnvs      = @($existingEnvs + @($envResourceName) | Select-Object -Unique)

$patchBody = @{
  hostnames    = $mergedHostnames
  environments = $mergedEnvs
}

$updateMask = "hostnames,environments"
$egPatchUri = "$egGetUri?updateMask=$updateMask"

Invoke-ApigeeRest -Method PATCH -Uri $egPatchUri -Body $patchBody -Headers $headers | Out-Null

Write-Log "==> Listo."
Write-Log "ORG       : $orgName"
Write-Log "ENV       : $EnvironmentName"
Write-Log "ENVGROUP  : $EnvGroupName"
Write-Log "HOSTNAMES : $($mergedHostnames -join ', ')"
Write-Log "ENVS      : $($mergedEnvs -join ', ')"

if ($DryRun) {{
  Write-Log "DRYRUN activo: no se ejecutaron llamadas reales a Apigee."
}}
'''

def write(env_name, envgroup_default, label, filename):
    content = template.format(ENV_NAME=env_name, ENVGROUP_DEFAULT=envgroup_default, ENV_LABEL=label)
    path = f"/mnt/data/{filename}"
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path

paths = [
    write("prod", "eg-prod", "PRODUCCIÓN", "apigee-bootstrap-prod.ps1"),
    write("test", "eg-test", "TEST", "apigee-bootstrap-test.ps1"),
    write("dec",  "eg-dec",  "DEC",  "apigee-bootstrap-dec.ps1"),
]
paths
