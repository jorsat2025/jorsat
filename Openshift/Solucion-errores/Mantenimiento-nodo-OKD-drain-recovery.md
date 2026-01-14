# Mantenimiento y recuperación de nodo en OKD

## 1. Marcar el nodo como *Unschedulable*
Se evita que el scheduler asigne nuevos pods al nodo.

```bash
oc adm cordon master2.gsve.locals
```

---

## 2. Retirar el nodo del clúster (Drain)
Se drenan los workloads existentes del nodo.

```bash
oc adm drain master2.gsve.locals \
  --force=true --ignore-daemonsets --delete-emptydir-data --timeout=60s
```

---

## 3. Ingresar al nodo en falla

```bash
ssh -l core master2.gsve.locals
```

Elevar privilegios:

```bash
sudo -i
```

---

## 4. Detener servicios de Kubernetes

```bash
systemctl stop kubelet
```

---

## 5. Detener pods y contenedores

### Detener todos los pods
```bash
crictl stopp `crictl pods -q`
```

### Detener todos los contenedores
```bash
crictl stop `crictl ps -aq`
```

---

## 6. Eliminar pods detenidos

```bash
crictl rmp `crictl pods -q`
crictl rmp --force `crictl pods -q`
```

---

## 7. Reinicializar CRI-O y limpiar contenedores

```bash
systemctl stop crio
rm -rf /var/lib/containers/*
crio wipe -f
```

---

## 8. Levantar servicios

```bash
systemctl start crio
systemctl start kubelet
```

---

## Resultado esperado
- El nodo queda limpio de pods y contenedores corruptos.
- kubelet y CRI-O inician correctamente.
- El nodo puede reincorporarse al clúster luego del *uncordon*.

---

## Nota
Este procedimiento es **destructivo a nivel de contenedores locales**.  
Usar únicamente en nodos con fallas graves.
