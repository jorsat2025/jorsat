#!/usr/bin/env bash
set -euo pipefail

# purge-coredumps.sh (versión simple)
# - Dry-run por defecto (no borra sin confirmar salvo --yes)
# - Filtra por antigüedad (--days N)
# - Valida con `file` cuando se puede
# - Busca en rutas típicas y evita pseudo FS

DAYS=0
ASSUME_YES=0
QUIET=0

usage() {
  cat <<'USAGE'
Uso: purge-coredumps.sh [opciones]
  --days N   Borra solo core dumps con más de N días (default 0)
  --yes      Borra sin preguntar (no-interactivo)
  --quiet    Menos salida
  --help     Muestra esta ayuda
Ejemplos:
  purge-coredumps.sh
  purge-coredumps.sh --days 7
  purge-coredumps.sh --yes
  purge-coredumps.sh --days 30 --yes
USAGE
}

log() { [[ $QUIET -eq 1 ]] || echo -e "$*"; }
err() { echo -e "$*" >&2; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Este script debe ejecutarse como root."
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  if [[ $ASSUME_YES -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

is_core_file() {
  local f="$1"
  if command -v file >/dev/null 2>&1; then
    local out
    out=$(file -b "$f" 2>/dev/null || true)
    if grep -qiE 'core file' <<<"$out"; then
      return 0
    fi
    if [[ "$f" =~ /var/lib/systemd/coredump/ ]] && [[ "$f" =~ \.(zst|lz4)$ ]]; then
      return 0
    fi
  else
    if [[ "$f" =~ /var/lib/systemd/coredump/ ]] || [[ "$f" =~ /var/crash/ ]]; then
      return 0
    fi
    if [[ "$(basename "$f")" =~ ^core(\.[0-9]+)?$ || "$f" =~ \.coredump(\.(zst|lz4))?$ ]]; then
      return 0
    fi
  fi
  return 1
}

size_bytes() { stat -c '%s' "$1" 2>/dev/null || echo 0; }

human() {
  local b=$1 u=(B KB MB GB TB PB) i=0
  while (( b>=1024 && i<${#u[@]}-1 )); do b=$((b/1024)); i=$((i+1)); done
  printf "%d %s" "$b" "${u[$i]}"
}

gather_candidates() {
  local days="$1"
  # Buscamos en rutas típicas y evitamos pseudo FS. Sin arrays complicadas ni paréntesis raros.
  # 1) systemd-coredump y crash
  find /var/lib/systemd/coredump /var/crash -xdev -type f -mtime +"$days" \
    \( -name 'core' -o -name 'core.*' -o -name '*.core' -o -name '*.coredump' -o -name '*.zst' -o -name '*.lz4' \) 2>/dev/null || true
  # 2) Raíz, excluyendo pseudo FS comunes
  find / -xdev \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /snap -o -path /boot/efi \) -prune -o \
    -type f -mtime +"$days" \
    \( -name 'core' -o -name 'core.*' -o -name '*.core' -o -name '*.coredump' -o -name '*.zst' -o -name '*.lz4' \) -print 2>/dev/null || true
}

main() {
  require_root

  # Flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days) DAYS="${2:-0}"; shift 2 ;;
      --yes) ASSUME_YES=1; shift ;;
      --quiet) QUIET=1; shift ;;
      --help|-h) usage; exit 0 ;;
      *) err "Opción desconocida: $1"; usage; exit 2 ;;
    esac
  done

  log "🔎 Buscando core dumps (> ${DAYS} día/s)…"

  # Recolectar candidatos (únicos)
  mapfile -t CANDS < <(gather_candidates "$DAYS" | sort -u)

  declare -a TO_DELETE=()
  TOTAL=0
  for f in "${CANDS[@]}"; do
    [[ -f "$f" ]] || continue
    if is_core_file "$f"; then
      sz=$(size_bytes "$f")
      TOTAL=$((TOTAL + sz))
      TO_DELETE+=("$f")
      log "  • $f ($(human "$sz"))"
    fi
  done

  local count=${#TO_DELETE[@]}
  if (( count == 0 )); then
    log "✅ No se encontraron core dumps que cumplan el criterio."
    exit 0
  fi

  log "\nSe encontraron $count archivo(s), total estimado: $(human "$TOTAL")."

  if ! confirm "¿Eliminar ahora?"; then
    log "ℹ️ Modo dry-run: no se borró nada."
    exit 0
  fi

  local del=0 freed=0
  for f in "${TO_DELETE[@]}"; do
    if [[ -f "$f" ]]; then
      sz=$(size_bytes "$f")
      rm -f -- "$f" && { del=$((del+1)); freed=$((freed+sz)); log "🗑️  borrado: $f"; }
    fi
  done

  # Limpieza opcional del journal persistente
  if [[ -d /var/log/journal ]] && command -v journalctl >/dev/null 2>&1; then
    log "\n🧹 Journal persistente detectado. Limpieza opcional."
    if confirm "¿Vaciar entradas del journal más antiguas de ${DAYS} día/s?"; then
      journalctl --vacuum-time="${DAYS}d" || true
    fi
  fi

  log "\n✅ Eliminación completa: $del archivo(s), liberado: $(human "$freed"))."
}

main "$@"
