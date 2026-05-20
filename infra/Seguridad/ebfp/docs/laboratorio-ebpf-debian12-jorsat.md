# Laboratorio eBPF en Debian 12 — Proyecto Jorsat

> Objetivo: preparar una mini PC con Debian 12 como laboratorio eBPF puro para entender qué pasa a nivel sistema operativo cuando llega tráfico de red normal o “peligroso”.

---

## 0. Contexto del laboratorio

Estado actual de la mini PC:

```text
Debian 12 pelado
Sin Suricata
Sin Kubernetes
Sin Docker
Sin nftables complejo
Sin dashboard
```

Objetivo inicial:

```text
proceso → syscall → socket → tráfico → latencia → comportamiento del SO
```

Más adelante:

```text
Guemes / Suricata / nftables / JSMS
        ↓
correlación con eBPF
```

---

## 1. Conceptos clave

### ¿Qué es eBPF?

eBPF permite cargar pequeños programas seguros dentro del kernel Linux para observar o actuar sobre eventos del sistema.

Sirve para:

```text
tracing
networking
seguridad
performance
observabilidad
syscalls
sockets
filesystem
containers
```

---

### ¿Qué es bpftrace?

`bpftrace` es una herramienta de alto nivel para escribir scripts eBPF de forma simple.

Los scripts suelen tener extensión:

```text
.bt
```

Ejemplo:

```bash
trace_exec.bt
tcp_connect.bt
nmap_observer.bt
```

---

### Tipos de hooks importantes

| Hook | Qué observa |
|---|---|
| tracepoint | Eventos estables del kernel |
| kprobe | Funciones internas del kernel |
| kretprobe | Retorno de funciones del kernel |
| uprobe | Funciones de aplicaciones user-space |
| uretprobe | Retorno de funciones user-space |
| XDP | Paquetes muy temprano en la placa de red |
| socket filter | Tráfico asociado a sockets |
| cgroup hooks | Procesos/containers/cgroups |

---

## 2. Verificar estado del sistema

Ejecutar:

```bash
uname -a
cat /etc/os-release
```

Verificar bpffs:

```bash
mount | grep bpf
ls -ld /sys/fs/bpf
```

Verificar BTF:

```bash
ls -l /sys/kernel/btf/vmlinux
```

Si existe, muy buena señal.

---

## 3. Verificar restricciones que pueden afectar eBPF

### AppArmor

```bash
sudo aa-status
```

También:

```bash
cat /sys/module/apparmor/parameters/enabled
```

Resultado esperado si está activo:

```text
Y
```

Para laboratorio eBPF se puede dejar activo al principio, pero si molesta se puede desactivar.

---

### Kernel lockdown

```bash
cat /sys/kernel/security/lockdown
```

Ideal para laboratorio:

```text
[none] integrity confidentiality
```

Si aparece:

```text
none [integrity] confidentiality
```

o:

```text
none integrity [confidentiality]
```

puede limitar tracing avanzado.

---

### Secure Boot

```bash
mokutil --sb-state
```

Ideal para laboratorio:

```text
SecureBoot disabled
```

Si está activo, puede activar lockdown.

---

### Unprivileged BPF

```bash
sysctl kernel.unprivileged_bpf_disabled
```

Para laboratorio sin restricciones:

```text
kernel.unprivileged_bpf_disabled = 0
```

Temporal:

```bash
sudo sysctl -w kernel.unprivileged_bpf_disabled=0
```

Persistente:

```bash
echo 'kernel.unprivileged_bpf_disabled=0' | sudo tee /etc/sysctl.d/99-ebpf.conf
sudo sysctl --system
```

---

## 4. Desactivar AppArmor si se quiere laboratorio sin restricciones

Editar GRUB:

```bash
sudo nano /etc/default/grub
```

Buscar:

```text
GRUB_CMDLINE_LINUX_DEFAULT=
```

Ejemplo recomendado para laboratorio:

```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet apparmor=0"
```

Aplicar:

```bash
sudo update-grub
sudo reboot
```

Verificar:

```bash
sudo aa-status
```

---

## 5. Montar bpffs

Temporal:

```bash
sudo mount -t bpf bpf /sys/fs/bpf
```

Persistente:

```bash
echo "bpf /sys/fs/bpf bpf defaults 0 0" | sudo tee -a /etc/fstab
```

Verificar:

```bash
mount | grep bpf
```

---

## 6. Instalar herramientas base

```bash
sudo apt update
```

```bash
sudo apt install -y \
  bpftrace \
  bpftool \
  bpfcc-tools \
  clang \
  llvm \
  libbpf-dev \
  libelf-dev \
  linux-headers-$(uname -r) \
  linux-perf \
  tcpdump \
  git \
  curl \
  vim \
  nano \
  net-tools \
  iproute2 \
  procps
```

Si falla `linux-headers-$(uname -r)`, revisar kernel exacto:

```bash
uname -r
apt search linux-headers
```

---

## 7. Validar soporte eBPF

```bash
sudo bpftool feature probe
```

Versión resumida:

```bash
sudo bpftool feature probe kernel
```

Ver programas eBPF cargados:

```bash
sudo bpftool prog show
```

Ver mapas eBPF cargados:

```bash
sudo bpftool map show
```

---

## 8. Comandos inline con bpftrace

Los comandos inline son ideales para pruebas rápidas.

### 8.1 Ver procesos que se ejecutan

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_execve
{
  printf("EXEC comm=%s pid=%d uid=%d\n", comm, pid, uid);
}'
```

Probar en otra terminal:

```bash
ls
curl http://example.com
ps aux
```

---

### 8.2 Ver creación de sockets

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_socket
{
  printf("SOCKET comm=%s pid=%d domain=%d type=%d protocol=%d\n",
         comm, pid, args->domain, args->type, args->protocol);
}'
```

Valores útiles:

```text
domain=2   AF_INET
domain=10  AF_INET6
type=1     SOCK_STREAM
type=2     SOCK_DGRAM
```

---

### 8.3 Ver intentos de connect()

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_connect
{
  printf("CONNECT comm=%s pid=%d fd=%d\n", comm, pid, args->fd);
}'
```

Probar:

```bash
curl https://google.com
ssh usuario@ip
```

---

### 8.4 Ver accept4()

Útil cuando la mini PC recibe conexiones.

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_accept4
{
  printf("ACCEPT4 comm=%s pid=%d fd=%d\n", comm, pid, args->fd);
}'
```

En otra terminal levantar server:

```bash
python3 -m http.server 8080
```

Desde otra máquina:

```bash
curl http://IP_MINIPC:8080
```

---

### 8.5 Ver read()

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_read
/comm == "python3"/
{
  printf("READ comm=%s pid=%d fd=%d count=%d\n",
         comm, pid, args->fd, args->count);
}'
```

---

### 8.6 Ver write()

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_write
/comm == "python3"/
{
  printf("WRITE comm=%s pid=%d fd=%d count=%d\n",
         comm, pid, args->fd, args->count);
}'
```

---

### 8.7 Ver apertura de archivos

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_openat
{
  printf("OPEN comm=%s pid=%d file=%s\n",
         comm, pid, str(args->filename));
}'
```

---

### 8.8 Ver borrado de archivos

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_unlinkat
{
  printf("UNLINK comm=%s pid=%d file=%s\n",
         comm, pid, str(args->pathname));
}'
```

---

### 8.9 Ver ejecución de comandos sospechosos

```bash
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_execve
/str(args->filename) == "/bin/sh" || str(args->filename) == "/bin/bash" || str(args->filename) == "/usr/bin/nc"/
{
  printf("SUSPICIOUS EXEC comm=%s pid=%d uid=%d file=%s\n",
         comm, pid, uid, str(args->filename));
}'
```

---

### 8.10 Contar syscalls por proceso

```bash
sudo bpftrace -e '
tracepoint:raw_syscalls:sys_enter
{
  @[comm] = count();
}
'
```

Al cortar con `CTRL+C`, muestra resumen.

---

## 9. Scripts .bt reutilizables

Crear carpeta:

```bash
mkdir -p ~/ebpf-lab/scripts
cd ~/ebpf-lab/scripts
```

---

# Script 1 — exec_monitor.bt

Archivo:

```bash
nano exec_monitor.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * exec_monitor.bt
 * Observa procesos nuevos mediante execve().
 */

tracepoint:syscalls:sys_enter_execve
{
    printf("EXEC time=%llu comm=%s pid=%d ppid=%d uid=%d file=%s\n",
           nsecs, comm, pid, curtask->real_parent->tgid, uid, str(args->filename));
}
```

Permisos:

```bash
chmod +x exec_monitor.bt
```

Ejecución:

```bash
sudo ./exec_monitor.bt
```

O:

```bash
sudo bpftrace exec_monitor.bt
```

---

# Script 2 — socket_create.bt

Archivo:

```bash
nano socket_create.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * socket_create.bt
 * Observa creación de sockets.
 */

tracepoint:syscalls:sys_enter_socket
{
    printf("SOCKET comm=%s pid=%d uid=%d domain=%d type=%d protocol=%d\n",
           comm, pid, uid, args->domain, args->type, args->protocol);
}
```

Ejecutar:

```bash
sudo bpftrace socket_create.bt
```

---

# Script 3 — connect_monitor.bt

Archivo:

```bash
nano connect_monitor.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * connect_monitor.bt
 * Observa intentos de conexión saliente.
 */

tracepoint:syscalls:sys_enter_connect
{
    printf("CONNECT_ENTER comm=%s pid=%d uid=%d fd=%d\n",
           comm, pid, uid, args->fd);
}

tracepoint:syscalls:sys_exit_connect
{
    printf("CONNECT_EXIT comm=%s pid=%d ret=%d\n",
           comm, pid, args->ret);
}
```

Ejecutar:

```bash
sudo bpftrace connect_monitor.bt
```

Probar:

```bash
curl https://example.com
```

---

# Script 4 — accept_monitor.bt

Archivo:

```bash
nano accept_monitor.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * accept_monitor.bt
 * Observa conexiones entrantes aceptadas por procesos locales.
 */

tracepoint:syscalls:sys_enter_accept4
{
    printf("ACCEPT4_ENTER comm=%s pid=%d uid=%d fd=%d\n",
           comm, pid, uid, args->fd);
}

tracepoint:syscalls:sys_exit_accept4
{
    printf("ACCEPT4_EXIT comm=%s pid=%d ret_fd=%d\n",
           comm, pid, args->ret);
}
```

Ejecutar:

```bash
sudo bpftrace accept_monitor.bt
```

Prueba:

```bash
python3 -m http.server 8080
```

Desde Guemes:

```bash
curl http://IP_MINIPC:8080
```

---

# Script 5 — file_activity.bt

Archivo:

```bash
nano file_activity.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * file_activity.bt
 * Observa apertura y borrado de archivos.
 */

tracepoint:syscalls:sys_enter_openat
{
    printf("OPEN comm=%s pid=%d uid=%d file=%s\n",
           comm, pid, uid, str(args->filename));
}

tracepoint:syscalls:sys_enter_unlinkat
{
    printf("DELETE comm=%s pid=%d uid=%d file=%s\n",
           comm, pid, uid, str(args->pathname));
}
```

Ejecutar:

```bash
sudo bpftrace file_activity.bt
```

---

# Script 6 — suspicious_exec.bt

Archivo:

```bash
nano suspicious_exec.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * suspicious_exec.bt
 * Observa ejecución de binarios usados frecuentemente en explotación.
 */

tracepoint:syscalls:sys_enter_execve
/str(args->filename) == "/bin/sh" ||
 str(args->filename) == "/bin/bash" ||
 str(args->filename) == "/usr/bin/nc" ||
 str(args->filename) == "/bin/nc" ||
 str(args->filename) == "/usr/bin/python3" ||
 str(args->filename) == "/usr/bin/perl" ||
 str(args->filename) == "/usr/bin/curl" ||
 str(args->filename) == "/usr/bin/wget"/
{
    printf("SUSPICIOUS_EXEC comm=%s pid=%d uid=%d file=%s\n",
           comm, pid, uid, str(args->filename));
}
```

Ejecutar:

```bash
sudo bpftrace suspicious_exec.bt
```

Probar:

```bash
curl http://example.com
bash -c 'echo test'
```

---

# Script 7 — syscall_counter.bt

Archivo:

```bash
nano syscall_counter.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * syscall_counter.bt
 * Cuenta syscalls por proceso.
 */

tracepoint:raw_syscalls:sys_enter
{
    @[comm] = count();
}

interval:s:5
{
    print(@);
    clear(@);
}
```

Ejecutar:

```bash
sudo bpftrace syscall_counter.bt
```

---

# Script 8 — python_http_observer.bt

Archivo:

```bash
nano python_http_observer.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * python_http_observer.bt
 * Observa actividad de un servidor python3 -m http.server.
 */

tracepoint:syscalls:sys_enter_accept4
/comm == "python3"/
{
    printf("PYTHON_HTTP accept4 pid=%d fd=%d\n", pid, args->fd);
}

tracepoint:syscalls:sys_enter_read
/comm == "python3"/
{
    printf("PYTHON_HTTP read pid=%d fd=%d count=%d\n", pid, args->fd, args->count);
}

tracepoint:syscalls:sys_enter_write
/comm == "python3"/
{
    printf("PYTHON_HTTP write pid=%d fd=%d count=%d\n", pid, args->fd, args->count);
}

tracepoint:syscalls:sys_enter_openat
/comm == "python3"/
{
    printf("PYTHON_HTTP open file=%s\n", str(args->filename));
}
```

Ejecutar:

```bash
sudo bpftrace python_http_observer.bt
```

En otra terminal:

```bash
python3 -m http.server 8080
```

Desde Guemes:

```bash
curl http://IP_MINIPC:8080
nmap -sV -p 8080 IP_MINIPC
```

---

# Script 9 — latency_connect.bt

Archivo:

```bash
nano latency_connect.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * latency_connect.bt
 * Mide duración de connect().
 */

tracepoint:syscalls:sys_enter_connect
{
    @start[tid] = nsecs;
}

tracepoint:syscalls:sys_exit_connect
/@start[tid]/
{
    $delta_us = (nsecs - @start[tid]) / 1000;
    printf("CONNECT_LATENCY comm=%s pid=%d ret=%d duration_us=%d\n",
           comm, pid, args->ret, $delta_us);
    delete(@start[tid]);
}
```

Ejecutar:

```bash
sudo bpftrace latency_connect.bt
```

Probar:

```bash
curl https://example.com
```

---

# Script 10 — nmap_activity.bt

Archivo:

```bash
nano nmap_activity.bt
```

Contenido:

```bpftrace
#!/usr/bin/env bpftrace

/*
 * nmap_activity.bt
 * Observa cómo reacciona el SO ante tráfico generado por nmap.
 * Usar junto con tcpdump y nmap desde Guemes.
 */

tracepoint:syscalls:sys_enter_accept4
{
    printf("ACCEPT4 comm=%s pid=%d fd=%d\n", comm, pid, args->fd);
}

tracepoint:syscalls:sys_exit_accept4
{
    printf("ACCEPT4_EXIT comm=%s pid=%d ret=%d\n", comm, pid, args->ret);
}

tracepoint:syscalls:sys_enter_read
{
    printf("READ comm=%s pid=%d fd=%d count=%d\n",
           comm, pid, args->fd, args->count);
}

tracepoint:syscalls:sys_enter_write
{
    printf("WRITE comm=%s pid=%d fd=%d count=%d\n",
           comm, pid, args->fd, args->count);
}
```

Ejecutar:

```bash
sudo bpftrace nmap_activity.bt
```

Desde Guemes:

```bash
nmap -sS IP_MINIPC
nmap -sV IP_MINIPC
nmap -O IP_MINIPC
nmap -A IP_MINIPC
```

---

## 10. Herramientas BCC listas

Estas herramientas ya vienen preparadas y son excelentes para aprender.

### Ver conexiones TCP salientes

```bash
sudo tcpconnect-bpfcc
```

---

### Ver vida de conexiones TCP

```bash
sudo tcplife-bpfcc
```

---

### Ver procesos nuevos

```bash
sudo execsnoop-bpfcc
```

---

### Ver archivos abiertos

```bash
sudo opensnoop-bpfcc
```

---

### Ver latencia de disco

```bash
sudo biolatency-bpfcc
```

---

### Ver latencia del scheduler

```bash
sudo runqlat-bpfcc
```

---

### Ver tráfico TCP por proceso

```bash
sudo tcptop-bpfcc
```

---

## 11. Prueba controlada con servidor HTTP

En mini PC:

```bash
mkdir -p ~/http-test
cd ~/http-test
echo "hola desde mini pc debian 12" > index.html
python3 -m http.server 8080
```

En otra terminal de mini PC:

```bash
sudo bpftrace ~/ebpf-lab/scripts/python_http_observer.bt
```

Desde Guemes:

```bash
curl http://IP_MINIPC:8080
nmap -sV -p 8080 IP_MINIPC
```

También observar con tcpdump:

```bash
sudo tcpdump -i any port 8080 -nn
```

---

## 12. Prueba controlada con nmap desde Guemes

Desde Guemes:

```bash
nmap -sS IP_MINIPC
```

```bash
nmap -sT IP_MINIPC
```

```bash
nmap -sV -p 22,80,443,8080 IP_MINIPC
```

```bash
nmap -O IP_MINIPC
```

```bash
nmap -A IP_MINIPC
```

En mini PC observar:

```bash
sudo tcpdump -i any host IP_GUEMES -nn
```

```bash
sudo bpftrace ~/ebpf-lab/scripts/nmap_activity.bt
```

```bash
sudo tcplife-bpfcc
```

```bash
sudo execsnoop-bpfcc
```

---

## 13. Qué esperar con diferentes tipos de nmap

### SYN scan

```bash
nmap -sS IP_MINIPC
```

Puede generar poco impacto en syscalls de aplicaciones si no hay servicios aceptando conexiones.

Se observa mejor con:

```bash
sudo tcpdump -i any host IP_GUEMES -nn
```

y hooks de red más avanzados.

---

### TCP connect scan

```bash
nmap -sT IP_MINIPC
```

Genera conexiones TCP completas.

Se observa mejor con:

```bash
sudo tcplife-bpfcc
sudo tcpconnect-bpfcc
```

---

### Version detection

```bash
nmap -sV -p 8080 IP_MINIPC
```

Si hay un servicio activo, por ejemplo `python3 -m http.server`, se ven:

```text
accept4()
read()
write()
openat()
close()
```

---

### OS detection

```bash
nmap -O IP_MINIPC
```

Genera paquetes particulares para fingerprinting.

Se ve más claramente con:

```bash
sudo tcpdump -i any host IP_GUEMES -nn -vv
```

---

## 14. Mini metodología de análisis

Cuando llegue tráfico sospechoso, mirar en este orden:

```text
1. tcpdump
2. socket/connect/accept
3. read/write
4. execve
5. openat/unlinkat
6. latencia
7. consumo CPU/scheduler
```

Comandos:

```bash
sudo tcpdump -i any host IP_ATACANTE -nn
```

```bash
sudo bpftrace socket_create.bt
```

```bash
sudo bpftrace accept_monitor.bt
```

```bash
sudo bpftrace suspicious_exec.bt
```

```bash
sudo bpftrace file_activity.bt
```

```bash
sudo runqlat-bpfcc
```

---

## 15. Estructura recomendada del repo

```text
ebpf-test-jorsat/
├── README.md
├── docs/
│   ├── debian12-ebpf-lab.md
│   ├── nmap-tests.md
│   └── troubleshooting.md
├── scripts/
│   ├── exec_monitor.bt
│   ├── socket_create.bt
│   ├── connect_monitor.bt
│   ├── accept_monitor.bt
│   ├── file_activity.bt
│   ├── suspicious_exec.bt
│   ├── syscall_counter.bt
│   ├── python_http_observer.bt
│   ├── latency_connect.bt
│   └── nmap_activity.bt
└── tests/
    ├── curl-tests.sh
    ├── nmap-basic.sh
    └── nmap-http-server.sh
```

---

## 16. Script Bash para crear todos los .bt

Crear:

```bash
nano create-ebpf-scripts.sh
```

Contenido:

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p ~/ebpf-lab/scripts
cd ~/ebpf-lab/scripts

cat > exec_monitor.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_execve
{
    printf("EXEC time=%llu comm=%s pid=%d uid=%d file=%s\n",
           nsecs, comm, pid, uid, str(args->filename));
}
EOF

cat > socket_create.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_socket
{
    printf("SOCKET comm=%s pid=%d uid=%d domain=%d type=%d protocol=%d\n",
           comm, pid, uid, args->domain, args->type, args->protocol);
}
EOF

cat > connect_monitor.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_connect
{
    printf("CONNECT_ENTER comm=%s pid=%d uid=%d fd=%d\n",
           comm, pid, uid, args->fd);
}

tracepoint:syscalls:sys_exit_connect
{
    printf("CONNECT_EXIT comm=%s pid=%d ret=%d\n",
           comm, pid, args->ret);
}
EOF

cat > accept_monitor.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_accept4
{
    printf("ACCEPT4_ENTER comm=%s pid=%d uid=%d fd=%d\n",
           comm, pid, uid, args->fd);
}

tracepoint:syscalls:sys_exit_accept4
{
    printf("ACCEPT4_EXIT comm=%s pid=%d ret_fd=%d\n",
           comm, pid, args->ret);
}
EOF

cat > file_activity.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_openat
{
    printf("OPEN comm=%s pid=%d uid=%d file=%s\n",
           comm, pid, uid, str(args->filename));
}

tracepoint:syscalls:sys_enter_unlinkat
{
    printf("DELETE comm=%s pid=%d uid=%d file=%s\n",
           comm, pid, uid, str(args->pathname));
}
EOF

cat > suspicious_exec.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_execve
/str(args->filename) == "/bin/sh" ||
 str(args->filename) == "/bin/bash" ||
 str(args->filename) == "/usr/bin/nc" ||
 str(args->filename) == "/bin/nc" ||
 str(args->filename) == "/usr/bin/python3" ||
 str(args->filename) == "/usr/bin/perl" ||
 str(args->filename) == "/usr/bin/curl" ||
 str(args->filename) == "/usr/bin/wget"/
{
    printf("SUSPICIOUS_EXEC comm=%s pid=%d uid=%d file=%s\n",
           comm, pid, uid, str(args->filename));
}
EOF

cat > syscall_counter.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:raw_syscalls:sys_enter
{
    @[comm] = count();
}

interval:s:5
{
    print(@);
    clear(@);
}
EOF

cat > python_http_observer.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_accept4
/comm == "python3"/
{
    printf("PYTHON_HTTP accept4 pid=%d fd=%d\n", pid, args->fd);
}

tracepoint:syscalls:sys_enter_read
/comm == "python3"/
{
    printf("PYTHON_HTTP read pid=%d fd=%d count=%d\n", pid, args->fd, args->count);
}

tracepoint:syscalls:sys_enter_write
/comm == "python3"/
{
    printf("PYTHON_HTTP write pid=%d fd=%d count=%d\n", pid, args->fd, args->count);
}

tracepoint:syscalls:sys_enter_openat
/comm == "python3"/
{
    printf("PYTHON_HTTP open file=%s\n", str(args->filename));
}
EOF

cat > latency_connect.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_connect
{
    @start[tid] = nsecs;
}

tracepoint:syscalls:sys_exit_connect
/@start[tid]/
{
    $delta_us = (nsecs - @start[tid]) / 1000;
    printf("CONNECT_LATENCY comm=%s pid=%d ret=%d duration_us=%d\n",
           comm, pid, args->ret, $delta_us);
    delete(@start[tid]);
}
EOF

cat > nmap_activity.bt <<'EOF'
#!/usr/bin/env bpftrace

tracepoint:syscalls:sys_enter_accept4
{
    printf("ACCEPT4 comm=%s pid=%d fd=%d\n", comm, pid, args->fd);
}

tracepoint:syscalls:sys_exit_accept4
{
    printf("ACCEPT4_EXIT comm=%s pid=%d ret=%d\n", comm, pid, args->ret);
}

tracepoint:syscalls:sys_enter_read
{
    printf("READ comm=%s pid=%d fd=%d count=%d\n",
           comm, pid, args->fd, args->count);
}

tracepoint:syscalls:sys_enter_write
{
    printf("WRITE comm=%s pid=%d fd=%d count=%d\n",
           comm, pid, args->fd, args->count);
}
EOF

chmod +x *.bt

echo "Scripts creados en ~/ebpf-lab/scripts"
ls -l ~/ebpf-lab/scripts
```

Ejecutar:

```bash
chmod +x create-ebpf-scripts.sh
./create-ebpf-scripts.sh
```

---

## 17. Troubleshooting rápido

### Error: command not found

```bash
which bpftrace
which bpftool
```

Instalar:

```bash
sudo apt install -y bpftrace bpftool bpfcc-tools
```

---

### Error: failed to load BPF program

Verificar:

```bash
cat /sys/kernel/security/lockdown
```

```bash
sysctl kernel.unprivileged_bpf_disabled
```

Ejecutar siempre con:

```bash
sudo
```

---

### Error con BTF

Verificar:

```bash
ls /sys/kernel/btf/vmlinux
```

---

### No veo eventos

Puede ser porque:

```text
el evento no ocurre
el proceso no coincide con el filtro comm
el servicio no está corriendo
el tráfico no llega
el firewall bloquea antes
el script mira syscall y el scan no llega a aplicación
```

Validar con:

```bash
sudo tcpdump -i any -nn
```

---

## 18. Orden recomendado de práctica

Día 1:

```text
execve
socket
connect
accept
tcpconnect-bpfcc
tcplife-bpfcc
```

Día 2:

```text
python http server
curl desde Guemes
nmap -sT
nmap -sV
file_activity
read/write
```

Día 3:

```text
tcpdump + bpftrace
latencias
syscall_counter
comparar -sS vs -sT
```

Día 4:

```text
empezar kprobes
estudiar tcp_connect
tcp_v4_connect
inet_csk_accept
```

Día 5:

```text
mirar XDP en modo observación
sin drops todavía
```

---

## 19. Comandos finales de referencia

```bash
sudo bpftrace -l
```

```bash
sudo bpftrace -l 'tracepoint:syscalls:*'
```

```bash
sudo bpftrace -l '*tcp*'
```

```bash
sudo bpftool prog show
```

```bash
sudo bpftool map show
```

```bash
sudo bpftool feature probe
```

```bash
sudo tcpconnect-bpfcc
```

```bash
sudo tcplife-bpfcc
```

```bash
sudo execsnoop-bpfcc
```

```bash
sudo opensnoop-bpfcc
```

```bash
sudo tcpdump -i any -nn
```

---

## 20. Idea central

El objetivo no es solamente ver paquetes.

El objetivo es responder:

```text
cuando llega tráfico peligroso,
¿qué pasa realmente dentro del sistema operativo?
```

Con eBPF se puede observar:

```text
syscalls
procesos
sockets
latencia
filesystem
ejecución de comandos
actividad de red
comportamiento del kernel
```

Ese es el camino para construir una plataforma Jorsat más avanzada.
