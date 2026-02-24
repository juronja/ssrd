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

# Get latests Code-server version
code_server_latest_version() {
  local VERSION
  VERSION="$(curl -fsSLI -o /dev/null -w "%{url_effective}" https://github.com/coder/code-server/releases/latest)"
  VERSION="${VERSION#https://github.com/coder/code-server/releases/tag/}"
  VERSION="${VERSION#v}"
  echo "$VERSION"
}

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

while true; do
  if OS_USER=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nCloud-init username" 8 58 --title "CLOUD-INIT USERNAME" --cancel-button "Exit Script" 3>&1 1>&2 2>&3); then
    if [[ -z $OS_USER ]]; then
      whiptail --backtitle "Install - Ubuntu VM" --msgbox "Username cannot be empty" 8 58
    else
      break # Username is not empty, break out of the loop
    fi
  else
    exit_script
  fi
done

while true; do
  if OS_PASS=$(whiptail --backtitle "Install - Ubuntu VM" --passwordbox "\nCloud-init password" 8 58 --title "CLOUD-INIT PASSWORD" --cancel-button "Exit Script" 3>&1 1>&2 2>&3); then
    if [[ -z $OS_PASS ]]; then
      whiptail --backtitle "Install - Ubuntu VM" --msgbox "Password cannot be empty" 8 58
    elif [[ "$OS_PASS" == *" "* ]]; then
      whiptail --backtitle "Install - Ubuntu VM" --msgbox "Password cannot contain spaces. Please try again." 8 58
    elif [ ${#OS_PASS} -lt 8 ]; then
      whiptail --backtitle "Install - Ubuntu VM" --msgbox "Password must be at least 8 characters long. Please try again." 8 58
    else
      # Using SHA-512 (algorithm 6) for strong hashing
      HASHED_OS_PASS=$(echo -n "$OS_PASS" | openssl passwd -6 -stdin)
      break # Password is valid, break out of the loop
    fi
  else
    exit_script
  fi
done

while true; do
  if SSH_PUB_KEY=$(whiptail --backtitle "Install - Ubuntu VM" --title "CLOUD-INIT SSH-KEY" --inputbox "\nPaste the Public SSH Key to use.\nLeave empty for no SSH \n" --cancel-button "Exit Script" 8 58 3>&1 1>&2 2>&3); then
    if [[ -z $SSH_PUB_KEY ]]; then
      ssh=0
      break
    elif ! [[ "$SSH_PUB_KEY" =~ ^(ssh-rsa|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-ed25519)\s* ]]; then
      whiptail --backtitle "Install - Ubuntu VM" --msgbox "Invalid SSH key prefix. Must start with ssh-rsa, ssh-dss, ecdsa-sha2-nistpXXX, or ssh-ed25519." 8 58
    elif [ ${#SSH_PUB_KEY} -lt 60 ]; then
      whiptail --backtitle "Install - Ubuntu VM" --msgbox "SSH Key is too short. It might be incomplete." 8 58
    else
      break # Password is valid, break out of the loop
    fi
  else
    exit_script
  fi
done

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

# Install additional programs
if installPrograms=$(whiptail --backtitle "Install - Ubuntu VM" --title "INSTALL PROGRAMS" --checklist "\nInstall these programs? (Spacebar to select)" 12 58 5 \
  "docker" "" OFF \
  "prometheus-node-exporter" "" OFF \
  "code-server" "" OFF \
  "ansible" "" OFF \
  "cifs-utils" "" OFF \
  3>&1 1>&2 2>&3); then
  echo -e "Install programs: $installPrograms"
else
  echo "Programs install skipped .."
fi

if [[ "$installPrograms" =~ "docker" ]]; then
  if insecReg=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nWrite comma seperated IP:PORT list to allow:" 10 58 "192.168.x.x:PORT" --title "ADD INSECURE REGISTRY RULES?" --cancel-button "Skip" 3>&1 1>&2 2>&3); then
    registries=1
    echo "Added insecure registry rules: $insecReg"
  else
    echo "Add registry rules skipped .."
  fi
  if installContainers=$(whiptail --backtitle "Install - Ubuntu VM" --title "INSTALL CONTAINERS" --checklist "\nInstall these containers? (Spacebar to select)" 12 58 3 \
    "portainer" "" OFF \
    "jenkins" "" OFF \
    3>&1 1>&2 2>&3); then
    echo -e "Install containers: $installContainers"
  else
    echo "Container install skipped .."
  fi
fi

if [[ "$installPrograms" =~ "code-server" ]]; then
  while true; do
    if NAS_USERNAME=$(whiptail --backtitle "Install - Ubuntu VM" --inputbox "\nSMB username for mounting GitRepos" 8 58 --title "MOUNT SMB GITREPOS" --cancel-button "Exit Script" 3>&1 1>&2 2>&3); then
      if [[ -z $NAS_USERNAME ]]; then
        whiptail --backtitle "Install - Ubuntu VM" --msgbox "Username cannot be empty" 8 58
      else
        break # Username is not empty, break out of the loop
      fi
    else
      exit_script
    fi
  done

  while true; do
    if NAS_PASSWORD=$(whiptail --backtitle "Install - Ubuntu VM" --passwordbox "\nSMB password for mounting GitRepos" 8 58 --title "MOUNT SMB GITREPOS" --cancel-button "Exit Script" 3>&1 1>&2 2>&3); then
      if [[ -z $NAS_PASSWORD ]]; then
        whiptail --backtitle "Install - Ubuntu VM" --msgbox "Password cannot be empty" 8 58
      elif [[ "$NAS_PASSWORD" == *" "* ]]; then
        whiptail --backtitle "Install - Ubuntu VM" --msgbox "Password cannot contain spaces. Please try again." 8 58
      elif [ ${#NAS_PASSWORD} -lt 8 ]; then
        whiptail --backtitle "Install - Ubuntu VM" --msgbox "Password must be at least 8 characters long. Please try again." 8 58
      else
        break # Password is valid, break out of the loop
      fi
    else
      exit_script
    fi
  done
fi

# Constant variables for app installs
PortainerComposeUrl="https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/Infrastructure/Portainer/Enterprise/compose.yaml"
JenkinsDockerfileUrl="https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/CI-CD/Jenkins/Dockerfile"
JenkinsComposeUrl="https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/CI-CD/Jenkins/compose.yaml"

# Proxmox variables
RAM=$(($RAM_COUNT * 1024))
IMG_LOCATION="/var/lib/vz/template/iso/"
CPU="x86-64-v3"
STORAGE_ID="cloud-configs"
CLOUD_INIT_ABSOLUTE="/mnt/pve/$STORAGE_ID/snippets/$NEXTID-$VM_NAME-ubuntu-cloud-init.yml"
CLOUD_INIT_PVE_PATH="$STORAGE_ID:snippets/$NEXTID-$VM_NAME-ubuntu-cloud-init.yml"
CLUSTER_FW_ENABLED=$(pvesh get /cluster/firewall/options --output-format json | sed -n 's/.*"enable": *\([0-9]*\).*/\1/p')
LOCAL_NETWORK=$(pve-firewall localnet | grep local_network | cut -d':' -f2 | sed 's/ //g')
HOME_NETWORK_ALIAS="home_network"
PROXY_ALIAS="proxy"
PROXY_CIDR="192.168.84.254"
GROUP_LOCAL="local-ssh-ping"

# Download the Ubuntu cloud init image
wget -nc --directory-prefix=$IMG_LOCATION https://cloud-images.ubuntu.com/$UBUNTU_RLS/current/$UBUNTU_RLS-server-cloudimg-amd64.img

# Create a VM
qm create $NEXTID --ostype l26 --cores $CORE_COUNT --cpu $CPU --numa 1 --memory $RAM --name $VM_NAME --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr0,firewall=1$VLAN --serial0 socket --vga serial0 --ipconfig0 ip=$OS_IPv4_CIDR$OS_IPv4_GW_FULL --agent enabled=1 --onboot 1

# Import cloud image disk
qm disk import $NEXTID $IMG_LOCATION$UBUNTU_RLS-server-cloudimg-amd64.img local-lvm --format qcow2

# Map cloud image disk
qm set $NEXTID --scsi0 local-lvm:vm-$NEXTID-disk-0,discard=on,ssd=1 --ide2 local-lvm:cloudinit

# Resize the disk
qm disk resize $NEXTID scsi0 "${DISK_SIZE}G" && qm set $NEXTID --boot order=scsi0

# Configure Cloudinit datails
rm $CLOUD_INIT_ABSOLUTE
touch $CLOUD_INIT_ABSOLUTE

cat <<EOF >>$CLOUD_INIT_ABSOLUTE
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
fqdn: $VM_NAME
users:
  #- default
  - name: $OS_USER
    groups: users, sudo, docker # Add docker group here so user is in docker group from start
    shell: /bin/bash # Set a default shell
    passwd: $HASHED_OS_PASS
    lock_passwd: false # Lock the password to disable password login
    #sudo: "ALL=(ALL) NOPASSWD:ALL" # Grant sudo access without password prompt
    ssh_authorized_keys:
      #- SSH_PUB_KEY
package_update: true
package_upgrade: true
package_reboot_if_required: true
apt:
  sources:
    ansible:
      source: ppa:ansible/ansible
packages:
  - qemu-guest-agent
  - python3-pip
  #- cifs-utils
  #- prometheus-node-exporter
  #- ansible
  #- shellcheck
  #- shfmt
snap:
  commands:
  #- snap install aws-cli --classic
  #- snap install kubectl --classic
  #- snap install node --classic
runcmd:
  # Disable IPv6
  - sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
  # Create custom app folder for deployments
  - mkdir -m 750 /home/$OS_USER/apps && chown -R $OS_USER:$OS_USER /home/$OS_USER/apps
EOF

# SSH manage
if [[ $ssh != 0 ]]; then
  sed -i "s|#- SSH_PUB_KEY|- \"$SSH_PUB_KEY\"|" $CLOUD_INIT_ABSOLUTE
fi

# Docker install
if [[ "$installPrograms" =~ "docker" ]]; then
  cat <<'EOF' >>$CLOUD_INIT_ABSOLUTE
  # Add Docker's official GPG key
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && chmod a+r /etc/apt/keyrings/docker.asc
  # Add the repository to Apt sources
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  # Install Docker
  - apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
EOF
  cat <<EOF >>$CLOUD_INIT_ABSOLUTE
  # Append user to docker group
  - usermod -aG docker $OS_USER
  # Create the daemon.json for insecure (http) logins configs if needed for Nexus
  - cd /etc/docker/ && touch daemon.json
EOF
fi
# Add insecure registries
if [[ $registries == 1 ]]; then
  cat <<EOF >>$CLOUD_INIT_ABSOLUTE
  # Add insecure registries
  - 'printf "{\n    \"insecure-registries\" : [ \"$insecReg\" ]\n}" | tee /etc/docker/daemon.json > /dev/null'
EOF
fi
# Install Portainer
if [[ "$installPrograms" =~ "docker" ]] && [[ "$installContainers" =~ "portainer" ]]; then
  cat <<EOF >>$CLOUD_INIT_ABSOLUTE
  # Install Portainer
  - mkdir /home/$OS_USER/apps/portainer
  - wget -nc --directory-prefix=/home/$OS_USER/apps/portainer $PortainerComposeUrl
  - cd /home/$OS_USER/apps/portainer
  - docker compose up -d
EOF
fi
# Install Jenkins
if [[ "$installPrograms" =~ "docker" ]] && [[ "$installContainers" =~ "jenkins" ]]; then
  cat <<EOF >>$CLOUD_INIT_ABSOLUTE
  # Install Jenkins
  - mkdir /home/$OS_USER/apps/jenkins
  - wget -nc --directory-prefix=/home/$OS_USER/apps/jenkins $JenkinsDockerfileUrl
  - wget -nc --directory-prefix=/home/$OS_USER/apps/jenkins $JenkinsComposeUrl
  - cd /home/$OS_USER/apps/jenkins
  - docker compose up -d
EOF
fi

# Install Prometheus Node Exporter
if [[ "$installPrograms" =~ "prometheus-node-exporter" ]]; then
  sed -i 's/#- prometheus-node-exporter/- prometheus-node-exporter/' $CLOUD_INIT_ABSOLUTE
fi

# Install Code-server
if [[ "$installPrograms" =~ "code-server" ]]; then

  CODE_SERVER_VERSION=$(code_server_latest_version)

  # sed -i 's/#- snap install node --classic/- snap install node --classic/' $CLOUD_INIT_ABSOLUTE
  sed -i 's/#- shellcheck/- shellcheck/' $CLOUD_INIT_ABSOLUTE
  sed -i 's/#- shfmt/- shfmt/' $CLOUD_INIT_ABSOLUTE
  cat <<EOF >>$CLOUD_INIT_ABSOLUTE
  # Mount SMB
  - mkdir -m 750 /home/$OS_USER/GitRepos
  - chown -R $OS_USER:$OS_USER /home/$OS_USER/GitRepos
  - sed -i '\$a //nas.lan/personal/Development/GitRepos/ /home/$OS_USER/GitRepos cifs username=$NAS_USERNAME,password=$NAS_PASSWORD,uid=$OS_USER,gid=$OS_USER,_netdev 0 0' /etc/fstab
  - mount -a
  # Configure Code-server
  - curl -fOL https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server_${CODE_SERVER_VERSION}_amd64.deb
  - dpkg -i code-server_${CODE_SERVER_VERSION}_amd64.deb
  - systemctl enable --now code-server@$OS_USER
  - sleep 3s
  - sed -i 's| 127.0.0.1| 0.0.0.0|' /home/$OS_USER/.config/code-server/config.yaml
  - sed -i 's| password| none|' /home/$OS_USER/.config/code-server/config.yaml
  ## ADD Rsync for the code server config folder?
EOF
fi

# Install Ansible and dependencies
if [[ "$installPrograms" =~ "ansible" ]]; then
  sed -i 's/#- ansible/- ansible/' $CLOUD_INIT_ABSOLUTE
  sed -i 's/#- snap install aws-cli --classic/- snap install aws-cli --classic/' $CLOUD_INIT_ABSOLUTE
  sed -i 's/#- snap install kubectl --classic/- snap install kubectl --classic/' $CLOUD_INIT_ABSOLUTE
  cat <<EOF >>$CLOUD_INIT_ABSOLUTE
  # Install Ansible
  - mkdir -m 750 /home/$OS_USER/apps/ansible
  - chown -R $OS_USER:$OS_USER /home/$OS_USER/apps/ansible
  - pip install boto3 --user --break-system-packages # Needed for aws module
  - pip install openshift --user --break-system-packages # Needed for k8s module
EOF
fi

# Install Cifs Utils
if [[ "$installPrograms" =~ "cifs-utils" ]]; then
  sed -i 's/#- cifs-utils/- cifs-utils/' $CLOUD_INIT_ABSOLUTE
fi

qm set $NEXTID --cicustom "user=local:$CLOUD_INIT_PVE_PATH"

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

if [[ "$installContainers" =~ "portainer" ]]; then
  printf "Portainer will be available at: ${BL}https://$(echo "$OS_IPv4_CIDR" | awk -F'./' '{print $1}'):9443${CL}\n\n"
fi
if [[ "$installContainers" =~ "jenkins" ]]; then
  printf "Jenkins will be available at: ${BL}http://$(echo "$OS_IPv4_CIDR" | awk -F'./' '{print $1}'):8080${CL}\n\n"
fi
