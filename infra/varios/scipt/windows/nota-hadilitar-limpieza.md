# 🧹 Script de Mantenimiento y Limpieza para Windows 11

Este script automatizado limpia en profundidad las carpetas de archivos temporales del sistema, los temporales del usuario actual, el caché de `Prefetch` y los instaladores remanentes de Windows Update (`SoftwareDistribution`). Al finalizar, fuerza el vaciado de la Papelera de Reciclaje.

## 🚀 Creación y Ejecución en un solo paso

Para evitar errores de permisos, codificación o archivos inexistentes, abrir una consola de **PowerShell como Administrador** y pegar el siguiente bloque de comandos completo. El comando creará el script `Limpiar-Temporales.ps1` en el directorio actual y lo ejecutará aplicando un bypass temporal de restricciones:

```powershell
# 1. Crear el archivo .ps1 e inyectar el código de limpieza de forma limpia
New-Item -Path ".\Limpiar-Temporales.ps1" -ItemType File -Value '@(
    "C:\Windows\Temp\*",
    "$env:USERPROFILE\AppData\Local\Temp\*",
    "C:\Windows\Prefetch\*",
    "C:\Windows\SoftwareDistribution\Download\*"
) | ForEach-Object {
    Write-Host "Limpiando: $_" -ForegroundColor Yellow
    Get-ChildItem -Path $_ -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Write-Host "¡Limpieza Jorsat finalizada con éxito!" -ForegroundColor Green' -Force

# 2. Ejecutar el script evadiendo restricciones de ejecución locales
Set-ExecutionPolicy Bypass -Scope Process -Force; .\Limpiar-Temporales.ps1
