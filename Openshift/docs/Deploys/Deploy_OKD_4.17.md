![](media/image1.png){width="3.103448162729659in"
height="3.103448162729659in"}

**Índice**

**Tabla de Contenidos**

[1.1.1 Introducción [2](#introducción)](#introducción)

[1.1.2 Arquitectura [2](#arquitectura)](#arquitectura)

[1.1.3 Componentes de la solución
[3](#componentes-de-la-solución)](#componentes-de-la-solución)

[1.1.3.1 Storage. [3](#storage.)](#storage.)

[1.1.4 Pasos previos al deploy
[4](#pasos-previos-al-deploy)](#pasos-previos-al-deploy)

[1.1.4.1.1 Descargamos las imágenes y binarios necesarios
[4](#descargamos-las-imágenes-y-binarios-necesarios)](#descargamos-las-imágenes-y-binarios-necesarios)

[1.1.5 Deploy del cluster OKD 4.17
[4](#deploy-del-cluster-okd-4.17)](#deploy-del-cluster-okd-4.17)

[1.1.5.1.1 Proceso de instalación de los nodos
[7](#proceso-de-instalación-de-los-nodos)](#proceso-de-instalación-de-los-nodos)

[1.1.5.1.2 Verificamos el estatus del cluster
[14](#verificamos-el-estatus-del-cluster)](#verificamos-el-estatus-del-cluster)

[1.1.6 Dia 2 del cluster OKD 4.17
[15](#dia-2-del-cluster-okd-4.17)](#dia-2-del-cluster-okd-4.17)

[1.1.6.1 Agregado de taints a los nodos infra
[16](#agregado-de-taints-a-los-nodos-infra)](#agregado-de-taints-a-los-nodos-infra)

[1.1.6.1.1 Configuración Servicio chrony en todos los nodos
[16](#configuración-servicio-chrony-en-todos-los-nodos)](#configuración-servicio-chrony-en-todos-los-nodos)

[1.1.6.2 Migración de los routers de ingress a los nodos infra
[19](#migración-de-los-routers-de-ingress-a-los-nodos-infra)](#migración-de-los-routers-de-ingress-a-los-nodos-infra)

[1.1.6.2.1 Migración de la registry a los nodos infra
[19](#migración-de-la-registry-a-los-nodos-infra)](#migración-de-la-registry-a-los-nodos-infra)

[1.1.6.2.2 Patcheo de nodos master como noscheduleable
[19](#patcheo-de-nodos-master-como-noscheduleable)](#patcheo-de-nodos-master-como-noscheduleable)

[1.1.6.2.3 Aumento de réplicas de los ingress routers
[19](#aumento-de-réplicas-de-los-ingress-routers)](#aumento-de-réplicas-de-los-ingress-routers)

[1.1.6.2.4 configuración de la registry y creación de sc, y pv
[19](#configuración-de-la-registry-y-creación-de-sc-y-pv)](#configuración-de-la-registry-y-creación-de-sc-y-pv)

[1.1.6.2.5 configuración login local con htpasswd
[22](#configuración-login-local-con-htpasswd)](#configuración-login-local-con-htpasswd)

[1.1.6.2.6 Deshabilitamos la telemetría de Insigths
[25](#deshabilitamos-la-telemetría-de-insigths)](#deshabilitamos-la-telemetría-de-insigths)

[1.1.6.2.7 Borramos usuario kudeadmin
[26](#borramos-usuario-kudeadmin)](#borramos-usuario-kudeadmin)

### Introducción

El objetivo del documento es detallar el paso a paso del deploy y la
realización del día 2 del cluster OKD 4.17 es cluster IPI de laboratorio
sobre la plataforma VMware Vsphere 7.0.3.01400. En este caso se eligió
el tipo de instalación UPI instalando en forma manual cada nodo a través
del montaje de la imagen live de fedora Core OS nodo por nodo.

### Arquitectura

En este deploy se optó por replicar la arquitectura utilizada en los
cluster productivos de Openshift .

El siguiente grafico nos muestra la arquitectura de la plataforma:

![](media/image2.png){width="5.8716568241469815in"
height="2.9915212160979876in"}

### Componentes de la solución

El deploy del cluster mencionado requirió de la creación de las
siguientes vms en el entorno VMware Vsphere 7.0.3.01400 provisto:

![](media/image3.emf)

Se solicitaron las vms con los siguientes flavors:

![](media/image4.emf)

#### Storage.

Se utilizaron los siguientes datastores para los discos de los nodos en
la plataforma VMware:

![Interfaz de usuario gráfica, Aplicación Descripción generada
automáticamente](media/image5.png){width="5.90625in"
height="0.7638888888888888in"}

Se creo un volumen de 100 GB, atachado a la vm correspondiente al
bastión, necesario para montar el volumen NFS para la registry, en el
siguiente datastore:

![](media/image6.png){width="5.90625in" height="0.18472222222222223in"}

### Pasos previos al deploy

##### Descargamos las imágenes y binarios necesarios

> Descargamos los binarios oc y openshift-install para la versión 4.17
> de OKD, de la siguiente url:
> <https://github.com/okd-project/okd/releases>, y los descomprimimos en
> la carpeta /usr/local/bin de nuestro bastión.
>
> Descargamos la imagen iso booteable
> **fedora-coreos-39.20231101.3.0-live.x86_64.iso** desde la url:
> <https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/41.20250315.3.0/x86_64/fedora-coreos-41.20250315.3.0-live.x86_64.iso>
>
> La imagen antes mencionada será necesaria más adelante para la
> ignición de los futuros nodos de OKD.
>
> Descargamos las imágenes necesarias para la instalación de CoreOS en
> los nodos. Las imágenes necesarias son:
>
> **fcos.raw.xz**
>
> Las imágenes antes mencionadas se deben ubicar en el path:

**/var/www/html/okd4**

### 1.1.5 Deploy del cluster OKD 4.17 {#deploy-del-cluster-okd-4.17 .list-paragraph}

Como primer paso se creó la carpeta de instalación del cluster OKD en el
path:

**/root/okd-install**

Ingresamos a la carpeta okd-install y procedimos a la creación del
manifiesto install_config.yaml con el siguiente contenido:

apiVersion: v1

baseDomain: gsve.com

compute:

\- hyperthreading: Enabled

name: worker

replicas: 0

controlPlane:

hyperthreading: Enabled

name: master

replicas: 3

metadata:

name: labgsve

networking:

clusterNetwork:

\- cidr: 10.128.0.0/14

hostPrefix: 23

networkType: OVNKubernetes

serviceNetwork:

\- 172.30.0.0/16

platform:

vsphere:

failureDomains:

\- name: generated-failure-domain

region: generated-region

server: server01.gsve.com

topology:

computeCluster: /jorsat01/host/nas01-lun001

datacenter: Jorsat01

datastore: NAS-001-L001

networks:

\- Net-virt

zone: generated-zone

vcenters:

\- datacenters:

\- Jorsat01

password: jorsat2026!!

port: 443

server: openstack-vcenter.claro.amx

user: jorsat@vsphere.local

diskType: thin

pullSecret:
\'{\"auths\":{\"cloud.openshift.com\":{\"auth\":\"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfM2IxMzk4ZjQ2MWE5NDE2Mzg4Njk0YWY3ZDNlNmU5MTU6WDdYUVcwTjNYQ0k0MUo2U0hGR1YySEdWN1NFUkg0MkwwVVQ2OElRM0szOVpaQkhJTU9SSlQ3NUpZRERUN1U4RA==\",\"email\":\"ignacio.bellucci@claro.com.ar\"},\"quay.io\":{\"auth\":\"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfM2IxMzk4ZjQ2MWE5NDE2Mzg4Njk0YWY3ZDNlNmU5MTU6WDdYUVcwTjNYQ0k0MUo2U0hGR1YySEdWN1NFUkg0MkwwVVQ2OElRM0szOVpaQkhJTU9SSlQ3NUpZRERUN1U4RA==\",\"email\":\"ignacio.bellucci@claro.com.ar\"},\"registry.connect.redhat.com\":{\"auth\":\"fHVoYy1wb29sLTQ5YWJlZTE4LTFmYTQtNDE2Ny1iNGQzLWFkNzhjOTRiODRiMDpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXhaR1l6WkRBeE1XVmxZV1kwWVROaFlqQXpObVExWXpJM1pUTm1ZV1V6WmlKOS5oeXJ4M013YWhkWVpFdlZfVzJrSTNnVVJGb0ppMTVkbUNZOC1tV0IyX1B6TGdaTjdhaFFZc1E5RS1JbU5IUFl1ZkYzWjRINGNNN1hnZFlfRXViNjM5d1p0N3pobWpLbXNtSFY4ZGxhV3hlUHZpcnhZWnZqTy1fd1kwLUhmN2NIcVUtVWZUQ2FFMmpSUTlBckNkZUtKSTNvVTZ1OHJsR19XNk9yZGdrRUVGMW1HN1VTNERaZ1FkWHJKTVY2bG12TWRBZDJuanVzVXEtMUhWQ3dRaXo3NUxEVUtwVHVCYkd2ZkNVLWxZS1BXWF9seTRiRTlJOE5YelJaOGdkVjh5VUFvSzRFTUh2cWd4U3MwV2tHdTZUY0MtaFFvdGRQMUNjdVZZWkdiWW1lX0QwU1kwenVMVmp6VmM1dWwwOVpXZTcwRlkxMzhUcGpTLTFkZTJPNkxTWlVBSmMyVXE1eXJKdjhla1FPSFNMNS1QaDdSWGhkTFNBWTFfNGY3N2xYZWlseHNQTjJDcXVRMVlMbVpvLUpOdWpBbjhQZ2tQVXloMzBtbXdNUkhGa0FEMmd5VXloNm1Gdm96R3QwbzlsYWI4NmQ0Z2hoZnJMUGt1b0FzZjlMVHVlMFEtTlppNlFDQVB1aDBtYmtQYlBTb280dlNfR19HaG0wWFNCMmJ3aDFtUGR3VXcxTGVENlEwR3FqNk00VEVxeXozYk5rYmp1UGRmZ3pfVS1xQnpYRzRhOThjanB4bDNhaWo2UGdFUWE2YmlYSUk5UnpXLXBOdFgxTWl0ckt0aWNIc0NHYzVDdExvQ2JnbjFOT25iWXQ4eVlleWlHMWlDR1IwOERtUVg4cmU1a2dReVZ5Ukl6WnRoNC1LQzF0OG5iNEV6OXFXSG1KODRHSWpKb3pZY1I0U0xvaw==\",\"email\":\"ignacio.bellucci@claro.com.ar\"},\"registry.redhat.io\":{\"auth\":\"fHVoYy1wb29sLTQ5YWJlZTE4LTFmYTQtNDE2Ny1iNGQzLWFkNzhjOTRiODRiMDpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXhaR1l6WkRBeE1XVmxZV1kwWVROaFlqQXpObVExWXpJM1pUTm1ZV1V6WmlKOS5oeXJ4M013YWhkWVpFdlZfVzJrSTNnVVJGb0ppMTVkbUNZOC1tV0IyX1B6TGdaTjdhaFFZc1E5RS1JbU5IUFl1ZkYzWjRINGNNN1hnZFlfRXViNjM5d1p0N3pobWpLbXNtSFY4ZGxhV3hlUHZpcnhZWnZqTy1fd1kwLUhmN2NIcVUtVWZUQ2FFMmpSUTlBckNkZUtKSTNvVTZ1OHJsR19XNk9yZGdrRUVGMW1HN1VTNERaZ1FkWHJKTVY2bG12TWRBZDJuanVzVXEtMUhWQ3dRaXo3NUxEVUtwVHVCYkd2ZkNVLWxZS1BXWF9seTRiRTlJOE5YelJaOGdkVjh5VUFvSzRFTUh2cWd4U3MwV2tHdTZUY0MtaFFvdGRQMUNjdVZZWkdiWW1lX0QwU1kwenVMVmp6VmM1dWwwOVpXZTcwRlkxMzhUcGpTLTFkZTJPNkxTWlVBSmMyVXE1eXJKdjhla1FPSFNMNS1QaDdSWGhkTFNBWTFfNGY3N2xYZWlseHNQTjJDcXVRMVlMbVpvLUpOdWpBbjhQZ2tQVXloMzBtbXdNUkhGa0FEMmd5VXloNm1Gdm96R3QwbzlsYWI4NmQ0Z2hoZnJMUGt1b0FzZjlMVHVlMFEtTlppNlFDQVB1aDBtYmtQYlBTb280dlNfR19HaG0wWFNCMmJ3aDFtUGR3VXcxTGVENlEwR3FqNk00VEVxeXozYk5rYmp1UGRmZ3pfVS1xQnpYRzRhOThjanB4bDNhaWo2UGdFUWE2YmlYSUk5UnpXLXBOdFgxTWl0ckt0aWNIc0NHYzVDdExvQ2JnbjFOT25iWXQ4eVlleWlHMWlDR1IwOERtUVg4cmU1a2dReVZ5Ukl6WnRoNC1LQzF0OG5iNEV6OXFXSG1KODRHSWpKb3pZY1I0U0xvaw==\",\"email\":\"ignacio.bellucci@claro.com.ar\"}}}\'

sshKey: ssh-rsa
AAAAB3NzaC1yc2EAAAADAQABAAACAQDKWOa44enw8BMBfYJFN680vtUrU6V9jHycS77D4m/cFHyHV7Xn5bqIgXNTg7ZJOrlnc1zjP+jBW8KlrnFuzY2uFzgOZC1+5M9PKZBBTBXV4oqAFgRuoowKWocuheMEz1BfuAqTe2z+6gGx9vSaDcwarHbFeEy4jAaxQAKH5N26Aam2EKPNSuqCvgUZSUWFlibHcYT0iXj+qAjWgIQ5dr63Y+7F+uCxkOGxq2kBftUiIWf03ZjLNBwTpvji/bG2I0T1wquG2iKEnOqLiMF4K6ySgAWwdmrkeyxGi43gRoe+O3BLkCVu4E5rxU617eRHGQzTKUm3A4+DkoVUdK4V7+N2kb9FCgth8YRB6qiQJi6W/hrzGRV4HajgTMsXlLgMSvGhmVafqi26u9bLA5kKWpUGylhSdGTeRVipThsmTLhKTqsjZ9bJ3+iAP5zXTSlQiOrVkqmvRyDJPCNPqy94JOqPRY/Km1B2vdh+zaaVnTUOEfH9P0iwQBpbiT/rmnuN/IqTVcg/hvUnMRafiinzLHvYE6GlGGU62Uz3ApdreNKldo8nci+6DDQz63zCO8hyRN4RO5hu7JRP3F+mT1sSJH+ZcUkY41N8hKlptPXnHNBCRIhAr5SHVDHGmDO9gYy1N7wmuaKKX34/sG58fBJZfqiJgGlin6vnGo8ZkaIvx9xwtw==
claro@helper

**Nota:** Es recomendable copiar el archivo install_config.yaml a otra
carpeta debido a que se borra con cada ejecución del comando
openshift-install.

En este caso todos los archivos se backupearon en el path:

**/root/bkp-okd-files**

**Preparacion archivos OKD**

En este paso corremos el script:

/home/jorsat/labokd/okd-pretasks.sh

Dicho scipt contiene los siguientes pasos:

**#!/bin/bash**

**echo \"Creando carpeta de installacion\"**

**mkdir -p /home/jorsat/okd-ipi**

**echo \"copio el install config\"**

**/usr/bin/cp -pr /home/claro/install-config.yaml /home/jorsat/okd-ipi**

**echo \"me muevo al directorio\"**

**/usr/bin/cd /home/jorsat/okd-ipi**

**echo \"Genero los manifiestos\"**

**/usr/local/bin/openshift-install create manifests \--dir
/home/jorsat/okd-ipi**

**#echo \" Copio manifiest para la sdn a la carpeta Manifest\"**

**#cp /home/jorsat/bkp-okd+helper/cluster-network-03-config.yml
/home/claro/okd-ipi/manifests**

**#echo \" Chequeo la existencia de el archivo
cluster-network-03-config.yml\"**

**#ls /home/jorsat/okd-ipi/manifests**

**#echo \"Creando el cluster ipi\"**

**#openshift-install create cluster \--dir /home/jorsat/okd-ipi
\--log-level debug**

**echo \"Creando cluster UPI\"**

**openshift-install create ignition-configs \--dir /home/jorsat/okd-ipi
\--log-level debug**

**echo \"Muevo los ignition files a la ruta de apache\"**

**mv /home/jorsat/okd-ipi/\*.ign /var/www/html/okd4**

**echo \"Relabel permisos** **selinux y reinicio de apache\"**

**restorecon -vR /var/www/html/**

**chmod o+r /var/www/html/okd4/\*.ign**

**systemctl restart httpd**

##### Proceso de instalación de los nodos

Para realizar la instalación del SO CoreOS en los nodos de OKD 4.17 se
realizó el siguiente procedimiento, comenzando por el nodo Bootstrap, se
configuraron las vms para bootear con la iso:
**fedora-coreos-37.20230218.3.0-live.x86_64.iso**

Comenzamos por el nodo Bootstrap

![Interfaz de usuario gráfica, Texto, Aplicación, Correo electrónico
Descripción generada
automáticamente](media/image7.png){width="5.136260936132984in"
height="3.016534339457568in"}

![Captura de pantalla de un celular El contenido generado por IA puede
ser incorrecto.](media/image8.png){width="5.90625in"
height="4.030555555555556in"}

A continuación, forzamos a la vm a bootear en el BIOS en siguiente
reinicio:

![Interfaz de usuario gráfica, Aplicación Descripción generada
automáticamente](media/image9.png){width="5.1777537182852145in"
height="3.403132108486439in"}

Luego iniciamos la vm y seleccionamos CD-ROM Drive dentro de las
opciones de arranque.

![Interfaz de usuario gráfica, Texto, Aplicación, Tabla Descripción
generada automáticamente](media/image10.png){width="4.124490376202974in"
height="3.641480752405949in"}

Presionamos F10 para guardar los cambios y que se reinicie la vm.

Presionamos la tecla tab para editar el menú de booteo en la iso y nos
aparece la siguiente pantalla:

![Texto Descripción generada
automáticamente](media/image11.png){width="5.90625in"
height="3.05625in"}

Colocamos siguientes parámetros de ignición de instalación del nodo
Bootstrap a partir de la última línea de parámetros:

**ip=10.10.10.100.20::10.10.10.1:255.255.255.0:bootstrap.lab.gsve.com:ens192:none
nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http://10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http://10.10.100.2:8080/okd4/bootstrap.ign
coreos.inst.insecure**

![Texto Descripción generada
automáticamente](media/image12.png){width="5.90625in"
height="3.7427438757655294in"}

Luego presionamos enter y comenzara a realizar el proceso de ignición.

![Texto Descripción generada
automáticamente](media/image13.png){width="5.90625in"
height="3.5208333333333335in"}

![Interfaz de usuario gráfica Descripción generada automáticamente con
confianza baja](media/image14.png){width="5.90625in"
height="3.432638888888889in"}

Luego de la instalación de CoreOS podremos ver el login del nodo
Bootstrap:

![Texto Descripción generada
automáticamente](media/image15.png){width="5.90625in"
height="2.0236111111111112in"}

El nodo Bootstrap se reiniciará aproximadamente tres veces hasta quedar
completamente instalado.

Luego de la instalación de CoreOS en el nodo Bootstrap comienza el
proceso de bootsraping en el que se comienzan a desplegar todos los
manifiestos y configuraciones necesarias para la operación del futuro
cluster OKD 4.17.

Tenemos que verificar el avance del proceso de bootstraping ingresando
en el nodo Bootstrap con el siguiente comando:

**ssh -l core bootstrap.lab.gsve.com**

Una vez dentro del nodo ejecutamos el comando:

**journalctl -b -f -u release-image.service -u bootkube.service**

Luego de verificar que ya no se está realizando ninguna tarea podemos
comenzar a instalar el primer nodo master.

Luego de aproximadamente 30 minutos ejecutamos el comando:

**\[root@labarq01adl okd_install\]# openshift-install wait-for
bootstrap-complete \--log-level debug**

**DEBUG OpenShift Installer 4.17.0-0.okd-2023-02-18-033438**

**DEBUG Built from commit b8d83ea70540362ec041b21bc150ed984c1d7467**

**INFO Waiting up to 20m0s (until 10:44AM) for the Kubernetes API at
https://api.labo-okd.claro.mx:6**

**DEBUG Still waiting for the Kubernetes API: Get
\"https://api.labo-okd.claro.mx:6443/version\": EOF**

El comando nos indicara cuanto tiempo falta para finalizar el proceso de
bootstraping o si ha finalizado y ya podemos apagar el nodo Bootstrap.

Antes de apagar el nodo Bootstrap debemos comenzar la instalación de los
nodos master realizando el mismo proceso de instalación del nodo
Bootstrap con las siguientes líneas para la ignición:

Master0

**ip=**10.10.100.12**::10.10.100.1:255.255.255.0:master0.gsve.com:ens192:none
nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http://10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http://10.10.100.2:8080/okd4/master.ign
coreos.inst.insecure**

**Master1**

**ip=10.10.100.13::10.10.100.1:255.255.255.0:master1.gsve.com:ens192:none
nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http://10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http://10.10.100.2:8080/okd4/master.ign
coreos.inst.insecure**

**Mater2**

**ip=10.10.100.13::10.10.100.1:255.255.255.0:master2.
gsve.com:ens192:none nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http:// 10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http://10.10.100.2:8080/okd4/master.ign
coreos.inst.insecure**

Luego de la instalación se reiniciará tres veces para finalizar la
instalación de CoreOS.

Una vez instalado el primer nodo master chequeamos en que estado se
encuentra con el comando:

**oc get nodes**

Lo que debemos hacer es aprobar todos los certificados CSR pendientes
con el script:

**/home/jorsat/bkp-okd-files/scripts/approve-all-csr.sh**

Puede ser necesario ejecutar varias veces el comando anterior hasta que
no queden certificados pendientes de aprobación y el nodo master se
encuentre en estado Ready:

**master0.labokdipi.claro.amx Ready control-plane,master 11d v1.31.6**

El siguiente paso es continuar el mismo procedimiento con todos los
nodos. Utilizaremos las siguientes líneas para el proceso de ignición en
los nodos worker:

**ip=10.10.100.14::10.10.100.1:255.255.255.0:worker0.gsve.com:ens192:none
nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http:// 10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http:// 10.10.100.2:8080/okd4/worker.ign
coreos.inst.insecure**

**ip=10.10.100.15:: 10.10.100.1:255.255.255.0:worker1.
gsve.com:ens192:none nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http:// 10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http:// 10.10.100.2:8080/okd4/worker.ign
coreos.inst.insecure**

**ip=10.10.100.16::10.10.100.1:255.255.255.0:worker2.
gsve.com:ens192:none nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http:// 10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http:// 10.10.100.2:8080/okd4/worker.ign
coreos.inst.insecure**

**ip=10.10.100.17::
10.10.100.1:255.255.255.0:worker3.gsve.com:ens192:none
nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http:// 10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http:// 10.10.100.2:8080/okd4/worker.ign
coreos.inst.insecure**

**ip=10.202.36.78::10.10.100.1:255.255.255.0:worker4.gsve.com:ens192:none
nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http:// 10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http://10.10.100.2:8080/okd4/worker.ign
coreos.inst.insecure**

**ip=10.202.36.79:10.202.36.1:255.255.255.0:worker5.gsve.com:ens192:none
nameserver=10.10.100.1 coreos.inst.install_dev=sda
coreos.inst.image_url=http:// 10.10.100.2:8080/okd4/fcos.raw.xz
coreos.inst.ignition_url=http:// 10.10.100.2:8080/okd4/worker.ign
coreos.inst.insecure**

##### Verificamos el estatus del cluster

Al finalizar podremos chequear que todos nuestros nodos están en estado
Ready:

![Texto El contenido generado por IA puede ser
incorrecto.](media/image16.png){width="5.90625in"
height="1.7173611111111111in"}

También tenemos que verificar que todos los cluster operators estén ok
con el siguiente comando:

![Interfaz de usuario gráfica, Texto El contenido generado por IA puede
ser incorrecto.](media/image17.png){width="5.90625in"
height="4.121527777777778in"}

Como podemos ver todos los CO se encuentran disponibles y sin errores
con lo cual podemos probar el ingreso a la consola del cluster
ingresando la url:

<https://console-openshift-console.apps.labokdipi.claro.amx/>

Veremos la siguiente pantalla de login:

![Interfaz de usuario gráfica, Aplicación El contenido generado por IA
puede ser incorrecto.](media/image18.png){width="5.90625in"
height="3.946527777777778in"}

Para ingresar a la plataforma necesitamos obtener la password del
usuario kudeadmin del archivo:

**\[root@labarq01adl claro\]# cat
/root/okd-install/auth/kubeadmin-password**

Una vez ingresemos en la consola del cluster veremos la siguiente
pantalla:

![Interfaz de usuario gráfica, Texto El contenido generado por IA puede
ser incorrecto.](media/image19.png){width="5.90625in" height="3.25in"}

### Dia 2 del cluster OKD 4.17

Para finalizar los trabajos de deploy del cluster se realizaron las
configuraciones y customizaciones finales a saber:

-   Se colocaron los taints correctos a los nodos infra

-   Se configuro el servicio NTP (chrony) en todos los nodos.

-   Se migraron los routers de ingress a los nodos infra.

-   Se migro la registry a los nodos infra.

-   Se patchearon los nodos master para que no corran pods.

-   Se aumentaron las réplicas de ingress router para que tengamos uno
    por cada nodo infra.

-   Se crearon Storage class, PV y PVC para el acceso al servidor NFS
    correspondiente a la registry.

-   Se configuro login local con htpasswd.

-   Se deshabilito insigths.

#### Agregado de taints a los nodos infra

Ingresamos al nodo bastión y ejecutamos el siguiente comando:

**\[root@labarq01adl \~\]#\$ oc adm taint nodes -l
node-role.kubernetes.io/infra infra=reserved:NoSchedule**

##### Configuración Servicio chrony en todos los nodos

Es necesario configurar el servicio chrony en todos los nodos para lo
cual es necesario crear los machine config para cada nodo en la que
aplicaremos la configuración de chrony. Para realizar esta tarea es
necesario crear los siguientes archivos:

**99-infra-chrony.yaml**

**99-masters-chrony.yaml**

**99-workers-chrony.yaml**

Necesitamos crear un archivo con el contenido del archivo
/etc/chrony.conf:

**cat \>chrony.conf\<\<EOF**

**server ntpdserver-a.gsve.com iburst**

**server ntpdserver-b. gsve.com iburst**

**server ntpdserver-c. gsve.com iburst**

**server ntpdserver-d. gsve.com iburst**

**driftfile /var/lib/chrony/drift**

**makestep 1.0 3**

**rtcsync**

**allow 10.10.100.0/23**

**keyfile /etc/chrony.keys.**

**leapsectz right/UTCleapsectz right/UTC**

**logdir /var/log/chrony**

**EOF**

Luego tenemos que correr el comando:

**base64 -w0 chrony.conf**

Con este comando lo que hacemos es codificar el archivo generando un
hash en base64.

En nuestro caso el hash resultante fue:

c2VydmVyIG50cGRzZXJ2ZXItYS5jbGFyby5hbXggaWJ1cnN0CnNlcnZlciBudHBkc2VydmVyLWIuY2xhcm8uYW14IGlidXJzdApzZXJ2ZXIgbnRwZHNlcnZlci1jLmNsYXJvLmFteCBpYnVyc3QKc2VydmVyIG50cGRzZXJ2ZXItZC5jbGFyby5hbXggaWJ1cnN0CmRyaWZ0ZmlsZSAvdmFyL2xpYi9jaHJvbnkvZHJpZnQKbWFrZXN0ZXAgMS4wIDMKcnRjc3luYwphbGxvdyAxMC4yMDIuNDIuMC8yMwpsb2dkaXIgL3Zhci9sb2cvY2hyb255Cg==

Este hash debemos colocarlo en los archivos .yaml mencionados quedando
de la siguiente manera para el caso de cada tipo de nodo:

**Infra**

apiVersion: machineconfiguration.openshift.io/v1

kind: MachineConfig

metadata:

  labels:

    machineconfiguration.openshift.io/role: infra

  name: 50-infra-chrony

spec:

  config:

    ignition:

      version: 2.2.0

    storage:

      files:

      - contents:

          source:
data:text/plain;charset=utf-8;base64,c2VydmVyIG50cGRzZXJ2ZXItYS5jbGFyby5hbXggaWJ1cnN0CnNlcnZlciBudHBkc2VydmVyLWIuY2xhcm8uYW14IGlidXJzdApzZXJ2ZXIgbnRwZHNlcnZlci1jLmNsYXJvLmFteCBpYnVyc3QKc2VydmVyIG50cGRzZXJ2ZXItZC5jbGFyby5hbXggaWJ1cnN0CmRyaWZ0ZmlsZSAvdmFyL2xpYi9jaHJvbnkvZHJpZnQKbWFrZXN0ZXAgMS4wIDMKcnRjc3luYwphbGxvdyAxMC4yMDIuNDIuMC8yMwpsb2dkaXIgL3Zhci9sb2cvY2hyb255Cg==

        filesystem: root

        mode: 0644

        path: /etc/chrony.conf

**Master**

apiVersion: machineconfiguration.openshift.io/v1

kind: MachineConfig

metadata:

  labels:

    machineconfiguration.openshift.io/role: master

  name: 50-master-chrony

spec:

  config:

    ignition:

      version: 2.2.0

    storage:

      files:

      - contents:

          source:
data:text/plain;charset=utf-8;base64,ICAgIHBvb2wgMTAuMTAuMTAxLjEwMiBpYnVyc3QgCiAgICBwb29sIDEwLjEwLjUwLjEwMSBpYnVyc3QgCiAgICBkcmlmdGZpbGUgL3Zhci9saWIvY2hyb255L2RyaWZ0CiAgICBtYWtlc3RlcCAxLjAgMwogICAgcnRjc3luYwogICAgbG9nZGlyIC92YXIvbG9nL2Nocm9ueQoK

        filesystem: root

        mode: 0644

        path: /etc/chrony.conf

**Worker**

apiVersion: machineconfiguration.openshift.io/v1

kind: MachineConfig

metadata:

  labels:

    machineconfiguration.openshift.io/role: worker

  name: 50-worker-chrony

spec:

  config:

    ignition:

      version: 2.2.0

    storage:

      files:

      - contents:

          source:
data:text/plain;charset=utf-8;base64,ICAgIHBvb2wgMTAuMTAuMTAxLjEwMiBpYnVyc3QgCiAgICBwb29sIDEwLjEwLjUwLjEwMSBpYnVyc3QgCiAgICBkcmlmdGZpbGUgL3Zhci9saWIvY2hyb255L2RyaWZ0CiAgICBtYWtlc3RlcCAxLjAgMwogICAgcnRjc3luYwogICAgbG9nZGlyIC92YXIvbG9nL2Nocm9ueQoK

        filesystem: root

        mode: 0644

        path: /etc/chrony.conf

**Nota: Tenemos que asegurarnos que el campo source nos quede en una
sola línea.**

El siguiente paso es aplicar cada uno de los machineconfig con los
siguientes comandos:

**oc apply -f 99-infra-chrony.yaml**

**oc apply -f 99-infra-master.yaml**

**oc apply -f 99-infra-worker.yaml**

Vamos a notar que los nodos se van reiniciando por orden de ejecución de
los comandos mencionados arriba.

Luego podemos verificar que la configuración de chrony se encuentre
aplicada en los nodos con los siguientes comandos:

![Texto Descripción generada
automáticamente](media/image20.png){width="5.90625in"
height="1.0944444444444446in"}

![Texto Descripción generada
automáticamente](media/image21.png){width="5.90625in"
height="0.8590277777777777in"}

Desde la consola de OKD, podemos ver que están creados los machineconfig
para cada tipo de nodo:

![Interfaz de usuario gráfica, Aplicación Descripción generada
automáticamente](media/image22.png){width="5.90625in" height="2.5625in"}

#### Migración de los routers de ingress a los nodos infra

Para poder migrar los routers de ingress de la plataforma necesitamos
ejecutar el siguiente comando en nuestro nodo bastión:

**oc patch ingresscontroller default -n openshift-ingress-operator
\--type=merge \--patch=\'{\"spec\":{\"nodePlacement\":{\"nodeSelector\":
{\"matchLabels\":{\"node-role.kubernetes.io/infra\":\"\"}}}}}\'**

#####  Migración de la registry a los nodos infra

El siguiente comando realiza la migración de la registry desde los nodos
master hacia los infra:

**oc patch configs.imageregistry.operator.openshift.io/cluster -n
openshift-image-registry \--type=merge \--patch
\'{\"spec\":{\"nodeSelector\":{\"node-role.kubernetes.io/infra\":\"\"}}}\'**

##### Patcheo de nodos master como noscheduleable

Esta tarea es necesaria para que los nodos master no corran pods de
usuarios y se logra con la ejecución del siguiente comando:

##### Aumento de réplicas de los ingress routers

A efectos de garantizar mayor disponibilidad de los routers de ingress
ante la caída de algún nodo ejecutamos el siguiente comando:

**oc patch -n openshift-ingress-operator ingresscontroller/default
\--patch \'{\"spec\":{\"replicas\": 3}}\' \--type=merge**

Este aumento en la cantidad de réplicas de ingress router la podemos
verificar con el siguiente comando:

![Texto El contenido generado por IA puede ser
incorrecto.](media/image23.png){width="5.90625in"
height="0.8701388888888889in"}

Como podemos ver tenemos corriendo un router de ingress en cada uno de
los nodos infra del cluster.

##### configuración de la registry y creación de sc, y pv

Fue necesario crear el storage class y el pv correspondientes a la
registry del cluster, apuntando al servidor NFS configurado en el nodo
bastión.

Comenzamos por la creación del storage class que nombramos stgokd
(storage OKD) con os siguientes parámetros:

kind: StorageClass

apiVersion: storage.k8s.io/v1

metadata:

  name: stgokd

provisioner: storage.io/nfs

reclaimPolicy: Retain

volumeBindingMode: Immediate

A continuacion creamos el persistent volume (pv):

apiVersion: v1

kind: PersistentVolume

metadata:

name: pv-image-registry

spec:

capacity:

storage: 100Gi

accessModes:

\- ReadWriteMany

persistentVolumeReclaimPolicy: Retain

volumeMode: Filesystem

mountOptions:

\- vers=3

nfs:

path: /ibm/NFS_Prod/REGISTRY_LABOKDIPI_dt_okd_apu

server: 10.202.36.23

readOnly: false

claimRef:

namespace: openshift-image-registry

name: pvc-image-registry

apiVersion: v1

kind: PersistentVolumeClaim

Seguimos con el pvc:

apiVersion: v1

kind: PersistentVolumeClaim

metadata:

name: pvc-image-registry

namespace: openshift-image-registry

spec:

accessModes:

\- ReadWriteMany

resources:

requests:

storage: 100Gi

volumeName: pv-image-registry

Luego se editó la configuración de registry y se agregó el PVC creado.

![](media/image24.png){width="5.90625in" height="0.2791666666666667in"}

Agregamos los campos :

![Texto El contenido generado por IA puede ser
incorrecto.](media/image25.png){width="5.90625in"
height="2.613888888888889in"}

Ahora podemos ver creado el pvc correspondiente:

![Captura de pantalla de un celular El contenido generado por IA puede
ser incorrecto.](media/image26.png){width="5.90625in"
height="1.4444444444444444in"}

Por comando el patcheo para que use el registry seria:

**oc patch configs.imageregistry.operator.openshift.io cluster \--type
merge \--patch
\'{\"spec\":{\"storage\":{\"pvc\":{\"claim\":\"pvc-image-registry\"}},
\"managementState\": \"Managed\"}}\' **

![](media/image27.png){width="5.90625in" height="2.7604166666666665in"}

##### configuración login local con htpasswd

Se agregó la configuración de un Identity Provider del tipo htpasswd.
Como primer paso se creo el archivo que contiene las credenciales:

**htpasswd -c -B -b users.htpasswd okd alfombra03**

Como resultante tenemos un archivo con el siguiente contenido:

![](media/image28.png){width="5.90625in" height="0.36736111111111114in"}

Luego se generó el secret con la ejecución del siguiente comando:

**oc create secret generic htpass-secret \--from-file=htpasswd=
users.htpasswd -n openshift-config**

Creamos el custom resource ( cr ) para el Identity Provider htpasswd. A
tal efecto creamos el siguiente archivo httpass-cr.yaml:

**apiVersion: config.openshift.io/v1**

**kind: OAuth**

**metadata:**

**name: cluster**

**spec:**

**identityProviders:**

**- name: Local**

**mappingMethod: claim**

**type: HTPasswd**

**challenge: true**

**login: true**

**htpasswd:**

**fileData:**

**name: htpass-secret**

Ahora aplicamos dicho yaml de la siguiente manera:

![](media/image29.png){width="4.718096019247594in"
height="0.2585115923009624in"}

Luego de aplicado el yaml mencionado se puede verificar en la consola de
OKD la creación del CR con su correspondiente POD , así como también la
existencia del Identity Provider htpasswd :

![Interfaz de usuario gráfica, Sitio web Descripción generada
automáticamente](media/image30.png){width="4.817341426071741in"
height="3.719633639545057in"}

![Interfaz de usuario gráfica, Texto, Aplicación Descripción generada
automáticamente](media/image31.png){width="4.415945975503062in"
height="4.148548775153106in"}

![Interfaz de usuario gráfica, Aplicación Descripción generada
automáticamente](media/image32.png){width="4.202531714785652in"
height="2.5575896762904637in"}

Probamos el acceso a la consola OKD a través del Identity Provider
creado:

![Interfaz de usuario gráfica, Aplicación Descripción generada
automáticamente](media/image33.png){width="5.045625546806649in"
height="3.245100612423447in"}

Nos encontramos con que la pantalla de Loguin tiene un nuevo capo
llamado htpasswd. Hacemos clic en dicho campo e ingresamos las
credenciales creadas en la generación del archivo **users.htpasswd** e
ingresamos en la consola OKD:

![Interfaz de usuario gráfica, Aplicación Descripción generada
automáticamente](media/image34.png){width="5.90625in"
height="2.7104166666666667in"}

Otorgar el rol de cluster admin a nuestro usuario local:

**oc adm policy add-cluster-role-to-user cluster-admin admin**

##### Deshabilitamos la telemetría de Insigths

Para deshabilitar las alertas generadas por la telemetría del operador
Insigths ejecutamos los siguientes comandos:

**\[root@labarq01adl bkp-pull-secret\]# oc extract secret/pull-secret -n
openshift-config \--to=.dockerconfigjson**

**\[root@labarq01adl bkp-pull-secret\]# cat .dockerconfigjson**

**{\"auths\":{\"cloud.openshift.com\":**

**{\"auth\":\"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfM2IxMzk4ZjQ2MWE5NDE2Mzg4Njk0YWY3ZDNl**

**NmU5MTU6WDdYUVcwTjNYQ0k0MUo2U0hGR1YySEdWN1NFUkg0MkwwVVQ2OElRM0szOVpaQkhJTU9SSlQ3N**

**UpZRERUN1U4RA==\",\"email\":\"ignacio.bellucci@claro.com.ar\"},\"quay.io\":**

**{\"auth\":\"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfM2IxMzk4ZjQ2MWE5NDE2Mzg4Njk0YWY3ZDNl**

**NmU5MTU6WDdYUVcwTjNYQ0k0MUo2U0hGR1YySEdWN1NFUkg0MkwwVVQ2OElRM0szOVpaQkhJTU9SSlQ3N**

**UpZRERUN1U4RA==\",\"email\":\"ignacio.bellucci@claro.com.ar\"},\"registry.connect.redhat.com\":**

**{\"auth\":\"fHVoYy1wb29sLTQ5YWJlZTE4LTFmYTQtNDE2Ny1iNGQzLWFkNzhjOTRiODRiMDpleUpoYkdjaU9pSlNVelV**

**4TWlKOS5leUp6ZFdJaU9pSXhaR1l6WkRBeE1XVmxZV1kwWVROaFlqQXpObVExWXpJM1pUTm1ZV1V6WmlKOS5**

**oeXJ4M013YWhkWVpFdlZfVzJrSTNnVVJGb0ppMTVkbUNZOC1tV0IyX1B6TGdaTjdhaFFZc1E5RS1JbU5IUFl1ZkYzW**

**jRINGNNN1hnZFlfRXViNjM5d1p0N3pobWpLbXNtSFY4ZGxhV3hlUHZpcnhZWnZqTy1fd1kwLUhmN2NIcVUtVWZ**

Luego podemos verificar que Insigths se encuentra deshabilitado:

![Interfaz de usuario gráfica Descripción generada automáticamente con
confianza media](media/image35.png){width="5.90625in" height="1.575in"}

#####  Borramos usuario kudeadmin

A fin de realizar dicha acción ejecutamos el comando:

**oc delete secrets kubeadmin -n kube-system**
