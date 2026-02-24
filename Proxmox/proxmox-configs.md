# Useful Proxmox configurations

- When installing I use `.lan` local domain. e.g. `pve-i7-9700.lan`.
- API URL endpoint for `pvesh` command: <https://pve-i7-9700.lan:8006/api2/html/>

## First time setup

Common steps when installing proxmox for the first time. Use this script:

<https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install>

## Firewall setup

Official docs: <https://pve.proxmox.com/wiki/Firewall>

### Cluster level Firewall

❗  Applies to all hosts.
⚠️  If you enable the firewall, traffic to all hosts is blocked by default. Only exceptions is WebGUI(8006) and ssh(22) from your local network.

```bash
pvesh set /cluster/firewall/options --enable 1
pvesh create /cluster/firewall/aliases --name home_network --cidr 192.168.84.0/24
pvesh create /cluster/firewall/aliases --name proxy --cidr 192.168.84.254
pvesh create /cluster/firewall/rules --action ACCEPT --type in --iface vmbr0 --source dc/home_network --macro Ping --enable 1
pvesh create /cluster/firewall/groups --group local-ssh-ping
pvesh create /cluster/firewall/groups/local-ssh-ping --action ACCEPT --type in --source dc/home_network --proto tcp --enable 1
pvesh create /cluster/firewall/groups/local-ssh-ping --action ACCEPT --type in --source dc/home_network --macro Ping --enable 1
pvesh create /cluster/firewall/groups/local-ssh-ping --action ACCEPT --type in --source dc/home_network --macro SSH --enable 1
```

### VM level Firewall

❗  Applies to specific VMs.

```bash
NODE=$(hostname)
pvesh create /nodes/$NODE/qemu/{{VMID}}/firewall/rules --action ACCEPT --type in --iface net0 --proto tcp --dport 7474,3131 --source dc/proxy --enable 1
pvesh set /nodes/$NODE/qemu/{{VMID}}/firewall/options --enable 1
```

### LXC level firewall

❗  Applies to specific LXCs.

```bash
NODE=$(hostname)
pvesh create /nodes/$NODE/lxc/{{LXCID}}/firewall/rules --action ACCEPT --type in --iface net0 --proto tcp --source dc/home_network --enable 1 # Enable access on local network
pvesh create /nodes/$NODE/lxc/{{LXCID}}/firewall/rules --action ACCEPT --type in --iface net0 --source dc/home_network --macro SSH --enable 1 # Enable SSH
pvesh create /nodes/$NODE/lxc/{{LXCID}}/firewall/rules --action ACCEPT --type in --iface net0 --source dc/home_network --macro Ping --enable 1 # # Enable Ping on local network
pvesh set /nodes/$NODE/lxc/{{LXCID}}/firewall/options --enable 1
```

## Enable VLANs on nodes vmbr0

Go to node System > Network > vmbr0 and tick the VLAN aware option.

## Drive share for Truenas Rsync

1. Create a **directory** type disk with **ext4** filesystem. pvenode>Disks>Directory>Create: Directory
2. Enable **Add storage** when creating

## Backup & Restore VMs

You can use this to migrate VMs from one machine to another.

1. Create a backup with Mode `Stop`. Other settings can be default.
2. By default it will save backups to `local` storage and to `/var/lib/vz/dump` folder.
3. Copy backup folder and cloud-init scripts to another machine via SCP:

    ```bash
    scp -r /var/lib/vz/dump /var/lib/vz/snippets root@pve-9700.lan:/var/lib/vz/
    ```

4. Restore VM from backups
5. Check if Firewall needs to be set (this does not get copied)

## VM Boot order

Order 1: adguard, (startup delay: 20s)
Order 2: truenas-scale (startup delay: 120s), haos, hosting-prod, caddy
Order 3: Any

## Clustering

Official docs: <https://pve.proxmox.com/wiki/Cluster_Manager>

### Kill a node and cluster

1. Identify the node ID to remove:

    ```bash
    pvecm nodes
    ```

    At this point, you must power off hp4 and ensure that it will not power on again (in the network) with its current configuration.

2. IMPORTANT: Set the quorum votes on the last node to 1!!

    ```bash
    pvecm expected 1
    ```

3. We can safely remove it from the cluster now. error = CS_ERR_NOT_EXIST can be ignored.

    ```bash
    pvecm delnode pve-nodename
    ```

### Remove the cluster

Run on the machine where you want to remove the cluster settings

```bash
# First, stop the corosync and pve-cluster services on the node:
systemctl stop pve-cluster
systemctl stop corosync
# Start the cluster file system again in local mode:
pmxcfs -l
# Delete the corosync configuration files:
rm /etc/pve/corosync.conf
rm -r /etc/corosync/*
# You can now start the file system again as a normal service:
killall pmxcfs
systemctl start pve-cluster
```

### Intel e1000e NIC Offloading Fix for node pve-9700

Edit the `/etc/network/interfaces` file and ad the `post-up` line.

```shell
iface eno1 inet manual
post-up ethtool -K eno1 gso off tso off rxvlan off txvlan off gro off tx off rx off sg off
```

Alternatively you can use the community script:

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/nic-offloading-fix.sh)"
```
