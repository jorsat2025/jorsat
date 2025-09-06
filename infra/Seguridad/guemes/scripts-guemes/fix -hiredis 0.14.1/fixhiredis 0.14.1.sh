sudo tee /root/fix-hiredis-suricata.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[+] Chequeando libhiredis requerida por Suricata…"
if ! ldd /opt/suricata/bin/suricata | grep -q 'libhiredis.so.0.14'; then
  echo "[i] El binario no parece requerir libhiredis.so.0.14 (o ldd no lo muestra). Igual continuamos."
fi

echo "[+] Verificando si ya existe /usr/local/lib/libhiredis.so.0.14…"
if [[ ! -e /usr/local/lib/libhiredis.so.0.14 ]]; then
  echo "[+] Compilando e instalando hiredis v0.14.1…"
  apt-get update
  apt-get install -y build-essential git

  work=/usr/src/hiredis-014
  rm -rf "$work"
  git clone https://github.com/redis/hiredis.git "$work"
  cd "$work"
  git checkout v0.14.1
  make -j"$(nproc)"
  make install   # instala libhiredis.so.0.14 en /usr/local/lib
fi

echo "[+] Asegurando que /usr/local/lib esté en el runtime loader…"
if ! grep -q '^/usr/local/lib$' /etc/ld.so.conf.d/local.conf 2>/dev/null; then
  echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf
fi
ldconfig

echo "[+] Probando Suricata (-V)…"
/opt/suricata/bin/suricata -V || {
  echo "[!] Suricata aún no arranca; mostrando dependencias faltantes:"
  ldd /opt/suricata/bin/suricata | grep -E "not found|=> .* not found" || true
  exit 1
}

echo "[+] Reintentando servicios Suricata q0/q1…"
systemctl daemon-reload
systemctl start suricata-q0.service || true
systemctl start suricata-q1.service || true

sleep 1
systemctl --no-pager -l status suricata-q0.service || true
systemctl --no-pager -l status suricata-q1.service || true

echo "[+] Journal último tramo (q0)…"
journalctl -u suricata-q0.service -n 80 -e || true

echo "[✓] Listo."
EOF
sudo bash /root/fix-hiredis-suricata.sh
