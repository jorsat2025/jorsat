#!/usr/bin/env bash
set -euo pipefail

MANIFEST="consumer-apps.yaml"

if ! oc whoami >/dev/null 2>&1; then
  echo "oc CLI not logged in"; exit 1
fi

echo "[+] Applying ${MANIFEST}"
oc apply -f "${MANIFEST}"

echo "[+] Waiting for deployments to be Ready"
oc -n eso-demo rollout status deploy/demo-consumer-a || true
oc -n eso-webhook rollout status deploy/demo-consumer-b || true

echo "[+] Sample logs (last lines)"
echo "--- demo-consumer-a (eso-demo) ---"
oc -n eso-demo logs -l app=demo-consumer-a --tail=50 || true
echo "--- demo-consumer-b (eso-webhook) ---"
oc -n eso-webhook logs -l app=demo-consumer-b --tail=50 || true

cat <<'HINT'

[HINT] Para ver las variables in-container:
  oc -n eso-demo rsh deploy/demo-consumer-a env | egrep 'DB_USERNAME|DB_PASSWORD'
  oc -n eso-webhook rsh deploy/demo-consumer-b env | egrep 'PWD_VALUE'

[HINT] Para limpiar:
  oc -n eso-demo delete deploy demo-consumer-a --ignore-not-found
  oc -n eso-webhook delete deploy demo-consumer-b --ignore-not-found
HINT
