# ================================
$MinVersion = [Version]"7.2.0"   # versión mínima requerida
$CurrentVersion = $PSVersionTable.PSVersion

Write-Host "Versión actual de PowerShell: $CurrentVersion"

# ================================
# Validación de versión
# ================================
if ($CurrentVersion -ge $MinVersion) {
    Write-Host "✔ PowerShell cumple con la versión mínima ($MinVersion). No se requiere actualización." -ForegroundColor Green
    exit 0
}

Write-Host "⚠ PowerShell desactualizado. Se requiere versión $MinVersion o superior." -ForegroundColor Yellow

# ================================
# Verificar si winget está disponible
# ================================
$winget = Get-Command winget -ErrorAction SilentlyContinue

if (-not $winget) {
    Write-Host "❌ winget no está instalado. No se puede actualizar automáticamente." -ForegroundColor Red
    Write-Host "👉 Instalá manualmente desde: https://aka.ms/getwinget"
    exit 1
}

# ================================
# Ejecutar actualización
# ================================
Write-Host "🚀 Iniciando actualización de PowerShell..." -ForegroundColor Cyan

try {
    winget install --id Microsoft.Powershell --source winget --accept-package-agreements --accept-source-agreements -h

    Write-Host "✔ Instalación finalizada. Reiniciá la terminal para usar la nueva versión." -ForegroundColor Green
}
catch {
    Write-Host "❌ Error durante la actualización: $_" -ForegroundColor Red
    exit 1
}