#!/bin/bash

# Storage Selection
STORAGE_MENU=$(pvesm status --output-format json | jq -r '.[].storage')
echo "Available storage:"
select STORAGE in $STORAGE_MENU; do
    if [[ " $STORAGE_MENU " =~ " $STORAGE " ]]; then
        break
    else
        echo "Invalid storage option. Please choose again."
    fi
done

# Network Configuration
read -p "Enter bridge name [vmbr0]: " BRIDGE
if [ -z "$BRIDGE" ]; then
    BRIDGE="vmbr0"
fi

read -p "Enter MAC address (e.g., 52:54:00:1a:2b:3c): " MAC_ADDRESS
read -p "Enter VLAN tag (optional, press Enter for none): " VLAN_TAG
if [ -z "$VLAN_TAG" ]; then
    VLAN_TAG=""
else
    VLAN_TAG="tag=$VLAN_TAG"
fi

read -p "Enter MTU size (default is 1500): " MTU
if [ -z "$MTU" ]; then
    MTU=1500
fi

# Resource Allocation
read -p "Enter VM CPU count [2]: " CPU_COUNT
if [ -z "$CPU_COUNT" ]; then
    CPU_COUNT=2
fi

read -p "Enter VM RAM size (in MB) [4096]: " RAM_SIZE
if [ -z "$RAM_SIZE" ]; then
    RAM_SIZE=4096
fi

# Additional VM Options
read -p "Enable QEMU Guest Agent? (y/n) [y]: " AGENT_ENABLED
if [ -z "$AGENT_ENABLED" ] || [[ $AGENT_ENABLED == "y" ]]; then
    AGENT_ENABLED="1"
else
    AGENT_ENABLED="0"
fi

# Download Ubuntu 24.04 Disk Image
URL="http://cdimage.debian.org/debian-cd/current-amd64/iso-cd/debian-24.04.1-amd64-netinst.iso"

# VM Configuration Variables
MACHINE="qemu-server"
CPU_TYPE="host"
DISK_CACHE="writeback"
VMID=$(qm config <VM_ID> | grep -oP 'vmid:\s*\K\d+')

echo "Starting VM creation..."

# Create VM
qm create $VMID --name ubuntu2404 --ostype l26 --net0 bridge=$BRIDGE,firewall=1,model=virtio,macaddr=$MAC_ADDRESS,$VLAN_TAG,mtu=$MTU --cores $CPU_COUNT --memory $RAM_SIZE --agent $AGENT_ENABLED

# Allocate Storage
pvesm alloc $STORAGE $VMID 20G

# Import Disk Image
qm importdisk $VMID $URL $STORAGE -format raw

# Set VM Configuration
qm set $VMID --scsihw virtio-scsi-pci --ide2 $STORAGE:$VMID/vm-$VMID-disk-0.raw,media=disk --bootorder cdn --efidisk0 /dev/pve/efidisk0,efipart=1

# Completion Messages
echo "VM created successfully with ID: $VMID"
echo "Please note the VM will boot from the downloaded disk image."
