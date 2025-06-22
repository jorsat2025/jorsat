#!/bin/bash

# Script: clamav-scan.sh
# Descripción: Escaneo liviano con ClamAV con logging y bajo impacto de CPU

# Archivo de log con fecha del día
LOGFILE="/var/log/clamav/daily-scan-$(date +%F).log"

# Directorios a escanear
SCAN_PATHS="/home /opt /var/www"

# Directorios a excluir del escaneo
EXCLUDES="^/proc|^/sys|^/dev|^/run|^/tmp|^/var/log|^/mnt"

# Crear el directorio de logs si no existe
mkdir -p /var/log/clamav

# Ejecutar escaneo con bajo uso de recursos y guardar log
nice -n 19 ionice -c3 clamscan -r $SCAN_PATHS --infected --bell --exclude-dir="$EXCLUDES" | tee "$LOGFILE"
