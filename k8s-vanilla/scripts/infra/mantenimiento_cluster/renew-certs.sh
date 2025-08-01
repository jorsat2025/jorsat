#!/bin/bash

# check_cluster_k8s.sh - Chequeo interactivo del clúster Kubernetes

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Carpeta de logs
LOG_DIR="/var/log/k8s-health"
mkdir -p "$LOG_DIR"

# Borrar logs de más de 7 días
find "$LOG_DIR" -type f -name "check_cluster_*.log" -mtime +7 -exec rm -f {} \;

# Timestamp para log actual
LOG_FILE="$LOG_DIR/check_cluster_$(date +'%Y-%m-%d_%H-%M').log"

# Redirigir stdout y stderr a consola y archivo
exec > >(tee -a "$LOG_FILE") 2>&1

while true; do
  echo ""
  echo "🧠 Menú de chequeo de clúster Kubernetes:"
  echo "1) Ver pods fallando en todos los namespaces"
  echo "2) Ver estado completo de pods (kubectl get pods -A -o wide)"
  echo "3) Ver pods en estado Pending"
  echo "4) Ver logs de pods en CrashLoopBackOff"
  echo "5) Ver PVCs con errores"
  echo "6) Ver últimos eventos del cluster"
  echo "7) Ver estado de nodos (Ready/Not Ready)"
  echo "8) Ver uso de CPU por nodo"
  echo "9) Ver uso de memoria por nodo"
  echo "10) Ver estado de PVCs y StorageClasses"
  echo "11) Salir"
  read -rp "Elegí una opción [1-11]: " opcion

  case "$opcion" in
    1)
      echo -e "\n🚨 Listando pods fallando:"
      echo -e "NAMESPACE\tPOD\tREASON"
      kubectl get pods --all-namespaces -o json \
        | jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting != null) | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.containerStatuses[].state.waiting.reason)"' \
        | while IFS=$'\t' read -r ns pod reason; do
            if [[ "$reason" == "CrashLoopBackOff" || "$reason" == "ImagePullBackOff" ]]; then
              echo -e "${RED}${ns}\t${pod}\t${reason}${NC}"
            else
              echo -e "$ns\t$pod\t$reason"
            fi
          done
      ;;
    2)
      echo -e "\n📦 Estado completo de pods:"
      kubectl get pods -A -o wide
      ;;
    3)
      echo -e "\n⏳ Listando pods en estado Pending:"
      kubectl get pods --all-namespaces --field-selector=status.phase=Pending || echo -e "${GREEN}✅ No hay pods en Pending${NC}"
      ;;
    4)
      echo -e "\n🔍 Buscando pods en CrashLoopBackOff:"
      pods=$(kubectl get pods --all-namespaces -o json \
        | jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason=="CrashLoopBackOff") | "\(.metadata.namespace) \(.metadata.name)"')

      if [[ -z "$pods" ]]; then
        echo -e "${GREEN}✅ No hay pods en CrashLoopBackOff${NC}"
      else
        echo "$pods" | while read -r ns pod; do
          echo -e "\n📄 Logs del pod ${RED}$pod${NC} en ns ${RED}$ns${NC}:"
          kubectl logs -n "$ns" "$pod" --tail=20 --all-containers
        done
      fi
      ;;
    5)
      echo -e "\n💾 Listando PVCs con problemas:"
      kubectl get pvc --all-namespaces | grep -Ev 'Bound|NAME' || echo -e "${GREEN}✅ Todos los PVCs están Bound${NC}"
      ;;
    6)
      echo -e "\n📋 Últimos eventos del cluster:"
      kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | tail -n 30
      ;;
    7)
      echo -e "\n🖥️  Estado de nodos:"
      kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[-1].type" --no-headers \
        | while read -r name status; do
            if [[ "$status" == "Ready" ]]; then
              echo -e "${GREEN}$name\t$status${NC}"
            else
              echo -e "${RED}$name\t$status${NC}"
            fi
          done
      ;;
    8)
      echo -e "\n📊 Uso de CPU por nodo:"
      kubectl top nodes | sort -k3 -rh
      ;;
    9)
      echo -e "\n📈 Uso de memoria por nodo:"
      kubectl top nodes | sort -k5 -rh
      ;;
    10)
      echo -e "\n💾 Chequeando PVCs en Pending y StorageClasses:"
      echo -e "\n🔹 PVCs en Pending:"
      kubectl get pvc -A --field-selector=status.phase=Pending || echo -e "${GREEN}✅ No hay PVCs en Pending${NC}"

      echo -e "\n🔹 StorageClasses sin provisioner:"
      kubectl get storageclass -o wide | awk '$2=="" {print}' || echo -e "${GREEN}✅ Todas las StorageClasses tienen provisioner${NC}"
      ;;
    11)
      echo "👋 Hasta la vista..."
      exit 0
      ;;
    *)
      echo "❌ Opción inválida. Probá de nuevo."
      ;;
  esac
done
