#### Bootstrap

---

##### WORKER

```text
ip=10.202.36.88::10.202.36.1:255.255.255.0:worker0.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure

ip=10.202.36.89::10.202.36.1:255.255.255.0:worker1.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure

ip=10.202.36.90::10.202.36.1:255.255.255.0:worker2.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure

ip=10.202.36.77::10.202.36.1:255.255.255.0:worker3.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure

ip=10.202.36.78::10.202.36.1:255.255.255.0:worker4.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure

ip=10.202.36.79:10.202.36.1:255.255.255.0:worker5.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure
```

---

##### MASTER

```text
ip=10.202.36.82::10.202.36.1:255.255.255.0:master0.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/master.ign coreos.inst.insecure

ip=10.202.36.83::10.202.36.1:255.255.255.0:master1.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/master.ign coreos.inst.insecure

ip=10.202.36.84::10.202.36.1:255.255.255.0:master2.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/master.ign coreos.inst.insecure
```

---

##### INFRA

```text
ip=10.202.36.85::10.202.36.1:255.255.255.0:infra0.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure

ip=10.202.36.86::10.202.36.1:255.255.255.0:infra1.gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure

ip=10.202.36.87::10.202.36.1:255.255.255.0:gsve.locals:ens192:none nameserver=10.92.55.39 coreos.inst.install_dev=sda coreos.inst.image_url=http://10.202.36.91:8080/okd4/fcos.raw.xz coreos.inst.ignition_url=http://10.202.36.91:8080/okd4/worker.ign coreos.inst.insecure
```

