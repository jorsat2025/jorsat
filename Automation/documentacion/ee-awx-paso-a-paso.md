# 🚀 Construcción de un Execution Environment (EE) para AWX

## Introducción

El repositorio **Git no se usa directamente para que AWX ejecute el Execution Environment (EE)**.

Se utiliza únicamente como **fuente del código** para construir una **imagen Docker/OCI**, que luego será utilizada por AWX para ejecutar los Jobs.

---

# 📌 Flujo completo

```text
GitHub
│
└── Automation/
    └── EE/
        ├── execution-environment.yml
        ├── requirements.yml
        ├── requirements.txt
        └── bindep.txt
                │
                │ git clone
                ▼
        Ubuntu 24.04
                │
                │ ansible-builder build
                ▼
      awx-ee-jorsat:v1 (Imagen Docker)
                │
                │ docker push
                ▼
        Registry Local (10.10.100.35:5000)
                │
                ▼
          AWX utiliza esa imagen
```

---

# 1️⃣ Clonar el repositorio

Supongamos que el repositorio se encuentra en GitHub:

```bash
git clone https://github.com/jorsat2025/jorsat.git
```

Ingresar al directorio donde se encuentran los archivos del Execution Environment:

```bash
cd jorsat/Automation/EE
```

En esa carpeta deberán existir los siguientes archivos:

```
execution-environment.yml
requirements.yml
requirements.txt
bindep.txt
```

---

# 2️⃣ Instalar Ansible Builder

Actualizar el sistema:

```bash
sudo apt update
```

Instalar Python:

```bash
sudo apt install -y python3-pip
```

Instalar Ansible Builder:

```bash
pip install ansible-builder
```

---

# 3️⃣ Instalar Docker (o Podman)

Por ejemplo:

```bash
sudo apt install docker.io -y
```

Opcionalmente agregar el usuario al grupo Docker para evitar utilizar `sudo`:

```bash
sudo usermod -aG docker $USER
```

Cerrar sesión y volver a ingresar para aplicar el cambio.

---

# 4️⃣ Construir la imagen

Ejecutar:

```bash
ansible-builder build -t awx-ee-jorsat:v1
```

Durante la construcción ocurre el siguiente proceso:

```text
Lee execution-environment.yml
            │
            ▼
Lee requirements.yml
            │
            ▼
Descarga Collections desde Ansible Galaxy
            │
            ▼
Lee requirements.txt
            │
            ▼
Instala librerías Python
            │
            ▼
Lee bindep.txt
            │
            ▼
Instala paquetes del Sistema Operativo
            │
            ▼
Genera la Imagen Docker
```

---

# 5️⃣ Verificar la imagen creada

Ejecutar:

```bash
docker images
```

Resultado esperado:

```text
REPOSITORY      TAG
awx-ee-jorsat   v1
```

---

# 6️⃣ Publicar la imagen en el Registry Local

Si ya existe un Registry local funcionando en:

```
10.10.100.35:5000
```

publicar la imagen:

```bash
docker tag awx-ee-jorsat:v1 10.10.100.35:5000/awx-ee-jorsat:v1

docker push 10.10.100.35:5000/awx-ee-jorsat:v1
```

---

# 7️⃣ Registrar el Execution Environment en AWX

Crear un nuevo **Execution Environment** apuntando a:

```text
10.10.100.35:5000/awx-ee-jorsat:v1
```

A partir de ese momento, cualquier **Job Template** podrá utilizar esa imagen.

---

# ⚠️ Importante

Verificar que el archivo se llame exactamente:

```text
execution-environment.yml
```

No debe llamarse:

```text
execution-envoironment.yml
```

Si el nombre es incorrecto, **Ansible Builder no lo detectará automáticamente**.

---

# 🎯 Próximos pasos recomendados

1. Clonar el repositorio `jorsat`.
2. Instalar `ansible-builder`.
3. Construir `awx-ee-jorsat:v1`.
4. Publicar la imagen en `10.10.100.35:5000`.
5. Registrar el Execution Environment en AWX.
6. Crear un Job Template utilizando ese EE.
7. Ejecutar el primer Job con el nuevo Execution Environment.

---

## Resultado esperado

En menos de una hora es posible disponer de un **Execution Environment personalizado**, versionado en Git, publicado en un Registry privado y reutilizable por todos los Jobs de AWX.
