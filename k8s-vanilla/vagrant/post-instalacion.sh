#!/usr/bin/env bash
# post-install.sh - Configura MetalLB + StorageClass default y corre tests
# Requisitos: kubectl con contexto del cluster (ej. en m1 como vagrant)

set -euo pipefail

# ======== PARAMETROS ========
POOL_RANGE="${POOL_RANGE:-10.10.100.110-10.10.100.119}"  # Cambiá con: POOL_RANGE=10.10.100.115-10.10.100.125 ./post-install.sh
SC_DEFAULT="${SC_DEFAULT:-local-path}"
TIMEOUT="${TIMEOUT:-600}"  # segundos (10 min) para esperas largas
RUN_TESTS="${RUN_TESTS:-true}"  # poné false para saltear tests: RUN_TESTS=false ./post-install.sh
# ===========================

hr(){ printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '-'; }

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta el comando '$1' en PATH"; exit 1; }
}

wait_rollout() {
  local ns="$1" kind="$2" name="$3" to="${4:-300}"
  echo "Esperando rollout de $kind/$name en $ns (timeout ${to}s)..."
  if ! kubectl -n "$ns" rollout status "$kind/$name" --timeout="${to}s"; then
    echo "WARN: Timeout esperando $kind/$name (continuo)..."
  fi
}

wait_condition(){
  # uso: wait_condition "comando" "mensaje" timeout
  local cmd="$1" msg="$2" to="${3:-300}"
  echo "Esperando: $msg (timeout ${to}s)..."
  local start=$(date +%s)
  while true; do
    if bash -c "$cmd" >/dev/null 2>&1; then
      echo "OK: $msg"
      break
    fi
    sleep 5
    local now=$(date +%s)
    (( now - start > to )) && { echo "WARN: Timeout en '$msg'"; break; }
  done
}

echo "== post-install MetalLB + StorageClass (pool: ${POOL_RANGE}) =="
need kubectl
hr

echo "Contexto actual:"
kubectl config current-context || true
kubectl get nodes -o wide || true
hr

# 1) Esperar red lista (Calico)
echo "Chequeando que Calico esté listo..."
if kubectl -n kube-system get ds calico-node >/dev/null 2>&1; then
  wait_rollout kube-system ds calico-node "$TIMEOUT"
else
  echo "WARN: No encontré DaemonSet calico-node; continúo de todos modos."
fi
# Esperar al menos 3 nodos Ready
wait_condition "[ \$(kubectl get nodes --no-headers 2>/dev/null | awk '/ Ready /{c++} END{print c+0}') -ge 3 ]" ">= 3 nodos Ready" "$TIMEOUT"
hr

# 2) MetalLB
echo "Instalando/actualizando MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
wait_rollout metallb-system deploy controller 300
# speaker es DaemonSet
if kubectl -n metallb-system get ds speaker >/dev/null 2>&1; then
  echo "Esperando speaker..."
  # No siempre 'rollout status' funciona en DS antiguos; hacemos verificación por pods
  wait_condition "[ \$(kubectl -n metallb-system get pods -l app=metallb,component=speaker --no-headers 2>/dev/null | awk '/Running/{c++} END{print c+0}') -ge 1 ]" "speaker corriendo" 300
fi

echo "Aplicando IPAddressPool y L2Advertisement (rango: ${POOL_RANGE})..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: pool-lan
  namespace: metallb-system
spec:
  addresses:
  - ${POOL_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: adv-lan
  namespace: metallb-system
spec:
  ipAddressPools:
  - pool-lan
EOF

kubectl -n metallb-system get ipaddresspools.metallb.io
kubectl -n metallb-system get l2advertisements.metallb.io
hr

# 3) StorageClass default (local-path)
echo "Instalando StorageClass 'local-path' (default)..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' || true
kubectl get storageclass
hr

if [[ "${RUN_TESTS}" == "true" ]]; then
  echo "== Corriendo tests de verificación =="

  # 4) Test de LoadBalancer
  echo "[Test LB] Desplegando echo y Service tipo LoadBalancer..."
  kubectl create deploy echo --image=hashicorp/http-echo --port=5678 -- -text="hola JLB desde MetalLB" 2>/dev/null || true
  kubectl expose deploy echo --type=LoadBalancer --port=80 --target-port=5678 2>/dev/null || true

  echo "Esperando EXTERNAL-IP asignada por MetalLB..."
  start=$(date +%s)
  EXTERNAL_IP=""
  while true; do
    EXTERNAL_IP="$(kubectl get svc echo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    [[ -n "$EXTERNAL_IP" ]] && break
    sleep 3
    now=$(date +%s); (( now - start > 300 )) && { echo "WARN: No se obtuvo EXTERNAL-IP en 300s"; break; }
  done

  if [[ -n "$EXTERNAL_IP" ]]; then
    echo "EXTERNAL-IP asignada: $EXTERNAL_IP"
    if command -v curl >/dev/null 2>&1; then
      echo "Probando http://${EXTERNAL_IP} ..."
      set +e
      curl -sS --max-time 5 "http://${EXTERNAL_IP}" || true
      set -e
    fi
  else
    echo "Sugerencia: revisá 'kubectl -n metallb-system logs deploy/controller'"
  fi
  hr

  # 5) Test de PVC
  echo "[Test PVC] Creando PVC y Pod de prueba..."
  cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests: {storage: 1Gi}
  storageClassName: local-path
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  restartPolicy: Never
  containers:
  - name: c
    image: busybox
    command: ["sh","-c","echo 'storage OK' > /data/ok && ls -l /data && sleep 5"]
    volumeMounts:
    - name: v
      mountPath: /data
  volumes:
  - name: v
    persistentVolumeClaim:s
      claimName: test-pvc
YAML

  wait_condition "[ \$(kubectl get pvc test-pvc -o jsonpath='{.status.phase}' 2>/dev/null) = Bound ]" "PVC test-pvc en estado Bound" 180
  # Esperar a que el Pod termine (Completed) o Running
  wait_condition "[ \$(kubectl get pod test-pod -o jsonpath='{.status.phase}' 2>/dev/null) = Succeeded ] || [ \$(kubectl get pod test-pod -o jsonpath='{.status.phase}' 2>/dev/null) = Running ]" "Pod test-pod en Running/Succeeded" 180

  echo "Logs de test-pod:"
  kubectl logs test-pod || true
  hr
fi

echo "== RESUMEN =="
echo "MetalLB instalado con pool: ${POOL_RANGE}"
echo "StorageClass default: ${SC_DEFAULT} (local-path)"
if [[ "${RUN_TESTS}" == "true" ]]; then
  echo "Tests creados: deploy/svc 'echo', pvc 'test-pvc', pod 'test-pod'"
  echo "Para limpiar tests:"
  echo "  kubectl delete svc echo deploy echo pvc test-pvc pod test-pod --ignore-not-found"
fi
echo "✅ Post-install terminado."
