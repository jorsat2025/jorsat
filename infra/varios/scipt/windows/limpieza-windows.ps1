<#
.SYNOPSIS
    Script de mantenimiento para Windows 11 - Jorsat Automation
    Limpia archivos temporales del sistema, de usuarios y carpetas de Prefetch.
#>

# Forzar a que corra con privilegios de Administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "¡Se necesitan permisos de Administrador! Reabriendo script..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   INICIANDO MANTENIMIENTO WINDOWS 11   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Definir las rutas críticas de basura
$RutasTemporales = @(
    "C:\Windows\Temp\*",
    "$env:USERPROFILE\AppData\Local\Temp\*",
    "C:\Windows\Prefetch\*",
    "C:\Windows\SoftwareDistribution\Download\*"
)

# 2. Ejecutar borrado capa por capa
foreach ($Ruta in $RutasTemporales) {
    Write-Host "Limpiando: $Ruta" -ForegroundColor Yellow
    try {
        # -Force borra ocultos, -Recurse borra subcarpetas, -ErrorAction SilentlyContinue ignora archivos en uso
        Get-ChildItem -Path $Ruta -Recurse -ErrorAction SilentlyContinue | 
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "No se pudieron borrar algunos archivos en: $Ruta (pueden estar en uso)" -ForegroundColor DarkGray
    }
}

# 3. Limpieza extra profunda usando herramientas nativas de Windows 11
Write-Host "Ejecutando liberador de espacio del sistema (Cleanmgr)..." -ForegroundColor Yellow
& cleanmgr.exe /sagerun:1 | Out-Null

Write-Host "Vaciando la Papelera de Reciclaje..." -ForegroundColor Yellow
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

Write-Host "=========================================" -ForegroundColor Green
Write-Host "     ¡MANTENIMIENTO FINALIZADO!          " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
