# Ansible-gcp

   Ansible Playbooks para Google Cloud Platform

# Requisitos

   1- Para que la Automatizacion funcione debemos crear la cuenta de servicio del Ansible. <br />
   1.1- Para saber cual es la cuenta de servicio: <br />

    Google Cloud: gcloud iam service-accounts list |grep ansible|sort|awk '{print $2}'

   2- Se debe conocer el nombre del proyecto <br />
   2.1- Para saber cual es el nombre del proyecto <br />

      Google Cloud: gcloud projects list |tail -1 |sort|awk '{print $1}'

## Alcance

### Configuracion de Red

   A saber: la red del ambiente, que se estara configurando contiene 2 redes.
   Una que es para MGMT, e ingreso de trafico al ambiente (via IP publica).
   La otra red esta destinada al procesamiento de datos / servicios / etc.. (red tipo DMZ).

1- VPC <br />
   1.1 - Creacion de redes<br />
      1.1.2 - Creacion de Red-1 (mgmt, con salida a internet) <br />
         1.1.2.1 - Creacion de subred 10.6.3.0/24 <br />
      1.1.3 - Creacion de Red-2 (sin salida, DMZ) <br />
         1.1.3.1 - Creacion de subred 10.6.30.0/24 <br />
   1.2 - Creacion de reglas de ruteo  <br />
      1.2.1 - Creacion de reglas de ruteo Red-1 <br />
      1.2.2 - Creacion de reglas de ruteo Red-2 <br />
   1.3 - Creacion de politicas de acceso <br />
      1.3.1 - Apertura de puertos Red-1 <br />
      1.3.2 - Apertura de puertos Red-2 <br />

### Configuracion de Computo

Falta describir este paso

## Para poder utilizar la siguientes librerias (playbooks) es necesario instalar

Las siguientes collections de los repos de Ansible.

    - ansible-galaxy collection install google.cloud
    - pip3 install requests google-auth

# GCP Commandos de creacion de infra

    --------------------------------------------------------------------------------
    |  Google cloud startup-script para crear infraestructura virtual GSV-FW       |
    |  Version: 0.1 | Desing by: Gaston Descalzo | GSV-Enterprise.                 |
    --------------------------------------------------------------------------------

## Comienzo del script

#### Crear Proyecto

El siguiente comando es utilizado para la creacion de proyectos, donde el primer nombre es "es el project ID" y el segundo nombre es el "project name"

      gcloud projects create gsv-project1 --name gsv-admin

#### Setear el proyecto para trabajar sobre el

      gcloud config set project gsv-project1

#### Creacion de redes VPC para el projecto

##### Crea la red primaria

      gcloud compute networks create --subnet-mode=custom red-1

##### Crea la red secundaria

      gcloud compute networks create --subnet-mode=custom red-2

###### Crea la subred 1 para la red primaria

      gcloud compute networks subnets create \
      --network=red-1 \
      --range=10.0.1.0/24 \
      --region=southamerica-east1 subred-1

###### Crea la subred 2 para la red primaria

      gcloud compute networks subnets create \
      --network=red-1 \
      --range=10.0.2.0/24 \
      --region=southamerica-east1 subred-2

###### Crea la subred 3 para la red secundaria

      gcloud compute networks subnets create \
      --network=red-2 \
      --range=10.0.3.0/24 \
      --region=southamerica-east1 subred-3

###### Crea la subred 4 para la red secundaria

      gcloud compute networks subnets create \
      --network=red-2 \
      --range=10.0.4.0/24 \
      --region=southamerica-east1 subred-4

#### Creacion de las reglas de SSH

      gcloud compute firewall-rules create gsv-ssh-input \
      --network red-1 \
      --allow tcp:10666 \
      --source-ranges 0.0.0.0/0
      
      gcloud compute firewall-rules create gsv-ssh-output \
      --network red-1 \
      --allow tcp:10666 \
      --direction egress

#### Creacion de las reglas del FW/Router/GW (VM)

      gcloud compute firewall-rules create gsv-nethserver-input \
      --network red-1 \
      --allow tcp:980 \
      --source-ranges 0.0.0.0/0
      
      gcloud compute firewall-rules create gsv-nethserver-output \
      --network red-1 \
      --allow tcp:980 \
      --direction egress
      
      gcloud compute firewall-rules create gsv-https-input \
      --network red-1 \
      --allow tcp:443 \
      --source-ranges 0.0.0.0/0
      
      gcloud compute firewall-rules create gsv-https-output \
      --network red-1 \
      --allow tcp:443 \
      --direction egress

#### Creacion de rutas

###### Red Primaria

      gcloud compute routes create no-ip-internet-route \
      --network red-2 \
      --destination-range 0.0.0.0/0 \
      --next-hop-instance gsv-fw \
      --next-hop-instance-zone sudamerica-east1-a \
      --tags no-ip \
      --priority 800

###### Red Secundaria

      gcloud compute routes create no-ip-internet-route-2 \
      --network red-2 \
      --destination-range 0.0.0.0/0 \
      --next-hop-instance gsv-fw \
      --next-hop-instance-zone sudamerica-east1-a \
      --tags no-ip \
      --priority 800

_________________________________________________________________________________________________________________________________________________________________

#### Creacion de la VM (Firewall) con 1 o 2 interfaces

###### Con dos interfaces  

####### Con machine type: "f1-micro"

        gcloud compute --project=proud-climber-224512 instances create gsv-fw \
        --zone=southamerica-east1-a \
        --machine-type=f1-micro \
        --network-interface subnet=subred-1,private-network-ip=10.0.1.2,address \
        --can-ip-forward \
        --network-interface subnet=subred-3,private-network-ip=10.0.3.2,no-address \
        --maintenance-policy=MIGRATE \
        --service-account=558603746237-compute@developer.gserviceaccount.com \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
        --image=centos-7-v20190423 \
        --image-project=centos-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --boot-disk-device-name=gsv-fw \
        --metadata serial-port-enable=1 \
        --metadata-from-file startup-script='G:\Documentos\GSV\gcloud-command-injection-firewall-startup-script.txt'

###### Con dos interfaces  

####### Machine type: "g1-smaill"

  La siguiente instancia es para crear un Firewall/Router interno, que tendra el fin de establecer VPN,
  rutear paquetes entre N cantidad de instancias. Esta VM debe tener al menos 2 placas de red con una subnet cada una.

        gcloud compute --project=proud-climber-224512 instances create gsv-fw \
        --zone=southamerica-east1-a \
        --machine-type=g1-small \
        --network-interface subnet=subred-1,private-network-ip=10.0.1.2,address \
        --can-ip-forward \
        --network-interface subnet=subred-3,private-network-ip=10.0.3.2,no-address \
        --maintenance-policy=MIGRATE \
        --service-account=558603746237-compute@developer.gserviceaccount.com \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
        --image=centos-7-v20190423 \
        --image-project=centos-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --boot-disk-device-name=gsv-fw \
        --metadata serial-port-enable=1 \
        --metadata-from-file startup-script='G:\Documentos\GSV\gcloud-command-injection-firewall-startup-script.txt'

####### Machine type: "f1-micro"

   Esta VM esta destinada a uso general. En este caso tiene solo una interface de red, sin ip publica.
   Con lo cual, solo la hace accesible via la red DMZ.

        gcloud compute --project=proud-climber-224512 instances create gsv-websrv \
        --zone=southamerica-east1-a \
        --machine-type=f1-micro \
        --network-interface subnet=subred-3,private-network-ip=10.0.3.3 \
        --no-address \
        --maintenance-policy=MIGRATE \
        --service-account=558603746237-compute@developer.gserviceaccount.com \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
        --image=centos-7-v20190423 \
        --image-project=centos-cloud \
        --boot-disk-size=10GB \
        --boot-disk-type=pd-standard \
        --boot-disk-device-name=gsv-websrv \
        --metadata serial-port-enable=1 \
        --metadata-from-file startup-script='G:\Documentos\GSV\gcloud-command-injection-websrv-startup-script.txt'

#### Ver Instancias

      gcloud compute instances list --format="table[box,title=Instances](name:sort=1,zone:label=zone, status)"

#### Removemos el startup-script del Firewall

        gcloud compute instances remove-metadata gsv-fw --keys startup-script
