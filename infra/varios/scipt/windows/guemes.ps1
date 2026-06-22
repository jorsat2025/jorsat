# --- CONFIGURACIÓN ---
$GuemesIP  = "10.10.10.5"
$Puerto    = 777
$Usuario   = "jlb"
$Password  = "murdok48"

# --- DESCARGA AUTOMÁTICA DE PLINK (Solo si no existe) ---
$PlinkPath = "$env:TEMP\plink.exe"
if (-not (Test-Path $PlinkPath)) {
    Write-Host "Descargando componente de conexión seguro..." -ForegroundColor Yellow
    # Descarga la versión oficial de 64 bits
    Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" -OutFile $PlinkPath
}

Write-Host "Conectando a Güemes en la misma ventana..." -ForegroundColor Cyan

# --- CONEXIÓN INTERACTIVA ---
# Ejecuta plink desde la carpeta temporal pasando los datos
& $PlinkPath -ssh $GuemesIP -P $Puerto -l $Usuario -pw $Password
