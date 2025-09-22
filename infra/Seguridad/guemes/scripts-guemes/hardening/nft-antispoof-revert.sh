#!/usr/bin/env bash
set -euo pipefail

del() {
  local fam="$1" tab="$2"
  if nft list table "$fam" "$tab" >/dev/null 2>&1; then
    echo "Borrando table $fam $tab…"
    nft delete table "$fam" "$tab"
    echo "OK"
  else
    echo "Table $fam $tab no existe (nada que hacer)."
  fi
}

del inet  antispoof
del netdev l2guard

echo "✅ Reversión completa."
