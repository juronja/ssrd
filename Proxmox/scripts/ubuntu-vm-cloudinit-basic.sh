#!/usr/bin/env bash
# Copyright (c) 2024-present juronja
# Used parts from https://github.com/community-scripts to some extent
# Author: juronja
# License: MIT

# Constant variables for dialogs
NEXTID=$(pvesh get /cluster/nextid)
NODE=$(hostname)

# Functions

# Colors
# YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
# RD=$(echo "\033[01;31m")
# GN=$(echo "\033[1;92m")

# Formatting
CL=$(echo "\033[m")

# FUNCTIONS

# This function checks if the script is running through SSH and prompts the user to confirm if they want to proceed or exit.
ssh_check() {
  if [ -n "${SSH_CLIENT:+x}" ]; then
    if whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "SSH DETECTED" --yesno "It's advisable to utilize the Proxmox shell rather than SSH, as there may be potential complications with variable retrieval. Proceed using SSH?" 10 72; then
      whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox --title "Proceed using SSH" "You've chosen to proceed using SSH. If any issues arise, please run the script in the Proxmox shell before creating a repository issue." 10 72
    else
      clear
      echo "Exiting due to SSH usage. Please consider using the Proxmox shell."
      exit
    fi
  fi
}

# This function is called when the user decides to exit the script. It clears the screen and displays an exit message.
function exit_script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

### MAIN SCRIPT ###
echo "Starting VM script .."

# WHIPTAIL VM INPUTS
if UBUNTU_RLS=$(whiptail --backtitle "Install - Ubuntu VM" --title "UBUNTU RELEASE" --radiolist "\nChoose the release to install. (Spacebar to select)\n" --cancel-button "Exit Script" 12 58 2 \
  "noble" "24.04 LTS" ON \
  "jammy" "22.04 LTS" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Release version: $UBUNTU_RLS"
else
  exit_script
fi

if CORE_COUNT=$(whiptail --backtitle "Install - Ubuntu VM" --title "CORE COUNT" --radiolist "\nAllocate number of CPU Cores. (Spacebar to select)\n" --cancel-button "Exit Script" 12 58 4 \
  "2" "cores" ON \
  "4" "cores" OFF \
  "6" "cores" OFF \
  "8" "cores" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Allocated Cores: $CORE_COUNT"
else
  exit_script
fi

if RAM_COUNT=$(whiptail --backtitle "Install - Ubuntu VM" --title "RAM COUNT" --radiolist "\nAllocate number of RAM. (Spacebar to select)\n" --cancel-button "Exit Script" 12 58 4 \
  "2" "GB" OFF \
  "4" "GB" ON \
  "8" "GB" OFF \
  "12" "GB" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Allocated RAM: $RAM_COUNT GB"
else
  exit_script
fi

if DISK_SIZE=$(whiptail --backtitle "Install - Ubuntu VM" --title "DISK SIZE" --radiolist "\nAllocate disk size. (Spacebar to select)\n" --cancel-button "Exit Script" 12 58 4 \
  "32" "GB" OFF \
  "48" "GB" ON \
  "64" "GB" OFF \
  "128" "GB" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Allocated disk size: $DISK_SIZE GB"
else
  exit_script
fi

if VM_NAME=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nSet the name of the VM" 8 58 "homelab" --title "NAME" --cancel-button "Exit Script" 3>&1 1>&2 2>&3); then
  if [[ -z $VM_NAME ]]; then
    VM_NAME="homelab"
    echo -e "Name: $VM_NAME"
  else
    echo -e "Name: $VM_NAME"
  fi
else
  exit_script
fi

while true; do
  if OS_IPv4_CIDR=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nSet a Static IPv4 CIDR Address (/24)" 8 58 "dhcp" --title "CLOUD-INIT IPv4 CIDR" --cancel-button "Exit Script" 3>&1 1>&2 2>&3); then
    if [ -z $OS_IPv4_CIDR ]; then
      OS_IPv4_CIDR="dhcp"
      break
    elif [ "$OS_IPv4_CIDR" = "dhcp" ]; then
      break
    elif [[ "$OS_IPv4_CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
      echo -e "IPv4 Address: $OS_IPv4_CIDR"
      break
    else
      whiptail --backtitle "Install - Ubuntu VM" --msgbox "$OS_IPv4_CIDR is an invalid IPv4 CIDR address. Please enter a valid IPv4 CIDR address or 'dhcp'" 8 58
    fi
  else
    exit_script
  fi
done

if [[ $OS_IPv4_CIDR != "dhcp" ]]; then
  SUGGESTED_GW=$(echo "$OS_IPv4_CIDR" | sed 's/\.[0-9]\{1,3\}\/\([0-9]\+\)$/.1/')
  while true; do
    if OS_IPv4_GW=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nEnter gateway IP address" 8 58 "$SUGGESTED_GW" --title "CLOUD-INIT IPv4 GATEWAY" --cancel-button "Exit Script" 3>&1 1>&2 2>&3); then
      if [[ -z $OS_IPv4_GW ]]; then
        whiptail --backtitle "Install - Ubuntu VM" --msgbox "Gateway IP address cannot be empty" 8 58
      elif [[ ! "$OS_IPv4_GW" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        whiptail --backtitle "Install - Ubuntu VM" --msgbox "Invalid IP address format" 8 58
      else
        OS_IPv4_GW_FULL=",gw=$OS_IPv4_GW"
        echo -e "Gateway IP Address: $OS_IPv4_GW"
        break # Exit the loop after a valid gateway IP is entered
      fi
    else
      exit_script
    fi
  done
fi

# WHIPTAIL FIREWALL RULES
if whiptail --backtitle "Install - Ubuntu VM" --title "PROXMOX FIREWALL" --yesno --defaultno "Do you want to enable Proxmox FIREWALL?" 10 62; then
  fw=1
  if tcpPorts=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nWrite comma seperated TCP ports to expose on WAN" 10 58 "7474,3131," --title "EXPOSE TCP PORTS" --cancel-button "Skip" 3>&1 1>&2 2>&3); then
    tcp=1
    echo "Will open TCP Ports: $tcpPorts"
  else
    echo "TCP ports skipped .."
  fi
  if udpPorts=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nWrite comma seperated UDP ports to expose on WAN" 10 58 "8082," --title "EXPOSE UDP PORTS" --cancel-button "Skip" 3>&1 1>&2 2>&3); then
    udp=1
    echo "Will open UDP Ports: $udpPorts"
  else
    echo "UDP ports skipped .."
  fi
else
  echo "FIREWALL setup skipped .."
fi

# Proxmox variables
RAM=$(($RAM_COUNT * 1024))
IMG_LOCATION="/var/lib/vz/template/iso/"
CPU="x86-64-v3"
CLUSTER_FW_ENABLED=$(pvesh get /cluster/firewall/options --output-format json | sed -n 's/.*"enable": *\([0-9]*\).*/\1/p')
LOCAL_NETWORK=$(pve-firewall localnet | grep local_network | cut -d':' -f2 | sed 's/ //g')
HOME_NETWORK_ALIAS="home_network"
PROXY_ALIAS="proxy"
PROXY_CIDR="192.168.84.254"
GROUP_LOCAL="local-ssh-ping"

# Download the Ubuntu cloud init image
wget -nc --directory-prefix=$IMG_LOCATION https://cloud-images.ubuntu.com/$UBUNTU_RLS/current/$UBUNTU_RLS-server-cloudimg-amd64.img

# Create a VM
qm create $NEXTID --ostype l26 --cores $CORE_COUNT --cpu $CPU --numa 1 --memory $RAM --name $VM_NAME --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr0,firewall=1 --serial0 socket --vga serial0 --ipconfig0 ip=$OS_IPv4_CIDR$OS_IPv4_GW_FULL --agent enabled=1 --onboot 1

# Import cloud image disk
qm disk import $NEXTID $IMG_LOCATION$UBUNTU_RLS-server-cloudimg-amd64.img local-lvm --format qcow2

# Map cloud image disk
qm set $NEXTID --scsi0 local-lvm:vm-$NEXTID-disk-0,discard=on,ssd=1 --ide2 local-lvm:cloudinit

# Resize the disk
qm disk resize $NEXTID scsi0 "${DISK_SIZE}G" && qm set $NEXTID --boot order=scsi0

# Configure Cluster level firewall rules if not enabled
if [[ $CLUSTER_FW_ENABLED != 1 ]]; then
  pvesh set /cluster/firewall/options --enable 1
  pvesh create /cluster/firewall/aliases --name $HOME_NETWORK_ALIAS --cidr $LOCAL_NETWORK
  pvesh create /cluster/firewall/aliases --name $PROXY_ALIAS --cidr $PROXY_CIDR
  pvesh create /cluster/firewall/groups --group $GROUP_LOCAL
  sleep 2
  pvesh create /cluster/firewall/rules --action ACCEPT --type in --iface vmbr0 --source $HOME_NETWORK_ALIAS --macro Ping --enable 1
  pvesh create /cluster/firewall/groups/$GROUP_LOCAL --action ACCEPT --type in --source $HOME_NETWORK_ALIAS --proto tcp --enable 1
  pvesh create /cluster/firewall/groups/$GROUP_LOCAL --action ACCEPT --type in --source $HOME_NETWORK_ALIAS --macro Ping --enable 1
  pvesh create /cluster/firewall/groups/$GROUP_LOCAL --action ACCEPT --type in --source $HOME_NETWORK_ALIAS --macro SSH --enable 1
  echo "Cluster Firewall configurations set successfully .."
else
  echo "Cluster Firewall configurations already present .."
fi

# Configure optional VM level firewall rules
if [[ $fw == 1 ]]; then
  pvesh create /nodes/$NODE/qemu/$NEXTID/firewall/rules --action $GROUP_LOCAL --type group --iface net0 --enable 1
  pvesh set /nodes/$NODE/qemu/$NEXTID/firewall/options --enable 1
  pvesh set /nodes/$NODE/qemu/$NEXTID/firewall/options --log_level_in warning
  echo "VM Firewall rules set successfully .."
fi

if [[ $tcp == 1 ]]; then
  pvesh create /nodes/$NODE/qemu/$NEXTID/firewall/rules --action ACCEPT --type in --iface net0 --proto tcp --source $PROXY_ALIAS --dport $tcpPorts --enable 1
  echo "TCP ports exposed successfully .."
fi
if [[ $udp == 1 ]]; then
  pvesh create /nodes/$NODE/qemu/$NEXTID/firewall/rules --action ACCEPT --type in --iface net0 --proto udp --source $PROXY_ALIAS --dport $udpPorts --enable 1
  echo "UDP ports exposed successfully .."
fi

printf "\n${BL}## Script finished! Start the VM .. ##${CL}\n\n"
