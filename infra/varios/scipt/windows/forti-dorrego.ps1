# --- CONFIGURACI�N ---
$FortiIP   = "10.10.10.1"          # <--- Cambia por la IP de tu Forti
$Puerto    = 777
$Usuario   = "admin"
$Password  = "Murdok2026!!"

Write-Host "Conectando a $FortiIP y aplicando login autom�tico..." -ForegroundColor Cyan

# 1. Creamos el objeto para simular el teclado
$wshell = New-Object -ComObject Wscript.Shell

# 2. Iniciamos el proceso SSH en una nueva ventana de consola
Start-Process powershell -ArgumentList "-NoExit", "-Command", "ssh -p $Puerto $Usuario@$FortiIP"

# 3. Esperamos 2 segundos a que el FortiGate responda y pida la contrase�a
Start-Sleep -Seconds 2

# 4. Enviamos la contrase�a simulando el teclado + ENTER
$wshell.SendKeys($Password)
$wshell.SendKeys("{ENTER}")
