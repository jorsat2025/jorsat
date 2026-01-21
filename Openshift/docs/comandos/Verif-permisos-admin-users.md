## 3.1 Permisos globales (equivalente a cluster-admin)

```bash
oc auth can-i '*' '*' --all-namespaces \
  --as=EXA67846 \
  --as-group=oseinfrait01-Admin
```

---

## 3.2 Permisos críticos para Apigee hybrid

```bash
oc auth can-i create customresourcedefinitions \
  --as=EXA67846 \
  --as-group=oseinfrait01-Admin
```

```bash
oc auth can-i create clusterroles \
  --as=EXA67846 \
  --as-group=oseinfrait01-Admin
```

```bash
oc auth can-i create clusterrolebindings \
  --as=EXA67846 \
  --as-group=oseinfrait01-Admin
```

```bash
oc auth can-i create validatingwebhookconfigurations \
  --as=EXA67846 \
  --as-group=oseinfrait01-Admin
```

```bash
oc auth can-i create mutatingwebhookconfigurations \
  --as=EXA67846 \
  --as-group=oseinfrait01-Admin
```

---

## 4. Verificación estructural (opcional, pero clara)

```bash
oc describe clusterrolebinding cluster-admin-0
```

---

## 5. Prueba final (solo si EXA67846 puede loguearse)

Si podés iniciar sesión directamente como **EXA67846** (UI o `oc login`):

```bash
oc whoami
oc auth can-i '*' '*' --all-namespaces
oc auth can-i create customresourcedefinitions
```
