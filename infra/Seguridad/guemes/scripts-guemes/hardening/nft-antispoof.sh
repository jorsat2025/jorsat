#!/usr/bin/env bash
set -euo pipefail

LAN="lan"
WAN="wan"
ALLOW_CGNAT=1   # 1 = permite 100.64.0.0/10 en WAN (común en ISPs). Cambiá a 0 si no lo usás.

usage() {
  cat <<'EOF'
Uso: antispoof-toggle.sh [--apply|--revert|--status] [--lan IFACE] [--wan IFACE] [--allow-cgnat 0|1]

Acciones:
  --apply     Aplica anti-spoof (sysctl + nft) seguro para router/gateway
  --revert    Revierte por completo (borra tablas nft y drop-in sysctl)
  --status    Muestra estado actual

Opciones:
  --lan IFACE         Interfaz LAN (default: lan)
  --wan IFACE         Interfaz WAN (default: wan)
  --allow-cgnat 0|1   Permitir CGNAT 100.64/10 en WAN (default: 1)
EOF
}

log(){ echo -e "$*"; }
err(){ echo -e "$*" >&2; }

need_root(){
  if [[ $EUID -ne 0 ]]; then err "Ejecutá como root."; exit 1; fi
}

# ===== Helpers de red =====
cidr_of_iface() {
  # Devuelve "IP/prefix" de la interfaz
  ip -4 addr show dev "$1" | awk '/inet /{print $2; exit}'
}

net_cidr_of_iface() {
  # Usa la IP/prefix como "red" (nft acepta X.Y.Z.W/nn y matchea la red)
  local cidr; cidr=$(cidr_of_iface "$1")
  [[ -n "$cidr" ]] && echo "$cidr" || true
}

gw_of_iface() {
  ip -4 route show default dev "$1" 2>/dev/null | awk 'NR==1{print $3}'
}

# ===== Sysctl (router-safe) =====
apply_sysctl() {
  local f=/etc/sysctl.d/20-antispoof-router.conf
  cat > "$f" <<'EOF'
# Anti-spoof IP y ARP seguro para router/gateway
# Reverse path filter (1 = loose; más seguro que 0, menos roto que 2 en WAN asimétrica)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# ICMP redirects: no aceptar ni enviar (evita route hijacking)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Log de paquetes marcianos
net.ipv4.conf.all.log_martians = 1

# Mantener forwarding (es router)
net.ipv4.ip_forward = 1

# ARP defensas (evita ARP flux y anuncios inconsistentes)
net.ipv4.conf.all.arp_filter = 1
net.ipv4.conf.all.arp_ignore = 2
net.ipv4.conf.all.arp_announce = 2

# No usar proxy ARP (a menos que sea intencional)
net.ipv4.conf.all.proxy_arp = 0
EOF
  sysctl --system >/dev/null
}

revert_sysctl() {
  rm -f /etc/sysctl.d/20-antispoof-router.conf || true
  sysctl --system >/dev/null || true
}

# ===== nftables (tablas propias) =====
apply_nft() {
  local lan="$1" wan="$2" allow_cgnat="$3"

  # Detectar redes/gateway
  local LAN_CIDR WAN_CIDR WAN_GW
  LAN_CIDR=$(net_cidr_of_iface "$lan" || true)
  WAN_CIDR=$(net_cidr_of_iface "$wan" || true)
  WAN_GW=$(gw_of_iface "$wan" || true)

  [[ -n "$LAN_CIDR" ]] || { err "No pude detectar CIDR de $lan"; exit 1; }
  [[ -n "$WAN_CIDR" ]] || { err "No pude detectar CIDR de $wan"; exit 1; }

  # Limpiar tablas si existen
  nft list table inet antispoof >/dev/null 2>&1 && nft delete table inet antispoof
  nft list table netdev l2guard  >/dev/null 2>&1 && nft delete table netdev l2guard

  # Tabla IPv4/IPv6 (usamos IPv4)
  nft add table inet antispoof
  nft 'add chain inet antispoof prerouting { type filter hook prerouting priority -150 ; policy accept ; }'

  # --- WAN ---
  # 0) Aceptar DHCP (cliente) en WAN: UDP 67->68 (para que no se caiga el lease)
  nft add rule inet antispoof prerouting iifname "$wan" ip protocol udp udp sport 67 udp dport 68 accept

  # 1) Aceptar explícitamente gateway y la red de la interfaz WAN (por si es privada)
  [[ -n "$WAN_GW" ]] && nft add rule inet antispoof prerouting iifname "$wan" ip saddr "$WAN_GW" accept
  nft add rule inet antispoof prerouting iifname "$wan" ip saddr "$WAN_CIDR" accept
  [[ "$allow_cgnat" -eq 1 ]] && nft add rule inet antispoof prerouting iifname "$wan" ip saddr 100.64.0.0/10 accept

  # 2) Dropear bogons y reservadas en WAN (lo permitido arriba ya salió por 'accept')
  nft add rule inet antispoof prerouting iifname "$wan" ip saddr { 0.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } counter drop
  # Nota: 10/8, 172.16/12 y 192.168/16 quedarían drop, salvo que coincidan con $WAN_CIDR y hayan sido aceptados antes.

  # --- LAN ---
  # Sólo permitimos tráfico cuyo origen pertenezca a la subred real de LAN
  nft add rule inet antispoof prerouting iifname "$lan" ip saddr != "$LAN_CIDR" counter drop

  # --- ARP guard (Capa 2) en LAN ---
  nft add table netdev l2guard
  nft "add chain netdev l2guard ingress_${lan} { type filter hook ingress device \"$lan\" priority 0 ; }"
  # Descarta ARP con sender IP fuera de LAN (mitiga ARP spoof básico)
  nft add rule netdev l2guard ingress_${lan} arp operation {request, reply} arp saddr ip != "$LAN_CIDR" counter drop
  # Limitar tormentas ARP
  nft add rule netdev l2guard ingress_${lan} arp operation {request, reply} limit rate 50/second accept

  log "✅ Anti-spoof aplicado:
  - LAN($lan): $LAN_CIDR
  - WAN($wan): $WAN_CIDR ${WAN_GW:+(GW $WAN_GW)}
  - CGNAT permitido: $allow_cgnat"
}

revert_nft() {
  nft list table inet antispoof >/dev/null 2>&1 && nft delete table inet antispoof
  nft list table netdev l2guard  >/dev/null 2>&1 && nft delete table netdev l2guard
}

show_status() {
  echo "---- sysctl ----"
  sysctl net.ipv4.ip_forward 2>/dev/null | sed 's/^/ /'
  sysctl net.ipv4.conf.all.rp_filter 2>/dev/null | sed 's/^/ /'
  sysctl net.ipv4.conf.default.rp_filter 2>/dev/null | sed 's/^/ /'
  sysctl net.ipv4.conf.all.accept_redirects 2>/dev/null | sed 's/^/ /'
  sysctl net.ipv4.conf.all.send_redirects 2>/dev/null | sed 's/^/ /'
  sysctl net.ipv4.conf.all.arp_filter 2>/dev/null | sed 's/^/ /'
  sysctl net.ipv4.conf.all.arp_ignore 2>/dev/null | sed 's/^/ /'
  sysctl net.ipv4.conf.all.arp_announce 2>/dev/null | sed 's/^/ /'
  echo "---- nftables ----"
  nft list table inet antispoof 2>/dev/null || echo "(sin tabla inet antispoof)"
  nft list table netdev l2guard 2>/dev/null || echo "(sin tabla netdev l2guard)"
}

# ===== main =====
ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply|--revert|--status) ACTION="${1#--}"; shift ;;
    --lan) LAN="$2"; shift 2 ;;
    --wan) WAN="$2"; shift 2 ;;
    --allow-cgnat) ALLOW_CGNAT="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) err "Opción desconocida: $1"; usage; exit 2 ;;
  esac
done

need_root

case "$ACTION" in
  apply)
    apply_sysctl
    apply_nft "$LAN" "$WAN" "$ALLOW_CGNAT"
    ;;
  revert)
    revert_nft
    revert_sysctl
    ;;
  status)
    show_status
    ;;
  *)
    usage; exit 2 ;;
esac
