# Kubernetes HA (3 masters + 3 workers) con Vagrant + Hyper‑V (Windows 11)
**LAN:** `10.10.100.0/25` (vSwitch externo `net-vms`, DHCP)
**VIP API (kube-vip):** `10.10.100.120`
**MetalLB (L2):** `10.10.100.110–10.10.100.119`
**Ubuntu 22.04**, **containerd**, **kubeadm**, **Calico** (CNI), **local-path** (StorageClass default)

Archivos:
- `Vagrantfile` (híbrido: net-vms por DHCP + red interna 192.168.56.x)
- `post-install.sh`
- `calico-mtu-auto.sh`

Levantar:
```powershell
$env:VAGRANT_DEFAULT_PROVIDER="hyperv"
vagrant up
```
Post‑install:
```bash
vagrant ssh m1
./post-install.sh
```
