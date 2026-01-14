# OKD / OpenShift 4.18 – Troubleshooting vSphere CSI Datastore

## Contexto
Cluster **OKD 4.18** sobre **vSphere** con el operador **vmware-vsphere-csi-driver** en estado **Degraded**.

Error recurrente:
```
VMwareVSphereController reconciliation failed:
unable to fetch default datastore url: datastore not found
```

---

## Síntoma
El ClusterOperator `storage` permanece en estado:
- `Available=True`
- `Degraded=True`

Aunque:
- El datastore existe
- El usuario `openshift4@vsphere.local` tiene permisos
- El nombre del datastore es correcto

---

## Causa raíz (IMPORTANTÍSIMO)

El **vSphere CSI NO usa solo el nombre del datastore**, sino su **Inventory Path completo**.

Ejemplo **incorrecto**:
```
/jorsat-IT/datastore/DS-DESA01-123-L003
```

Ejemplo **correcto**:
```
/jorsat-IT/datastore/OSDS-DESA01/DS-Cluster-DESA01-HUA/DS-DESA01-123-L003
```

El CSI intenta resolver el datastore por jerarquía de carpetas, no por nombre plano.

---

## Cómo obtener el Inventory Path correcto (PowerCLI)

```powershell
$dcName = "jorsat-IT"
$dsName = "DS-DESA01-123-L003"

$dsView = Get-View -Id (Get-Datastore -Name $dsName).Id
$names = @($dsView.Name)

$parent = Get-View -Id $dsView.Parent
while ($parent -and $parent.Name -ne "datastore") {
  $names = ,$parent.Name + $names
  $parent = Get-View -Id $parent.Parent
}

"/$dcName/datastore/" + ($names -join "/")
```

Salida esperada:
```
/jorsat-IT/datastore/OSDS-DESA01/DS-Cluster-DESA01-HUA/DS-DESA01-123-L003
```

---

## Patch correcto en OKD / OpenShift

```bash
oc patch infrastructure cluster --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/platformSpec/vsphere/failureDomains/0/topology/datastore",
    "value": "/jorsat-IT/datastore/OSDS-DESA01/DS-Cluster-DESA01-HUA/DS-DESA01-123-L003"
  }
]'
```

---

## Reinicio del controlador CSI

```bash
oc -n openshift-cluster-csi-drivers rollout restart \
  deploy/vmware-vsphere-csi-driver-controller
```

---

## Validaciones

### 1. Verificar infraestructura
```bash
oc get infrastructure cluster -o jsonpath='{.spec.platformSpec.vsphere.failureDomains[0].topology.datastore}'
```

### 2. Verificar operador storage
```bash
oc get co storage
```

Estado esperado:
```
Available=True
Progressing=False
Degraded=False
```

---

## Logs útiles

```bash
oc -n openshift-cluster-csi-drivers logs \
  deploy/vmware-vsphere-csi-driver-controller \
  | egrep -i 'datastore|permission|not found|error'
```

---

## Conclusión

✔ El problema **NO era permisos**
✔ El problema **NO era el nombre del datastore**
✔ El problema era **el Inventory Path incompleto**

Este es un **caso clásico de vSphere CSI** y suele confundir incluso a equipos senior.

---

## Recomendaciones

- Siempre validar `InventoryPath`, no solo `Name`
- Documentar el path exacto usado en `install-config.yaml`
- Guardar este procedimiento como runbook

---

Autor: Operación OKD / vSphere
Fecha: 2026-01-14

