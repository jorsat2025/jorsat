#!/bin/bash

# check_cluster-v2
# Menú interactivo para chequeos rápidos del clúster OpenShift

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Carpeta de logs
LOG_DIR="/var/log/ocp-health"
mkdir -p "$LOG_DIR"

# Borrar logs de más de 7 días
find "$LOG_DIR" -type f -name "check_cluster_*.log" -mtime +7 -exec rm -f {} \;

# Timestamp para log actual
LOG_FILE="$LOG_DIR/check_cluster_$(date +'%Y-%m-%d_%H-%M').log"

# Redirigir stdout y stderr a consola y archivo
exec > >(tee -a "$LOG_FILE") 2>&1

while true; do
  echo ""
  echo "🧠 Menú de chequeo de clúster OpenShift:"
  echo "1) Ver salud del clúster etcd"
  echo "2) Ver pods fallando en todos los namespaces"
  echo "3) Ver uso de CPU por nodo"
  echo "4) Ver uso de memoria por nodo"
  echo "5) Chequeos de clúster OpenShift (clusteroperators, nodos, etc.)"
  echo "6) Ver PVCs con errores"
  echo "7) Ver pods en estado Pending"
  echo "8) Salir"
  read -rp "Elegí una opción [1-8]: " opcion

  case "$opcion" in
    1)
      echo -e "\n🔍 Ejecutando chequeo etcd..."
      /usr/local/bin/check-etcd-health.sh
      ;;
    2)
      echo -e "\n🚨 Listando pods fallando:"
      echo -e "NAMESPACE\tPOD\tREASON"
      oc get pods --all-namespaces -o json \
        | jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting != null) | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.containerStatuses[].state.waiting.reason)"' \
        | while IFS=$'\t' read -r ns pod reason; do
            if [[ "$reason" == "CrashLoopBackOff" || "$reason" == "ImagePullBackOff" ]]; then
              echo -e "${RED}${ns}\t${pod}\t${reason}${NC}"
            else
              echo -e "$ns\t$pod\t$reason"
            fi
          done
      ;;
    3)
      echo -e "\n📊 Uso de CPU por nodo:"
      kubectl top nodes | sort -k3 -rh
      ;;
    4)
      echo -e "\n📈 Uso de memoria por nodo:"
      kubectl top nodes | sort -k5 -rh
      ;;
    5)
      echo -e "\n🧪 Chequeo de estado del clúster OpenShift:"
      echo -e "\n🔧 ClusterOperators no disponibles:"
      oc get clusteroperators | grep -v 'True.*False.*False' || echo -e "${GREEN}✅ Todos OK${NC}"
      echo -e "\n🚨 Nodos con problemas:"
      oc get nodes | grep -v ' Ready ' || echo -e "${GREEN}✅ Todos OK${NC}"
      echo -e "\n📦 Estado general de máquinas (MachineConfigPools):"
      oc get mcp
      echo -e "\n📡 Estado de los operadores:"
      oc get co
      ;;
    6)
      echo -e "\n💾 Listando PVCs con problemas:"
      oc get pvc --all-namespaces | grep -Ev 'Bound|NAME' || echo -e "${GREEN}✅ Todos los PVCs están Bound${NC}"
      ;;
    7)
      echo -e "\n⏳ Listando pods en estado Pending:"
      oc get pods --all-namespaces --field-selector=status.phase=Pending || echo -e "${GREEN}✅ No hay pods en Pending${NC}"
      ;;
    8)
      echo "👋 Hasta la vista..."
      exit 0
      ;;
    *)
      echo "❌ Opción inválida. Probá de nuevo."
      ;;
  esac
done

