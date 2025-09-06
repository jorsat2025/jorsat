#!/bin/bash

set -e

# MACs reales de tus interfaces
MAC_LAN="16:09:01:1a:e1:38"
MAC_WAN="16:09:01:1a:e1:3b"

echo "[+] Creando regla udev para renombrar interfaces..."
cat <<EOF > /etc/udev/rules.d/10-network-names.rules
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$MAC_LAN", NAME="lan"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$MAC_WAN", NAME="wan"
EOF

echo "[+] Desactivando nombres predictivos de red en grub..."
sed -i 's/GRUB_CMDLINE_LINUX="[^"]*/& net.ifnames=0 biosdevname=0/' /etc/default/grub

echo "[+] Actualizando grub..."
update-grub

echo "[+] Regenerando initramfs..."
update-initramfs -u

echo "[✔] Todo listo. Reiniciá el sistema para aplicar los nuevos nombres: lan y wan"
