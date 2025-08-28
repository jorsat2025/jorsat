#!/usr/bin/env bash
# post-install.sh - MetalLB + StorageClass default + tests (10.10.100.0/25)
set -euo pipefail
POOL_RANGE="${POOL_RANGE:-10.10.100.110-10.10.100.119}"
SC_DEFAULT="${SC_DEFAULT:-local-path}"
TIMEOUT="${TIMEOUT:-600}"
RUN_TESTS="${RUN_TESTS:-true}"
hr(){ printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '-'; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta '$1'"; exit 1; }; }
wait_rollout(){ ns="$1"; kind="$2"; name="$3"; to="${4:-300}"; echo "Esperando $kind/$name ($ns)..."; kubectl -n "$ns" rollout status "$kind/$name" --timeout="${to}s" || echo "WARN timeout"; }
wait_condition(){ cmd="$1"; msg="$2"; to="${3:-300}"; echo "Esperando: $msg"; s=$(date +%s); while true; do bash -c "$cmd" >/dev/null 2>&1 && { echo "OK: $msg"; break; }; sleep 5; now=$(date +%s); (( now - s > to )) && { echo "WARN: timeout $msg"; break; }; done; }
echo "== post-install MetalLB + StorageClass (pool: ${POOL_RANGE}) =="
need kubectl; hr
kubectl config current-context || true
kubectl get nodes -o wide || true
hr
echo "Chequeando Calico..."
if kubectl -n kube-system get ds calico-node >/dev/null 2>&1; then
  wait_rollout kube-system ds calico-node "$TIMEOUT"
fi
wait_condition "[ \$(kubectl get nodes --no-headers 2>/dev/null | awk '/ Ready /{c++} END{print c+0}') -ge 3 ]" ">= 3 nodos Ready" "$TIMEOUT"
hr
echo "Instalando/actualizando MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
wait_rollout metallb-system deploy controller 300
wait_condition "[ \$(kubectl -n metallb-system get pods -l app=metallb,component=speaker --no-headers 2>/dev/null | awk '/Running/{c++} END{print c+0}') -ge 1 ]" "speaker corriendo" 300
echo "Aplicando IPAddressPool y L2Advertisement..."
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
kubectl -n metallb-system get l2advertisements.metallb-system || true
hr
echo "Instalando StorageClass default (local-path)..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' || true
kubectl get storageclass
hr
if [[ "${RUN_TESTS}" == "true" ]]; then
  echo "== Tests =="
  echo "[LB] Deploy echo + Service LoadBalancer"
  kubectl create deploy echo --image=hashicorp/http-echo --port=5678 -- -text="hola JLB desde MetalLB" 2>/dev/null || true
  kubectl expose deploy echo --type=LoadBalancer --port=80 --target-port=5678 2>/dev/null || true
  echo "Esperando EXTERNAL-IP..."
  start=$(date +%s); EXTERNAL_IP=""
  while true; do
    EXTERNAL_IP="$(kubectl get svc echo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    [[ -n "$EXTERNAL_IP" ]] && break
    sleep 3; now=$(date +%s); (( now - start > 300 )) && { echo "WARN: sin EXTERNAL-IP"; break; }
  done
  [[ -n "$EXTERNAL_IP" ]] && echo "EXTERNAL-IP: $EXTERNAL_IP"
  echo "[PVC] Creando PVC + Pod de prueba"
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
    persistentVolumeClaim:
      claimName: test-pvc
YAML
  for i in {1..60}; do
    phase="$(kubectl get pvc test-pvc -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ "$phase" == "Bound" ]] && break
    sleep 3
  done
  for i in {1..60}; do
    phase="$(kubectl get pod test-pod -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ "$phase" == "Succeeded" || "$phase" == "Running" ]] && break
    sleep 3
  done
  echo "Logs test-pod:"; kubectl logs test-pod || true
fi
echo "== RESUMEN =="
echo "MetalLB pool: ${POOL_RANGE}"
echo "StorageClass default: ${SC_DEFAULT}"
echo "Tests: svc echo (LB), pvc test-pvc, pod test-pod (limpiar con: kubectl delete svc echo deploy echo pvc test-pvc pod test-pod --ignore-not-found)"
echo "✅ Post-install terminado."
