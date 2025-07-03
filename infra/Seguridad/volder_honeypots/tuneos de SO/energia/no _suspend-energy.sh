#!/bin/bash

echo "🛡️ Desactivando suspensión e hibernación en systemd-logind..."

# Hacer backup solo si no existe
if [ ! -f /etc/systemd/logind.conf.bak ]; then
    cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak
fi

# Borrar líneas existentes si están presentes
sed -i '/^HandleSuspendKey/d' /etc/systemd/logind.conf
sed -i '/^HandleHibernateKey/d' /etc/systemd/logind.conf
sed -i '/^HandleLidSwitch/d' /etc/systemd/logind.conf
sed -i '/^HandleLidSwitchExternalPower/d' /etc/systemd/logind.conf
sed -i '/^HandleLidSwitchDocked/d' /etc/systemd/logind.conf

# Agregar configuración para desactivar suspensión e hibernación
cat <<EOF >> /etc/systemd/logind.conf

# Desactivación de suspensión y hibernación agregada por script
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

# Reiniciar logind para aplicar cambios
systemctl restart systemd-logind

# Mascara las unidades que podrían intentar suspender
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

echo "🎉 ¡Listo! El sistema ya no puede suspenderse ni hibernar."
