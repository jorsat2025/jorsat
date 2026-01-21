#!/usr/bin/env bash
set -euo pipefail

### ========= PARAMETROS (AJUSTAR) =========
ENV_NAME="prod"

# Namespaces
NS_SYSTEM="apigee-system"
NS_ENV="apigee-${ENV_NAME}"        # recomendado separar por entorno (prod/test/dec)

# Rutas/archivos locales (en el bastion)
APIGEE_BUNDLE_DIR="/opt/apigee/hybrid-helm"   # donde dejaste el bundle/Charts de Apigee
VALUES_FILE="/opt/apigee/values/values-${ENV_NAME}.yaml"
SECRETS_DIR="/opt/apigee/secrets/${ENV_NAME}" # yamls de Secrets (GCP SA, TLS, etc.)

# Charts (ajustar según el bundle real)
OPERATOR_CHART="${APIGEE_BUNDLE_DIR}/charts/apigee-operator"
RUNTIME_CHART="${APIGEE_BUNDLE_DIR}/charts/apigee-runtime"

# Releases Helm
REL_OPERATOR="apigee-operator"
REL_RUNTIME="apigee-runtime-${ENV_NAME}"

### ========= FUNCIONES =========
need() { command -v "$1" >/dev/null 2>&1 || { echo "Falta comando: $1"; exit 1; }; }

log() { echo "[$(date +'%F %T')] $*"; }

oc_can_i_or_die() {
  local verb="$1" resource="$2"
  if ! oc auth can-i "$verb" "$resource" --all-namespaces >/dev/null 2>&1; then
    echo "Permiso insuficiente: oc auth can-i $verb $resource --all-namespaces"
    exit 1
  fi
}

### ========= PREFLIGHT =========
need oc
need helm

log "Validando sesión OpenShift..."
oc whoami >/dev/null

log "Validando permisos críticos (cluster-wide)..."
oc_can_i_or_die create customresourcedefinitions
oc_can_i_or_die create clusterrolebindings
oc_can_i_or_die create validatingwebhookconfigurations

log "Validando Helm charts/values..."
test -d "$OPERATOR_CHART" || { echo "No existe OPERATOR_CHART: $OPERATOR_CHART"; exit 1; }
test -d "$RUNTIME_CHART"  || { echo "No existe RUNTIME_CHART: $RUNTIME_CHART"; exit 1; }
test -f "$VALUES_FILE"    || { echo "No existe VALUES_FILE: $VALUES_FILE"; exit 1; }

log "Validando cert-manager (CRDs)..."
if ! oc get crd | grep -q "certificates.cert-manager.io"; then
  echo "cert-manager NO detectado (CRDs faltantes). Instalar cert-manager antes de Apigee."
  echo "Sugerencia: instalar cert-manager via OperatorHub/OLM según estándar."
  exit 1
fi

### ========= NAMESPACES =========
log "Creando/validando namespaces..."
oc get ns "$NS_SYSTEM" >/dev/null 2>&1 || oc create ns "$NS_SYSTEM"
oc get ns "$NS_ENV"    >/dev/null 2>&1 || oc create ns "$NS_ENV"

### ========= SECRETS =========
log "Aplicando secretos (si existe directorio): $SECRETS_DIR"
if [ -d "$SECRETS_DIR" ]; then
  oc -n "$NS_ENV" apply -f "$SECRETS_DIR"
else
  log "WARN: No existe SECRETS_DIR, se omite apply. (Puede ser OK si gestionás secrets por GitOps/ExternalSecrets)"
fi

### ========= HELM: OPERATOR =========
log "Instalando/actualizando Operator (Helm) en $NS_SYSTEM ..."
helm upgrade --install "$REL_OPERATOR" "$OPERATOR_CHART" \
  -n "$NS_SYSTEM" \
  --create-namespace

log "Esperando pods del operator..."
oc -n "$NS_SYSTEM" rollout status deploy/"$REL_OPERATOR" --timeout=300s || true
oc -n "$NS_SYSTEM" get pods -o wide

### ========= HELM: RUNTIME =========
log "Instalando/actualizando Runtime (Helm) en $NS_ENV con values: $VALUES_FILE ..."
helm upgrade --install "$REL_RUNTIME" "$RUNTIME_CHART" \
  -n "$NS_ENV" \
  -f "$VALUES_FILE" \
  --create-namespace

log "Esperando recursos principales..."
oc -n "$NS_ENV" get pods -o wide
oc -n "$NS_ENV" get svc -o wide

log "Chequeo rápido de salud (pods no-ready):"
oc -n "$NS_ENV" get pods | awk 'NR==1 || $2 !~ $3'

log "Listo. Siguiente: validar conectividad con control plane y exposición ingress/route."
