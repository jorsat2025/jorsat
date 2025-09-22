#!/usr/bin/env bash
set -euo pipefail

echo "== Router/Forwarding =="
sysctl -n net.ipv4.ip_forward

echo; echo "== Anti-spoof (rp_filter) =="
sysctl -n net.ipv4.conf.all.rp_filter
sysctl -n net.ipv4.conf.default.rp_filter

echo; echo "== ARP defenses =="
sysctl -n net.ipv4.conf.all.arp_filter
sysctl -n net.ipv4.conf.all.arp_ignore
sysctl -n net.ipv4.conf.all.arp_announce

echo; echo "== nftables: tablas anti-spoof =="
if nft list table inet antispoof >/dev/null 2>&1; then
  nft list chain inet antispoof prerouting | sed -n '1,120p'
else
  echo "(sin table inet antispoof)"
fi
if nft list table netdev l2guard >/dev/null 2>&1; then
  nft list table netdev l2guard | sed -n '1,120p'
else
  echo "(sin table netdev l2guard)"
fi

echo; echo "== Contadores de drops en antispoof =="
if nft -a list chain inet antispoof prerouting >/dev/null 2>&1; then
  nft -a list chain inet antispoof prerouting | \
    awk '/counter drop/ {
      pk=""; by="";
      for(i=1;i<=NF;i++){ if($i=="packets") pk=$(i+1); if($i=="bytes") by=$(i+1) }
      print "drop:", pk " packets,", by " bytes"
    }'
else
  echo "(no hay chain prerouting en inet/antispoof)"
fi

echo; echo "== Conectividad básica =="
GW=$(ip -4 route | awk '$1=="default"{print $3; exit}')
echo "Gateway: ${GW:-desconocido}"
if [[ -n "${GW:-}" ]]; then ping -c1 -W1 "$GW" >/dev/null && echo "ping GW OK" || echo "ping GW FAIL"; fi
ping -c1 -W2 8.8.8.8 >/dev/null && echo "ping Internet OK" || echo "ping Internet FAIL"
getent hosts www.google.com >/dev/null && echo "DNS OK" || echo "DNS FAIL"
