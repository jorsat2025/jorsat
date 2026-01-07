#!/bin/bash

echo " borro el directorio viejo"
/usr/bin/rm -rf /root/okd-install

echo "genero el directorio okd"
/usr/bin/mkdir /root/okd-install

echo "copio el install config"
/usr/bin/cp -pr /root/bkp-okd-files/install-config.yaml /root/okd-install

echo "me muevo al directorio"
/usr/bin/cd /root/okd-install 

echo "Genero los directorios"
/usr/local/bin/openshift-install create manifests --dir /root/okd-install

echo "Genero los ignition"
/usr/local/bin/openshift-install create ignition-configs --dir /root/okd-install

echo "Borro los ignition viejos"
/usr/bin/rm -f /var/www/html/ignition/*.ign

echo "Copio los ignition Nuevos"
/usr/bin/cp -pr /root/okd-install/*.ign /var/www/html/ignition/

echo "Doy permisos a los ignition"
/usr/sbin/restorecon -vR /var/www/html/
/usr/bin/chmod o+r /var/www/html/ignition/
/usr/bin/chmod 777 /var/www/html/ignition/*.ign

echo "Reinicio el httpd"
/usr/bin/systemctl restart httpd
