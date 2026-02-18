# Guía Paso a Paso -- Fix de Inicio de Sesión

## Microsoft Teams (Clásico y Nuevo) + Outlook

### Windows 11

------------------------------------------------------------------------

## 🎯 Objetivo

Resolver problemas de inicio de sesión cuando: - Teams queda en "Signing
in..." - Outlook pide credenciales en loop - Aparece "Something went
wrong" - Pantalla en blanco - Las credenciales son correctas pero no
autentica

------------------------------------------------------------------------

# 🔹 PASO 1 -- Guardar el Script

1.  Crear archivo:

        Fix-TeamsOutlookSignIn-W11.ps1

2.  Pegar el script corregido.

3.  Guardarlo en una carpeta local (por ejemplo: `C:\Scripts`).

------------------------------------------------------------------------

# 🔹 PASO 2 -- Permitir ejecución (una sola vez)

Abrir PowerShell como usuario normal:

``` powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

------------------------------------------------------------------------

# 🔹 PASO 3 -- Ejecutar FIX (modo normal)

Desde la carpeta donde está el script:

``` powershell
.\Fix-TeamsOutlookSignIn-W11.ps1
```

El script hará:

-   Cerrar Teams y Outlook
-   Limpiar caché Teams clásico
-   Limpiar caché Teams nuevo
-   Limpiar tokens Office / OneAuth
-   Resetear WAM (AAD Broker)
-   Reiniciar servicios clave

------------------------------------------------------------------------

# 🔹 PASO 4 -- Reiniciar Windows (Recomendado)

Después de ejecutar el script:

1.  Reiniciar el equipo
2.  Abrir primero Outlook
3.  Luego abrir Teams

------------------------------------------------------------------------

# 🔹 PASO 5 -- Si sigue el problema (Modo AGRESIVO)

Ejecutar:

``` powershell
.\Fix-TeamsOutlookSignIn-W11.ps1 -Aggressive
```

Esto además: - Borra credenciales guardadas en Administrador de
Credenciales - Fuerza re-login completo

⚠️ Puede pedir autenticación nuevamente en apps Microsoft.

------------------------------------------------------------------------

# 🔍 Verificación Técnica

## Verificar que WAM esté activo

``` powershell
Get-Service WebAccountManager
```

Debe estar en estado: `Running`

------------------------------------------------------------------------

## Verificar que Teams nuevo esté instalado

``` powershell
Get-AppxPackage *MSTeams*
```

------------------------------------------------------------------------

## Verificar Outlook instalado

``` powershell
Get-Item "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
```

------------------------------------------------------------------------

# 🧪 Diagnóstico adicional (si persiste)

-   Confirmar conexión a:
    -   https://login.microsoftonline.com
    -   https://teams.microsoft.com
-   Verificar que no haya proxy interceptando TLS
-   Confirmar que WebView2 esté instalado

------------------------------------------------------------------------

# ✅ Resultado Esperado

Después del fix:

-   Outlook inicia sesión sin pedir contraseña repetidamente
-   Teams abre normalmente
-   No hay loops de autenticación
-   No hay pantalla blanca

------------------------------------------------------------------------

# 📌 Notas Importantes

-   Este procedimiento no elimina perfiles de Outlook.
-   No elimina correos locales.
-   Solo limpia tokens y caché de autenticación.
-   Recomendado en entornos Microsoft 365.

------------------------------------------------------------------------

**Fin de la guía.**
