#!/bin/bash

# Obtener el nombre del hypervisor (servidor actual)
hypervisor_name=$(hostname)

# Obtener el nombre del pool
pool_name=$(xe pool-list params=name-label --minimal)

# Obtener la fecha actual en formato YYYY-MM-DD
current_date=$(date +"%Y-%m-%d")

# Definir el nombre del archivo de salida con fecha, nombre del hypervisor y del pool
output_file="inventario_${hypervisor_name}_${pool_name}_${current_date}.csv"

# Encabezado del archivo CSV
echo "VM Name, VM Power State, Host Server, CPU Count, Memory (MB), Disk 1 (GB), Disk 2 (GB), Disk 3 (GB), Disk 4 (GB), Number of Disks, OS Type, Creation Date, Uptime, MAC Addresses, IP Addresses" > "$output_file"

# Obtener todas las máquinas virtuales en el pool
vm_list=$(xe vm-list is-control-domain=false --minimal)

# Separar las VMs por comas
IFS=',' read -ra vm_array <<< "$vm_list"

# Función para convertir ISO 8601 a formato aceptable para `date`
convert_iso8601_to_date() {
    local iso_date="$1"
    if [[ "$iso_date" =~ ^[0-9]{8}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        echo "$iso_date" | sed -e 's/T/ /' -e 's/Z//'
    else
        echo "N/A"
    fi
}

# Recorrer cada VM y obtener la información deseada
for vm_uuid in "${vm_array[@]}"; do
    # Obtener nombre de la VM
    vm_name=$(xe vm-param-get uuid=$vm_uuid param-name=name-label)

    # Obtener el estado de la VM (encendida o apagada)
    vm_power_state=$(xe vm-param-get uuid=$vm_uuid param-name=power-state)

    # Obtener el UUID del host donde reside la VM
    host_uuid=$(xe vm-param-get uuid=$vm_uuid param-name=resident-on)

    # Verificar si el UUID del host es válido
    if [ -n "$host_uuid" ] && [ "$host_uuid" != "<not" ]; then
        # Obtener el nombre del host (servidor) en el que reside la VM
        host_name=$(xe host-param-get uuid=$host_uuid param-name=name-label)
    else
        # Si no se pudo obtener el host, asignar "N/A"
        host_name="N/A"
    fi

    # Obtener la cantidad de CPUs asignadas
    vm_cpu_count=$(xe vm-param-get uuid=$vm_uuid param-name=VCPUs-max)

    # Obtener la memoria asignada (en bytes y luego convertir a MB)
    vm_memory_bytes=$(xe vm-param-get uuid=$vm_uuid param-name=memory-static-max)
    vm_memory_mb=$(($vm_memory_bytes / 1024 / 1024))

    # Obtener los discos conectados a la VM
    vbd_list=$(xe vbd-list vm-uuid=$vm_uuid type=Disk --minimal)

    # Separar los VBDs conectados
    IFS=',' read -ra vbd_array <<< "$vbd_list"

    # Inicializar el tamaño de los discos
    disk_sizes=("N/A" "N/A" "N/A" "N/A")  # Vamos a mostrar hasta 4 discos

    # Recorrer los VBDs y obtener el tamaño de cada disco
    for i in "${!vbd_array[@]}"; do
        if [ "$i" -ge 4 ]; then
            break  # Limitar a 4 discos en total
        fi
        vdi_uuid=$(xe vbd-param-get uuid=${vbd_array[$i]} param-name=vdi-uuid)
        disk_size_bytes=$(xe vdi-param-get uuid=$vdi_uuid param-name=virtual-size)
        disk_sizes[$i]=$(($disk_size_bytes / 1024 / 1024 / 1024))  # Convertir de bytes a GB
    done

    # Número de discos
    number_of_disks=${#vbd_array[@]}

    # Obtener el tipo de sistema operativo
    os_type=$(xe vm-param-get uuid=$vm_uuid param-name=os-version 2>/dev/null)

    # Verificar si se pudo obtener el tipo de OS, si no asignar 'N/A'
    if [ -z "$os_type" ]; then
        os_type="N/A"
    fi

    # Obtener la fecha de creación (install-time) y convertirla a formato legible
    creation_timestamp=$(xe vm-param-get uuid=$vm_uuid param-name=install-time 2>/dev/null)
    creation_date=$(convert_iso8601_to_date "$creation_timestamp")

    # Obtener el tiempo de actividad (uptime) si la VM está en ejecución
    if [ "$vm_power_state" == "running" ]; then
        start_timestamp=$(xe vm-param-get uuid=$vm_uuid param-name=start-time 2>/dev/null)
        start_date=$(convert_iso8601_to_date "$start_timestamp")
        
        if [ "$start_date" != "N/A" ]; then
            # Convertir el start_date a Unix timestamp y calcular el uptime
            start_timestamp_unix=$(date --date="$start_date" +%s)
            uptime=$(($(date +%s) - $start_timestamp_unix))
            uptime_days=$(($uptime / 86400))
            uptime_hours=$((($uptime % 86400) / 3600))
            uptime_minutes=$((($uptime % 3600) / 60))
            uptime="${uptime_days}d ${uptime_hours}h ${uptime_minutes}m"
        else
            uptime="N/A"
        fi
    else
        uptime="N/A"
    fi

    # Obtener las interfaces de red asociadas a la VM
    vifs=$(xe vif-list vm-uuid=$vm_uuid --minimal)

    # Inicializar variables para las MACs y las IPs
    mac_addresses=""
    ip_addresses=""

    # Obtener la información de las redes de la VM
    networks_info=$(xe vm-param-get uuid=$vm_uuid param-name=networks)

    # Procesar cada interfaz de red (VIF)
    IFS=',' read -ra vif_array <<< "$vifs"
    for vif_uuid in "${vif_array[@]}"; do
        # Obtener la dirección MAC de la interfaz
        mac_address=$(xe vif-param-get uuid=$vif_uuid param-name=MAC)

        # Buscar la IP correspondiente a la MAC en la información de redes
#        ip_address=$(echo "$networks_info" | grep "$mac_address" | awk '{print $2}' | sed 's/;//')
        ip_address=$(xe vm-param-get uuid=$vm_uuid param-name=networks | awk '{print $2 }' |sed 's/;//')


        # Verificar si hay una IP asignada, de lo contrario asignar 'N/A'
        if [ -z "$ip_address" ]; then
            ip_address="N/A"
        fi

        # Concatenar la MAC e IP separadamente
        mac_addresses+="$mac_address; "
        ip_addresses+="$ip_address; "
    done

    # Remover el último punto
    # Remover el último punto y coma en MAC y IP, pero solo si la longitud es mayor a 2
    if [ ${#mac_addresses} -gt 2 ]; then
        mac_addresses=${mac_addresses::-2}
    fi
    if [ ${#ip_addresses} -gt 2 ]; then
        ip_addresses=${ip_addresses::-2}
    fi

    # Escribir la información en el archivo CSV, incluyendo discos adicionales
    echo "\"$vm_name\", \"$vm_power_state\", \"$host_name\", \"$vm_cpu_count\", \"$vm_memory_mb\", \"${disk_sizes[0]}\", \"${disk_sizes[1]}\", \"${disk_sizes[2]}\", \"${disk_sizes[3]}\", \"$number_of_disks\", \"$os_type\", \"$creation_date\", \"$uptime\", \"$mac_addresses\", \"$ip_addresses\"" >> "$output_file"
done

echo "Inventario generado: $output_file"
