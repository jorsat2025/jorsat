#!/bin/bash

# Comprobar si se corre como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecutá el script como root (usando sudo)."
  exit
fi

CURRENT_KERNEL=$(uname -r)
echo "--------------------------------------------------------"
echo "Kernel actual en uso: $CURRENT_KERNEL"
echo "--------------------------------------------------------"

# 1. Limpieza de paquetes que ya no son necesarios (autoremove)
echo "1. Ejecutando autoremove para eliminar dependencias viejas..."
apt-get autoremove --purge -y

# 2. Identificar y mostrar kernels antiguos (excluyendo el actual)
echo "2. Buscando kernels antiguos para eliminar..."
# Este comando lista imágenes y headers, filtrando el actual
KERNELS_TO_REMOVE=$(dpkg -l | grep -E 'linux-image-[0-9]|linux-headers-[0-9]' | awk '{print $2}' | grep -v "$CURRENT_KERNEL")

if [ -z "$KERNELS_TO_REMOVE" ]; then
    echo "No se encontraron kernels antiguos para eliminar."
else
    echo "Se eliminarán los siguientes paquetes:"
    echo "$KERNELS_TO_REMOVE"
    apt-get purge -y $KERNELS_TO_REMOVE
fi

# 3. Limpiar residuos de configuraciones de paquetes ya eliminados (estado 'rc')
echo "3. Limpiando archivos de configuración residuales..."
RESIDUAL_CONFIGS=$(dpkg -l | grep '^rc' | awk '{print $2}')
if [ -z "$RESIDUAL_CONFIGS" ]; then
    echo "No hay archivos de configuración residuales."
else
    apt-get purge -y $RESIDUAL_CONFIGS
fi

# 4. Actualizar el GRUB para reflejar los cambios
echo "4. Actualizando el menú de inicio (GRUB)..."
update-grub

echo "--------------------------------------------------------"
echo "¡Limpieza completada con éxito!"
echo "--------------------------------------------------------"