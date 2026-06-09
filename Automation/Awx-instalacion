# 🚀 Guía Rápida: Instalación de AWX y Solución de Errores

Esta guía contiene el paso a paso real que ejecutamos en el servidor, con los comandos limpios y las soluciones a los errores más comunes para dejar el clúster funcionando correctamente.

---

# 1. Solución al Instalador de Discos (Ubuntu Server)

Si el botón **"Hecho" (Done)** aparece deshabilitado y muestra el mensaje:

> **"To continue you need to: Select a boot disk"**

seguí estos pasos:

1. Bajá con las flechas del teclado hasta la sección **DISPOSITIVOS UTILIZADOS**.
2. Seleccioná el disco físico de **60 GB**.
3. Presioná **Enter** o **Espacio**.
4. Elegí la opción **Use as Boot Device**.

El mensaje desaparecerá y podrás continuar con la instalación.

---

# 2. Instalación de Dependencias y Kubernetes (K3s)

Ejecutar como **root**:

```bash
# Actualizar el sistema
apt update && apt upgrade -y

# Instalar herramientas básicas
apt install -y curl git jq

# Instalar K3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Instalar Kustomize
curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
mv kustomize /usr/local/bin/

# Clonar el repositorio oficial del operador AWX
git clone https://github.com/ansible/awx-operator.git

cd awx-operator

# Cambiar a la versión estable
git checkout 2.19.1

# Crear el namespace
export NAMESPACE=awx
kubectl create namespace $NAMESPACE

# Instalar el operador
make deploy
```
