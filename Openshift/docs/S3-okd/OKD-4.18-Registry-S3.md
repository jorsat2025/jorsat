# OKD 4.18 – Uso de OpenShift Internal Registry con Backend S3 (Claro)

## ✨ Objetivo

Configurar la **image-registry** en **OKD 4.18** para que utilice un **bucket S3** como backend de almacenamiento, validar su correcto funcionamiento y probarlo mediante una build personalizada.

---

## 1. ⚙️ Configuración del bucket S3

### ✅ Requisitos previos

- Bucket S3 llamado **lom-mutt**
- Accesible vía:
  ```
  http://s3hua.claro.amx
  ```
- AccessKey y SecretKey configurados como **Secret** en OpenShift:

```bash
oc -n openshift-image-registry create secret generic image-registry-private-configuration-user \
  --from-literal=REGISTRY_STORAGE_S3_ACCESSKEY=QzVBNTBDMzI2QUNCN0IzQTgzRUY= \
  --from-literal=REGISTRY_STORAGE_S3_SECRETKEY=eWJkYTFCbWk0aXNNRFVRZno0TXFwNnRLckZBQUFBR1hhc3Q3T3NJbw== \
  --from-literal=REGISTRY_STORAGE_S3_SECURE=false
```

---

### 🧹 (Opcional) Eliminar PVC antiguo

```bash
oc delete pvc -n openshift-image-registry image-registry-storage
```

⚠️ Ejecutar solo si no se necesitan imágenes previas.

---

### ✅ Patch al config de la registry

```bash
oc patch configs.imageregistry.operator.openshift.io cluster \
  --type=merge -p '{
    "spec": {
      "managementState": "Managed",
      "storage": {
        "s3": {
          "bucket": "lom-mutt",
          "region": "us-east-1",
          "regionEndpoint": "http://s3hua.claro.amx",
          "encrypt": false,
          "virtualHostedStyle": false
        }
      }
    }
  }'
```

---

## 2. 🚀 Validar que la Registry esté funcionando

```bash
oc get clusteroperator image-registry
oc get pods -n openshift-image-registry
```

---

## 3. 🌍 Acceso externo a la registry

```bash
oc get route -n openshift-image-registry
```

---

## 4. 🏠 Crear una app para validar uso de la registry

### Crear proyecto y build

```bash
oc new-project test-registry
oc new-build --binary --name=demo-nginx --image-stream=nginx
```

### Crear contenido

```bash
mkdir web-content
echo "<h1>Hola desde OpenShift Registry</h1>" > web-content/index.html
```

### Lanzar build

```bash
oc start-build demo-nginx --from-dir=web-content --follow
```

---

## 5. 🌐 Desplegar y probar la app

```bash
oc new-app demo-nginx
oc expose service demo-nginx
oc get route demo-nginx
```

Acceder vía navegador y validar el contenido.

---

## ✅ Confirmación

```bash
oc get is -n test-registry
```

---

## 🚀 Conclusión

La registry interna de OKD 4.18 funciona correctamente utilizando un backend S3 personalizado, aceptando builds y sirviendo imágenes sin inconvenientes.
