# 📦 XCP-ng VM Inventory

> Script de Bash para generar un inventario completo de máquinas virtuales en un pool XCP-ng / XenServer, exportado en formato CSV.

Desarrollado por **Cristian Omar Jiménez Sánchez** · [@crisomarjs](https://github.com/crisomarjs)

---

## 📋 Descripción

Genera un archivo CSV con información detallada de todas las VMs en el pool XCP-ng: estado de encendido, host donde residen, recursos asignados (CPU, RAM, discos), sistema operativo, fecha de creación, uptime y configuración de red (MAC e IP).

El archivo de salida se nombra automáticamente con el nombre del hypervisor, el nombre del pool y la fecha de ejecución, facilitando su archivo histórico y trazabilidad.

---

## ✅ Requisitos

| Requisito     | Detalle                                              |
|---------------|------------------------------------------------------|
| Sistema       | XCP-ng 8.x / XenServer 7.x o superior               |
| Ejecución     | Directamente en el **Dom0** del hypervisor           |
| Permisos      | Root o usuario con acceso a `xe` CLI                 |
| Dependencias  | `xe`, `bash`, `date`, `awk`, `sed` (incluidos en Dom0) |

> No requiere instalación de paquetes adicionales. Todas las herramientas usadas forman parte del sistema base de XCP-ng.

---

## 🚀 Uso

### 1. Copiar el script al Dom0

```bash
scp vm_inventory.sh root@<IP_DEL_HYPERVISOR>:/root/
```

### 2. Dar permisos de ejecución

```bash
chmod +x vm_inventory.sh
```

### 3. Ejecutar

```bash
./vm_inventory.sh
```

El script genera el CSV en el directorio actual y muestra el nombre del archivo al finalizar.

---

## 📂 Archivo de salida

El nombre del archivo se genera automáticamente con el siguiente formato:

```
inventario_<HYPERVISOR>_<POOL>_<FECHA>.csv
```

**Ejemplo:**

```
inventario_XCP-PROD-01_PoolDatacenter_2025-06-10.csv
```

---

## 📊 Columnas del CSV

| Columna           | Descripción                                           |
|-------------------|-------------------------------------------------------|
| `VM Name`         | Nombre de la máquina virtual                          |
| `VM Power State`  | Estado actual: `running`, `halted`, `suspended`       |
| `Host Server`     | Nombre del host donde reside la VM                    |
| `CPU Count`       | Número de vCPUs asignadas (VCPUs-max)                 |
| `Memory (MB)`     | Memoria estática máxima en MB                         |
| `Disk 1 (GB)`     | Tamaño del primer disco virtual en GB                 |
| `Disk 2 (GB)`     | Tamaño del segundo disco virtual en GB                |
| `Disk 3 (GB)`     | Tamaño del tercer disco virtual en GB                 |
| `Disk 4 (GB)`     | Tamaño del cuarto disco virtual en GB                 |
| `Number of Disks` | Total de discos tipo `Disk` conectados a la VM        |
| `OS Type`         | Información del SO reportada por XenTools (`os-version`) |
| `Creation Date`   | Fecha de instalación/creación de la VM (`install-time`) |
| `Uptime`          | Tiempo encendida en formato `Xd Xh Xm` (solo si running) |
| `MAC Addresses`   | MACs de todas las interfaces de red, separadas por `;` |
| `IP Addresses`    | IPs reportadas por XenTools, separadas por `;`        |

> **Nota:** Las columnas `OS Type`, `IP Addresses` y `Uptime` requieren que **XenServer Tools (xe-guest-utilities)** estén instaladas y en ejecución dentro de la VM. Sin las guest tools, estos campos mostrarán `N/A`.
---

<p align="center">
  Desarrollado con ❤️ para equipos de infraestructura y virtualización
</p>
