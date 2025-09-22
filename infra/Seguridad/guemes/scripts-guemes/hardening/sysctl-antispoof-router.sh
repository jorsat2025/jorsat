#!/usr/bin/env bash
set -euo pipefail

CONF=/etc/sysctl.d/20-antispoof-router.conf
cat > "$CONF" <<'EOF'
# === Anti-spoof IP (router-safe) ===
# Reverse Path Filter: usar modo estricto (2) para all y default,
# y asegurate luego de setearlo interface-by-interface si hace falta.
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

# No aceptar ni enviar redirects (mitiga algunos ataques de ruta)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Loggear martians (útil para detectar spoof)
net.ipv4.conf.all.log_martians = 1

# Mantener forwarding habilitado (router)
net.ipv4.ip_forward = 1

# === Defensas ARP (Capa 2) ===
# Evita responder ARP en interfaces equivocadas (ARP flux)
net.ipv4.conf.all.arp_filter = 1

# Responder ARP sólo si la IP destino está asignada a la interfaz que recibe
net.ipv4.conf.all.arp_ignore = 2
# Anunciar la IP de origen "más adecuada" y evitar anuncios inconsistentes
net.ipv4.conf.all.arp_announce = 2

# No usar Proxy ARP (salvo que realmente lo necesites)
net.ipv4.conf.all.proxy_arp = 0
EOF

sysctl --system
echo "✅ sysctl anti-spoof aplicado (router-safe)."
