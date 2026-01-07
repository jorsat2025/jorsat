# Error de credenciales de OKD contra vCenter

## Síntoma
El clúster OKD presenta el operador de almacenamiento degradado debido a un error de autenticación contra vCenter.

Ejemplo del evento observado:

```yaml
- lastTransitionTime: '2024-01-11T14:26:03Z'
  message: >-
    VSphereCSIDriverOperatorCRDegraded: VMwareVSphereControllerDegraded:
    error logging into vcenter: ServerFaultCode: Cannot complete login due
    to an incorrect user name or password.
  reason: VSphereCSIDriverOperatorCR_VMwareVSphereController_SyncError
```

---

## Causa
Las credenciales configuradas para vCenter en el secret `vsphere-creds` del namespace `kube-system` son incorrectas.

---

## Resolución

### 1. Actualizar credenciales
Cambiar la contraseña en el secret `vsphere-creds` del namespace `kube-system` asegurando que el usuario y password sean válidos en vCenter.

---

### 2. Verificar las credenciales almacenadas

```bash
for data in $(oc get secret vsphere-creds -n kube-system -o json | jq -r '.data[]'); do
  echo $data | base64 -d
  echo
done
```

Verificar que el usuario y la contraseña sean correctos.

---

### 3. Forzar recreación del ClusterOperator Storage

```bash
oc delete co/storage
```

---

## Resultado esperado
- El operador `storage` vuelve a estado **Available**
- El CSI de vSphere se autentica correctamente contra vCenter
- El clúster queda operativo

---

## Observaciones
- Validar permisos del usuario de vCenter para operaciones CSI
- Verificar conectividad de red entre OKD y vCenter
