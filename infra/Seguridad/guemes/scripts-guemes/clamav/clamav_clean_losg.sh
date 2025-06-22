#!/bin/bash
# Borrar logs de ClamAV con más de 30 días

find /var/log/clamav/ -type f -name "daily-scan-*.log" -mtime +30 -exec rm -f {} \;
