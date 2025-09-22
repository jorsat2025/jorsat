#!/usr/bin/env bash
set -euo pipefail

LAN=${LAN:-lan}
WAN=${WAN:-wan}
LAN_NET=${LAN_NET:-10.10.10.0/24}

# Crea una tabla si no existe
nft list table inet antispoof >/dev/null 2>&1 || nft add table inet antispoof

# Chain para tráfico que ingresa por interfaces (hook prerouting captura forward también)
nft 'add chain inet antispoof prerouting { type filter hook prerouting priority -150 ; policy accept ; }' 2>/dev/null || true

# ---- Anti-spoof IP en WAN: bloquear fuentes "bogon"/privadas/inválidas ----
nft "flush chain inet antispoof prerouting" 2>/dev/null || true
nft add rule inet antispoof prerouting iifname $WAN ip saddr { 0.0.0.0/8, 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } counter drop
nft add rule inet antispoof prerouting iifname $WAN ip saddr 100.64.0.0/10 counter drop   # CGNAT no debería venir desde Internet real
# (Opcional) bloquear bogons adicionales si no recibís rutas de IXP/operadores (ajusta según tu escenario)

# ---- Anti-spoof IP en LAN: sólo permitir IPs de la subred declarada ----
nft add rule inet antispoof prerouting iifname $LAN ip saddr != $LAN_NET counter drop

# ---- (Opcional) protección básica ARP por nftables en LAN ----
# Requiere hook 'ingress' en family 'netdev' para validar ARP a nivel L2.
# Activá sólo si necesitás chequeo ARP simple (sender IP debe pertenecer a LAN).
if nft list table netdev l2guard >/dev/null 2>&1; then
  :
else
  nft add table netdev l2guard
  nft "add chain netdev l2guard ingress_$LAN { type filter hook ingress device \"$LAN\" priority 0 ; }"
  # Permitir sólo ARP de la subred LAN; descartar ARP con IPs fuera de rango (mitiga ARP spoof básico)
  nft add rule netdev l2guard ingress_$LAN arp operation {request, reply} arp saddr ip != $LAN_NET counter drop
  # (Opcional) limitar tormentas de ARP
  nft add rule netdev l2guard ingress_$LAN arp operation {request, reply} limit rate 50/second accept
fi

echo "✅ Reglas anti-spoof cargadas:
- WAN: drop fuentes privadas/bogon
- LAN: sólo IP origen $LAN_NET
- L2 opcional: filtro ARP básico en $LAN (netdev)"
