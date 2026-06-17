# BACKUP - CONFIGURACIÓN DE INFRAESTRUCTURA OPENSHIFT (CLARO)
Fecha de exportación: 2026

## 1. JSON ORIGINAL (Raw Data)
--------------------------------------------------------------------------------
{
  "apiServerInternalIPs": [],
  "failureDomains": [
    {
      "name": "generated-failure-domain",
      "region": "generated-region",
      "server": "openstack-vcenter.claro.amx",
      "topology": {
        "computeCluster": "/Olleros-IT/host/FSO-Clu06-MC",
        "datacenter": "Olleros-IT",
        "datastore": "/Olleros-IT/datastore/OSDS-Cluster06-Mission Critical/OSDS-Cluster-CL06MC-VSP/OSDS-CL06MC-VSP-L035",
        "networks": [
          "PG-Olleros-VLAN0613"
        ],
        "resourcePool": "/Olleros-IT/host/FSO-Clu06-MC/Resources",
        "template": "/Olleros-IT/vm/osepaihub-mbx4q-rhcos-generated-failure-domain"
      },
      "zone": "generated-zone"
    }
  ],
  "vcenters": [
    {
      "datacenters": [
        "Olleros-IT"
      ],
      "port": 443,
      "server": "openstack-vcenter.claro.amx"
    }
  ]
}
--------------------------------------------------------------------------------

## 2. DATOS DE CONEXIÓN Y ACCESO (vCenter)
* **Servidor vCenter:** openstack-vcenter.claro.amx
* **Puerto:** 443
* **Datacenter Virtual:** Olleros-IT

## 3. TOPOLOGÍA DEL CLÚSTER (Cómputo y Recursos)
* **Cluster ESXi (Compute):** /Olleros-IT/host/FSO-Clu06-MC (Mission Critical)
* **Resource Pool:** /Olleros-IT/host/FSO-Clu06-MC/Resources
* **Plantilla base de OS (RHCOS Template):** /Olleros-IT/vm/osepaihub-mbx4q-rhcos-generated-failure-domain
* **Región Lógica:** generated-region
* **Zona Lógica:** generated-zone

## 4. RED (Networking)
* **PortGroup / VLAN vSphere:** PG-Olleros-VLAN0613

## 5. ALMACENAMIENTO (Ruta Posta para StorageClass)
* **Datastore Path:** /Olleros-IT/datastore/OSDS-Cluster06-Mission Critical/OSDS-Cluster-CL06MC-VSP/OSDS-CL06MC-VSP-L035

---

## 6. TEMPLATE DE STORAGECLASS LISTO PARA APLICAR (Basado en estos datos)
Si necesitas recrear la StorageClass predeterminada para este entorno, usa este manifiesto:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: thin-csi-claro-mc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: csi.vsphere.vmware.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  datastore: "/Olleros-IT/datastore/OSDS-Cluster06-Mission Critical/OSDS-Cluster-CL06MC-VSP/OSDS-CL06MC-VSP-L035"
  fstype: ext4