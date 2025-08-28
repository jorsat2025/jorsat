# Kubernetes HA (3 masters + 3 workers) con Vagrant + Hyper‑V (Windows 11)
**Red:** `10.10.100.0/25` (máscara `255.255.255.128`) – vSwitch externo **`net-vms`** (DHCP)  
**VIP (kube‑vip):** `10.10.100.120`  
**Pool MetalLB (L2):** `10.10.100.110–10.10.100.119`  
**SO invitado:** Ubuntu Server 22.04  
**CNI:** Calico  
**CRI:** containerd  
**Provisioner de Storage:** local‑path (default)  

> Recomendado: configurá **reservas DHCP** en tu router para las MAC de las VMs (al menos los masters).  
> Asegurate de que el **VIP** (`10.10.100.120`) y el **pool** de MetalLB **no estén** dentro del rango que entrega tu DHCP.

---

## 0) Prerrequisitos
- Windows 11 con **Hyper‑V** habilitado
- **Vagrant** instalado
- vSwitch **externo** ya creado y llamado **`net-vms`** (bridge a tu NIC física)
- Memoria recomendada: ~20–24 GB libres (podés bajar recursos si es necesario)

---

## 1) `Vagrantfile` (copiar/pegar)

> Solo ajustá el VIP si querés otro dentro de tu `/25`, y dejá `BRIDGE_SWITCH = "net-vms"`.

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # === AJUSTES DE TU RED ===
  VIP = "10.10.100.120"        # <-- IP libre en tu LAN (fuera del pool DHCP)
  BRIDGE_SWITCH = "net-vms"    # <-- vSwitch externo en Hyper-V
  POD_CIDR = "192.168.0.0/16"  # Calico

  MASTERS = [
    {name: "m1", mac: "00155D010011", cpus: 3, mem: 4096},
    {name: "m2", mac: "00155D010012", cpus: 3, mem: 4096},
    {name: "m3", mac: "00155D010013", cpus: 3, mem: 4096},
  ]
  WORKERS = [
    {name: "w1", mac: "00155D010021", cpus: 2, mem: 3584},
    {name: "w2", mac: "00155D010022", cpus: 2, mem: 3584},
    {name: "w3", mac: "00155D010023", cpus: 2, mem: 3584},
  ]

  # ---------- PROVISION COMÚN ----------
  COMMON = <<-SHELL
    set -euxo pipefail
    hostnamectl set-hostname $(cat /etc/hostname)
    sed -ri '/\\sswap\\s/s/^#?/#/' /etc/fstab || true
    swapoff -a || true

    modprobe overlay
    modprobe br_netfilter
    cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
    cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sysctl --system

    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq software-properties-common
    apt-get install -y containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl enable --now containerd

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF

    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    systemctl enable kubelet
  SHELL

  # ---------- kube-vip prep ----------
  KUBEVIP_PREP = <<-SHELL
    set -euxo pipefail
    IFACE=$(ip route | awk '/default/ {print $5; exit}')
    echo "IFACE=${IFACE}" > /root/kubevip.env
    ctr --namespace k8s.io images pull ghcr.io/kube-vip/kube-vip:v0.8.0 || true
    cat > /root/kube-vip-rbac.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-vip
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:kube-vip-role
rules:
- apiGroups: [""]
  resources: ["services","services/status","endpoints","nodes","pods"]
  verbs: ["list","get","watch","update","patch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["list","get","watch","update","create","patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-vip-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-vip-role
subjects:
- kind: ServiceAccount
  name: kube-vip
  namespace: kube-system
EOF
  SHELL

  # ---------- MASTER 1 ----------
  MASTER1 = <<-SHELL
    set -euxo pipefail
    IFACE=$(awk -F= '/IFACE=/{print $2}' /root/kubevip.env)
    IPADDR=$(ip -o -4 addr show $IFACE | awk '{print $4}' | cut -d/ -f1)

    cat > /etc/kubernetes/manifests/kube-vip.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-vip
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-vip
    image: ghcr.io/kube-vip/kube-vip:v0.8.0
    args: ["manager"]
    env:
    - {name: vip_arp, value: "true"}
    - {name: address, value: "#{VIP}"}
    - {name: interface, value: "${IFACE}"}
    - {name: cp_enable, value: "true"}
    - {name: svc_enable, value: "false"}
    securityContext:
      capabilities:
        add: ["NET_ADMIN","NET_RAW","SYS_TIME"]
EOF

    kubeadm init --control-plane-endpoint="#{VIP}:6443" \
      --apiserver-advertise-address=${IPADDR} \
      --pod-network-cidr=#{POD_CIDR} \
      --cri-socket=unix:///run/containerd/containerd.sock

    mkdir -p ~vagrant/.kube
    cp /etc/kubernetes/admin.conf ~vagrant/.kube/config
    chown -R vagrant:vagrant ~vagrant/.kube

    su - vagrant -c "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml"
    su - vagrant -c "kubectl apply -f /root/kube-vip-rbac.yaml"

    kubeadm token create --ttl 0
    CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -1 | tr -d '\\n')
    JOIN_CMD=$(kubeadm token create --print-join-command)

    echo "${JOIN_CMD} --cri-socket unix:///run/containerd/containerd.sock --control-plane --certificate-key ${CERT_KEY}" > /root/join-master.sh
    echo "${JOIN_CMD} --cri-socket unix:///run/containerd/containerd.sock" > /root/join-worker.sh
    chmod +x /root/join-master.sh /root/join-worker.sh
  SHELL

  # ---------- MASTER 2/3 (join via VIP) ----------
  MASTER_JOIN = <<-SHELL
    set -euxo pipefail
    apt-get install -y sshpass
    IFACE=$(ip route | awk '/default/ {print $5; exit}')
    cat > /etc/kubernetes/manifests/kube-vip.yaml <<EOF
apiVersion: v1
kind: Pod
metadata: {name: kube-vip, namespace: kube-system}
spec:
  hostNetwork: true
  containers:
  - name: kube-vip
    image: ghcr.io/kube-vip/kube-vip:v0.8.0
    args: ["manager"]
    env:
    - {name: vip_arp, value: "true"}
    - {name: address, value: "#{VIP}"}
    - {name: interface, value: "${IFACE}"}
    - {name: cp_enable, value: "true"}
    - {name: svc_enable, value: "false"}
    securityContext:
      capabilities: {add: ["NET_ADMIN","NET_RAW","SYS_TIME"]}
EOF
    # Espera a que m1 cree join-master.sh y que el VIP esté activo
    for i in {1..60}; do
      if sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@#{VIP} 'test -f /root/join-master.sh'; then break; fi
      echo "Esperando join-master.sh en #{VIP} ..."; sleep 5
    end
    sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@#{VIP} 'sudo cat /root/join-master.sh' > /tmp/join.sh
    bash /tmp/join.sh

    mkdir -p ~vagrant/.kube
    sshpass -p vagrant scp -o StrictHostKeyChecking=no vagrant@#{VIP}:/home/vagrant/.kube/config ~vagrant/.kube/config
    chown -R vagrant:vagrant ~vagrant/.kube
  SHELL

  # ---------- WORKERS (join via VIP) ----------
  WORKER_JOIN = <<-SHELL
    set -euxo pipefail
    apt-get install -y sshpass
    for i in {1..60}; do
      if sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@#{VIP} 'test -f /root/join-worker.sh'; then break; fi
      echo "Esperando join-worker.sh en #{VIP} ..."; sleep 5
    done
    sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@#{VIP} 'sudo cat /root/join-worker.sh' > /tmp/join.sh
    bash /tmp/join.sh
  SHELL

  # ---------- Definición de VMs ----------
  (MASTERS + WORKERS).each do |n|
    config.vm.define n[:name] do |node|
      node.vm.hostname = n[:name]
      node.vm.network "public_network",
        bridge: BRIDGE_SWITCH,
        auto_config: true,
        hyperv__mac: n[:mac]

      node.vm.provider :hyperv do |h|
        h.cpus = n[:cpus]
        h.memory = n[:mem]
        h.vmname = n[:name]
        h.vm_integration_services = { guest_service_interface: true }
        h.enable_virtualization_extensions = true
      end

      node.vm.provision "shell", inline: COMMON
      node.vm.provision "shell", inline: KUBEVIP_PREP

      if n[:name] == "m1"
        node.vm.provision "shell", inline: MASTER1, run: "always"
      elsif ["m2","m3"].include?(n[:name])
        node.vm.provision "shell", inline: MASTER_JOIN, run: "always"
      else
        node.vm.provision "shell", inline: WORKER_JOIN, run: "always"
      end
    end
  end
end
```

---

## 2) Levantar el cluster

En PowerShell, dentro de la carpeta del `Vagrantfile`:
```powershell
$env:VAGRANT_DEFAULT_PROVIDER="hyperv"
vagrant up
```

> Cuando te pregunte el switch para `public_network`, elegí **net-vms**.

---

## 3) Verificar

Conectate al master `m1`:
```powershell
vagrant ssh m1
```
y dentro:
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Cuando Calico quede `Ready`, verás los 6 nodos listos.  
El API del cluster responde por **https://10.10.100.120:6443** (VIP).

---

## 4) Post‑install: MetalLB + StorageClass + tests

Guardá el siguiente script como `post-install.sh` en `m1` (o donde tengas `kubectl`), dale permisos y ejecutalo.

```bash
#!/usr/bin/env bash
# post-install.sh - Configura MetalLB + StorageClass default y corre tests para 10.10.100.0/25

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

  wait_condition "[ \$(kubectl get pvc test-pvc -o jsonpath='{.status.phase}' 2>/dev/null) = Bound ]" "PVC test-pvc Bound" 180
  wait_condition "[ \$(kubectl get pod test-pod -o jsonpath='{.status.phase}' 2>/dev/null) = Succeeded ] || [ \$(kubectl get pod test-pod -o jsonpath='{.status.phase}' 2>/dev/null) = Running ]" "Pod test-pod Running/Succeeded" 180
  echo "Logs test-pod:"; kubectl logs test-pod || true
  hr
fi

echo "== RESUMEN =="
echo "MetalLB pool: ${POOL_RANGE}"
echo "StorageClass default: ${SC_DEFAULT}"
echo "Tests: svc echo (LB), pvc test-pvc, pod test-pod (podés limpiar con: kubectl delete svc echo deploy echo pvc test-pvc pod test-pod --ignore-not-found)"
echo "✅ Post-install terminado."
```

**Uso:**
```bash
nano post-install.sh
chmod +x post-install.sh
./post-install.sh
# (Opcional) Cambiar rango sin editar archivo:
# POOL_RANGE=10.10.100.111-10.10.100.118 ./post-install.sh
```

---

## 5) Limpieza de recursos de prueba
```bash
kubectl delete svc echo deploy echo pvc test-pvc pod test-pod --ignore-not-found
```

---

## 6) Tips
- Si tu DHCP entrega direcciones que chocan con `10.10.100.110–119` o `10.10.100.120`, reconfigurá el pool/ VIP o reservá esos IPs para evitar colisiones.
- Para bajar consumo: reducí RAM (p.ej., masters 3GB, workers 2GB; o menos workers).
- Si ves issues de red (MTU), avisame y te paso el parche de Calico en dos líneas.
- Snapshots de VMs en Hyper‑V antes de toquetear cosas “heavy”.

¡Listo para usar! 🚀
