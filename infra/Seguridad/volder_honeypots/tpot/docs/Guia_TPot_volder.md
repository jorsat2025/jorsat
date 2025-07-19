
# Guía para Resetear e Instalar T-Pot desde Cero en el Servidor "volder"

---

## 🧹 1. Limpiar completamente la instalación actual de T‑Pot

Ejecuta como root desde `/opt/tpotce`:

```bash
# Detener y eliminar todos los contenedores (e incluso los huérfanos)
docker compose down --remove-orphans

# Alternativamente, eliminar todos los contenedores relacionados con tpot
docker ps -a -q --filter "ancestor=ghcr.io/telekom-security" | xargs -r docker rm -f

# Eliminar los volúmenes de datos persistentes
docker volume ls -q --filter "name=tpotce" | xargs -r docker volume rm

# Eliminar la red por defecto si existe
docker network ls -q --filter "name=tpotce" | xargs -r docker network rm

# Vaciar la carpeta ./data
rm -rf ./data/*
```

---

## 🧰 2. Instalar T‑Pot desde cero

Basado en la guía: https://learnoci.cloud/install-t-pot-honey-pot-in-oci-c583cd0a612

### Pasos:

1. **Instalar dependencias**:
   ```bash
   sudo apt update && sudo apt install -y git curl
   ```

2. **Clonar el repositorio oficial**:
   ```bash
   git clone https://github.com/telekom-security/tpotce.git
   cd tpotce/iso/installer
   ```

3. **Ejecutar el instalador**:
   ```bash
   ./install.sh --type=user
   ```

4. **Seguir instrucciones del instalador**:
   - Crear usuario y contraseña web (se codifica en `.env`)
   - Se descargan contenedores, se configura y reinicia el sistema

5. **Verificar estado**:
   ```bash
   sudo systemctl status tpot
   docker ps
   docker logs -f tpotinit
   ```

6. **Acceder a la interfaz web**:
   - Ir a: `https://<IP_DEL_SERVIDOR>/`
   - Ingresar con las credenciales definidas

---

## 🪜 3. Plan recomendado

| Paso | Acción |
|------|--------|
| ✅ | Corre el script de limpieza anterior |
| 📦 | Instala `git` y `curl` |
| 📥 | Clona `tpotce` y corre `install.sh --type=user` |
| ⚙️ | Sigue los pasos interactivos |
| 🧪 | Verifica el estado y logs |
| 🔐 | Accedé a la interfaz web |

---

Guía generada automáticamente con ❤️ por ChatGPT y el comando `fix.sh`.
