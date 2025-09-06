sudo tee /root/purge-blends.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Limpia metapaquetes de Debian Pure Blends si están instalados
# Blends cubiertas: Edu, Med, Science, GIS, Astro, Junior
# Uso:
#   /root/purge-blends.sh          -> purga
#   /root/purge-blends.sh --dry    -> sólo mostrar lo que borraría

DRY=0
[[ "${1:-}" == "--dry" ]] && DRY=1

echo "==> Detectando blends instaladas…"
mapfile -t BLENDS < <(dpkg-query -W -f='${Package}\n' \
  | grep -E '^(debian-(edu|med|science|gis|astro|junior))' || true)

if (( ${#BLENDS[@]} == 0 )); then
  echo "✔ No se detectaron metapaquetes de blends instalados."
  exit 0
fi

echo "Se detectaron estos metapaquetes:"
printf '  - %s\n' "${BLENDS[@]}"

if (( DRY )); then
  echo
  echo "Modo --dry: no se purga nada. Fin."
  exit 0
fi

echo
echo "==> Purgando metapaquetes de blends…"
apt-get update -y
apt-get purge -y "${BLENDS[@]}"

echo
echo "==> Autoremove + limpieza de dependencias huérfanas…"
apt-get autoremove -y --purge

echo
echo "==> Purgando archivos de configuración residuales (estado rc)…"
RC_PKGS=$(dpkg -l | awk '/^rc/ {print $2}')
if [[ -n "${RC_PKGS}" ]]; then
  echo "${RC_PKGS}" | xargs -r dpkg --purge
else
  echo "No hay paquetes en estado rc."
fi

echo
echo "==> Limpieza de caché apt…"
apt-get autoclean -y || true
apt-get clean -y || true

echo
echo "==> Resumen:"
echo "Blends purgadas:"
printf '  - %s\n' "${BLENDS[@]}"
echo "Listo. Si se retiraron muchos paquetes, considerá un reboot."
EOF

sudo chmod +x /root/purge-blends.sh
