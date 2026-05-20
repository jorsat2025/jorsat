#!/usr/bin/env bash
set -euo pipefail

echo "=== eBPF Toolkit Installer para Debian 12 ==="

if [[ $EUID -ne 0 ]]; then
  echo "Ejecutá como root: sudo bash install-ebpf-debian12.sh"
  exit 1
fi

echo "[1/8] Detectando sistema..."
. /etc/os-release

echo "OS: ${PRETTY_NAME}"
echo "Kernel: $(uname -r)"

if [[ "${ID}" != "debian" ]]; then
  echo "Aviso: esto está pensado para Debian 12. Continúo igual..."
fi

echo "[2/8] Actualizando paquetes..."
apt update

echo "[3/8] Instalando herramientas base..."
apt install -y \
  curl \
  gnupg \
  ca-certificates \
  lsb-release \
  apt-transport-https \
  dialog

echo "[4/8] Instalando herramientas eBPF/BCC..."
apt install -y \
  bpftool \
  bpfcc-tools \
  python3-bpfcc \
  libbpfcc \
  bpftrace \
  linux-perf \
  linux-headers-$(uname -r) || true

echo "[5/8] Verificando headers..."
if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
  echo "WARNING: No encontré headers exactos para el kernel $(uname -r)."
  echo "Algunas herramientas BCC/Falco podrían fallar."
fi

echo "[6/8] Agregando repo oficial de Falco..."
install -d -m 0755 /usr/share/keyrings

curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
  | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
  > /etc/apt/sources.list.d/falcosecurity.list

apt update

echo "[7/8] Instalando Falco..."
apt install -y falco

echo "[8/8] Habilitando Falco..."
systemctl enable falco || true
systemctl restart falco || true

echo
echo "=== Validaciones ==="
echo "bpftool:"
bpftool version || true

echo
echo "bpftrace:"
bpftrace --version || true

echo
echo "Falco:"
falco --version || true

echo
echo "Servicio Falco:"
systemctl --no-pager status falco || true

echo
echo "=== Instalación terminada ==="
echo
echo "Pruebas recomendadas:"
echo "  sudo execsnoop-bpfcc"
echo "  sudo tcpconnect-bpfcc"
echo "  sudo opensnoop-bpfcc"
echo "  sudo journalctl -fu falco"