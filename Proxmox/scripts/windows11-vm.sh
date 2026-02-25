#! /bin/bash

# Copyright (c) 2024-present juronja
# Used code from https://github.com/tteck to some degree
# Author: juronja
# License: MIT

# Constant variables for dialogs
NEXTID=$(pvesh get /cluster/nextid)
NODE=$(hostname)

# Functions
function check_root() {
  if [[ "$(id -u)" != 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Install - Windows VM" --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
        echo "you've been warned"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

echo "Starting VM script .."

# Whiptail inputs

while read -r LSOUTPUT; do
  TRUNCATED="${LSOUTPUT:0:65}"
  if [ ${#LSOUTPUT} -gt 65 ]; then
    TRUNCATED="${TRUNCATED}..."
  fi
  ISOARRAY+=("$LSOUTPUT" "$TRUNCATED" "OFF")
done < <(ls /var/lib/vz/template/iso)

if WIN_ISO=$(whiptail --backtitle "Install - Windows 11 VM" --title "ISO FILE NAME" --radiolist "\nSelect the ISO to install. (Use Spacebar to select)\n" --notags --cancel-button "Exit Script" 18 78 8 "${ISOARRAY[@]}" 3>&1 1>&2 2>&3 | tr -d '"'); then
  echo -e "Selected iso: $WIN_ISO"
else
  exit-script
fi

if CORE_COUNT=$(whiptail --backtitle "Install - Windows 11 VM" --title "CORE COUNT" --radiolist "\nAllocate number of CPU Cores. (Use Spacebar to select)\n" --cancel-button "Exit Script" 12 58 3 \
  "4" "cores" ON \
  "8" "cores" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Allocated Cores: $CORE_COUNT"
else
  exit-script
fi

if RAM_COUNT=$(whiptail --backtitle "Install - Windows 11 VM" --title "RAM COUNT" --radiolist "\nAllocate number of RAM. (Use Spacebar to select)\n" --cancel-button "Exit Script" 12 58 3 \
  "8" "GB" OFF \
  "16" "GB" ON \
  "32" "GB" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Allocated RAM: $RAM_COUNT GB"
else
  exit-script
fi

if DISK_SIZE=$(whiptail --backtitle "Install - Windows 11 VM" --title "DISK SIZE" --radiolist "\nSelect disk size. (Use Spacebar to select)\n" --cancel-button "Exit Script" 12 58 3 \
  "128" "GB" OFF \
  "256" "GB" ON \
  "512" "GB" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Disk size: $DISK_SIZE GB"
else
  exit-script
fi

if VLAN1=$(whiptail --backtitle "Install - Windows Server VM" --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
  if [ -z $VLAN1 ]; then
    VLAN1="Default"
    VLAN=""
    echo -e "Vlan tag: $VLAN1"
  else
    VLAN=",tag=$VLAN1"
    echo -e "Vlan tag: $VLAN1"
  fi
else
  exit-script
fi

# Constant variables
NAME="windows11"
CPU="x86-64-v3"
VMID=$NEXTID
RAM=$(($RAM_COUNT * 1024))
IMG_LOCATION="/var/lib/vz/template/iso/"

# Download the VirtIO drivers stable for Windows
wget -nc --directory-prefix=$IMG_LOCATION https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

# Create a VM
qm create $VMID --ostype win11 --cores $CORE_COUNT --cpu $CPU --memory $RAM --name $NAME --bios ovmf --vga std --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=1 --machine q35 --tpmstate0 local-lvm:1,version=v2.0 --scsihw virtio-scsi-single --scsi0 local-lvm:$DISK_SIZE,ssd=on,iothread=on --ide0 local:iso/$WIN_ISO,media=cdrom --ide1 local:iso/virtio-win.iso,media=cdrom --net0 virtio,bridge=vmbr0,firewall=1$VLAN --ipconfig0 ip=dhcp,ip6=dhcp --agent enabled=1 --onboot 1 --boot order="ide0;scsi0"
