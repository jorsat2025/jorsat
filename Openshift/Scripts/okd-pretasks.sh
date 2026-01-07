#!/bin/bash

echo "Creando carpeta de installacion"
mkdir -p /home/okd/okdml01

echo "copio el install config"
/usr/bin/cp -pr /home/okd/bkp-okd-files/install-config.yaml /home/okd/okdml01

echo "me muevo al directorio"
/usr/bin/cd /home/okd/okdml01

echo "Genero los manifiestos"
/usr/local/bin/openshift-install create manifests --dir /home/okd/okdml01

echo "Genero los ignition files"

/usr/local/bin/openshift-install create ignition-configs --dir /home/okd/okdml01

echo "Muevo los ignition files a la ruta de apache"

mv /home/okd/okdml01/*.ign /var/www/html/okd4

echo "Relabel permisos selinux y reinicio  de apache"

restorecon -vR /var/www/html/
chmod o+r /var/www/html/okd4/*.ign
systemctl restart httpd




