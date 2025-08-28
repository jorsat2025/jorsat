#!/usr/bin/env bash
# calico-mtu-auto.sh - Ajusta MTU de Calico en función del MTU del host y del encapsulado (VXLAN/IPIP).
# Uso:
#   ./calico-mtu-auto.sh                   # aplica automáticamente (requiere kubectl)
#   IFACE=eth0 ./calico-mtu-auto.sh        # forzar interfaz
#   DRY_RUN=1 ./calico-mtu-auto.sh         # solo mostrar lo que haría
set -euo pipefail

: "${DRY_RUN:=0}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta '$1' en PATH"; exit 1; }; }
k() { if [ "$DRY_RUN" = "1" ]; then echo "+ kubectl $*"; else kubectl "$@"; fi; }

need kubectl
need ip
need awk

IFACE="${IFACE:-$(ip route | awk '/default/ {print $5; exit}')}"
if [ -z "$IFACE" ]; then
  echo "ERROR: no pude detectar la interfaz por defecto. Definí IFACE=..."
  exit 1
fi

HOST_MTU=$(ip -o link show "$IFACE" | awk '{for(i=1;i<=NF;i++) if($i=="mtu"){print $(i+1); exit}}')
if [ -z "${HOST_MTU:-}" ]; then
  echo "ERROR: no pude obtener MTU de $IFACE"; exit 1
fi

# Detectar modo de encapsulado desde el DaemonSet calico-node (env)
VXLAN=$(kubectl -n kube-system get ds calico-node -o jsonpath='{.spec.template.spec.containers[?(@.name=="calico-node")].env[?(@.name=="CALICO_IPV4POOL_VXLAN")].value}' 2>/dev/null || true)
IPIP=$(kubectl -n kube-system get ds calico-node -o jsonpath='{.spec.template.spec.containers[?(@.name=="calico-node")].env[?(@.name=="CALICO_IPV4POOL_IPIP")].value}' 2>/dev/null || true)

MODE="none"; OVERHEAD=0
if echo "${VXLAN:-}" | grep -qi 'always'; then MODE="vxlan"; OVERHEAD=50; fi
if echo "${IPIP:-}"  | grep -qi 'always'; then MODE="ipip";  OVERHEAD=20; fi

VETH_MTU=$(( HOST_MTU - OVERHEAD ))
if [ "$VETH_MTU" -lt 1200 ]; then
  echo "ERROR: veth_mtu calculado (${VETH_MTU}) es demasiado bajo. Abortando."
  exit 1
fi

echo "Interfaz: $IFACE  | MTU host: $HOST_MTU  | Encapsulado: $MODE  | Overhead: $OVERHEAD  => veth_mtu=$VETH_MTU"

# Patch del ConfigMap calico-config (veth_mtu)
k -n kube-system patch cm calico-config --type merge -p "{\"data\":{\"veth_mtu\":\"$VETH_MTU\"}}" || {
  echo "WARN: no pude parchear calico-config. ¿Existe?"; 
}

# Ajuste de FELIX_* según modo
if [ "$MODE" = "vxlan" ]; then
  k -n kube-system set env ds/calico-node FELIX_VXLANMTU="$VETH_MTU"
elif [ "$MODE" = "ipip" ]; then
  k -n kube-system set env ds/calico-node FELIX_IPINIPMTU="$VETH_MTU"
else
  echo "Modo 'none' (sin encapsulado): no se tocan FELIX_VXLANMTU/IPINIPMTU."
fi

# Reinicio de calico-node para aplicar
k -n kube-system rollout restart ds/calico-node

echo "Hecho. Re-creá los pods de tus workloads para que tomen el nuevo MTU (o dejá que se roten con el tiempo)."
echo "Chequeo dentro de un pod: kubectl exec -it <pod> -- ip link show eth0 | grep mtu"
