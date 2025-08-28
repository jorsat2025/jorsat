#!/usr/bin/env bash
# calico-mtu-auto.sh - Ajusta MTU de Calico (veth_mtu y FELIX_*)
set -euo pipefail
: "${DRY_RUN:=0}"
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta '$1'"; exit 1; }; }
k(){ if [ "$DRY_RUN" = "1" ]; then echo "+ kubectl $*"; else kubectl "$@"; fi; }
need kubectl; need ip; need awk
IFACE="${IFACE:-$(ip route | awk '/default/ {print $5; exit}')}"
[ -z "$IFACE" ] && { echo "ERROR: no pude detectar IFACE"; exit 1; }
HOST_MTU=$(ip -o link show "$IFACE" | awk '{for(i=1;i<=NF;i++) if($i=="mtu"){print $(i+1); exit}}')
[ -z "${HOST_MTU:-}" ] && { echo "ERROR: no pude leer MTU de $IFACE"; exit 1; }
VXLAN=$(kubectl -n kube-system get ds calico-node -o jsonpath='{.spec.template.spec.containers[?(@.name=="calico-node")].env[?(@.name=="CALICO_IPV4POOL_VXLAN")].value}' 2>/dev/null || true)
IPIP=$(kubectl -n kube-system get ds calico-node -o jsonpath='{.spec.template.spec.containers[?(@.name=="calico-node")].env[?(@.name=="CALICO_IPV4POOL_IPIP")].value}' 2>/dev/null || true)
MODE="none"; OVERHEAD=0
echo "${VXLAN:-}" | grep -qi always && { MODE=vxlan; OVERHEAD=50; }
echo "${IPIP:-}"  | grep -qi always && { MODE=ipip;  OVERHEAD=20; }
VETH_MTU=$(( HOST_MTU - OVERHEAD ))
[ "$VETH_MTU" -lt 1200 ] && { echo "ERROR: veth_mtu $VETH_MTU muy bajo"; exit 1; }
echo "IFACE=$IFACE host_mtu=$HOST_MTU mode=$MODE overhead=$OVERHEAD => veth_mtu=$VETH_MTU"
k -n kube-system patch cm calico-config --type merge -p "{\"data\":{\"veth_mtu\":\"$VETH_MTU\"}}" || echo "WARN: no pude parchear calico-config"
[ "$MODE" = "vxlan" ] && k -n kube-system set env ds/calico-node FELIX_VXLANMTU="$VETH_MTU"
[ "$MODE" = "ipip" ]  && k -n kube-system set env ds/calico-node FELIX_IPINIPMTU="$VETH_MTU"
k -n kube-system rollout restart ds/calico-node
echo "Listo. Recreá pods de tus apps para que tomen el nuevo MTU."
