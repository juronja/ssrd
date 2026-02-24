# Virtual Machine install manual

How to setup various VMs in Proxmox.

## Ubuntu Cloud init VM

### Custom Cloud init install

Copy this line in the Proxmox Shell.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/Infrastructure/Proxmox/scripts/ubuntu-vm-cloudinit-custom.sh)"
```

⚠️ A custom cloud init file will be created in snippets folder. This file is critical for restoring backups on another Proxmox node or when doing migrations.

### Basic Cloud init install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/Infrastructure/Proxmox/scripts/ubuntu-vm-cloudinit-basic.sh)"
```

- POST INSTALL - Edit SSH KEY cloud-init before starting

## TrueNAS VM

Copy this line in the Proxmox Shell.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/Infrastructure/Proxmox/scripts/truenas-vm.sh)"
```

After installed, import PCI Device to be able to access the disks

### Attach Motherboard Hard disks manually

Find out the unique ID for hard disks. Filtering results having "ata-" or "nvme-" or "usb-" but excluding results containing "part"

```bash
ls /dev/disk/by-id | grep -E '^ata-|^nvme-|^usb-' | grep -v 'part'
```

Get serial ID

```bash
udevadm info --query=property --value --property=ID_SERIAL_SHORT "/dev/disk/by-id/usb-_Mobile_Drive_00000000384B-0:0"
```

Attach the disks -scsi1, -scsi2, -scsi3, etc

```bash
qm set 100 -scsi1 /dev/disk/by-id/usb-_Mobile_Drive_00000000384B-0:0,serial=64CDSPSMS

qm set 100 -scsi2 /dev/disk/by-id/ata-Hitachi_HTS727575A9E364_J3390084GMAGND,serial=64CDSPSMS
```

## Windows 11 VM

❗Load ISO into Proxmox first!

Copy this line in the Proxmox Shell.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/Infrastructure/Proxmox/scripts/windows11-vm.sh)"
```

STEPS:

1. Choose Enterprise edition

2. Load virtio drivers when installing

    - **disk** (amd64/w11)
    - **network** (NetKVM/w11/amd64)

3. Use local domain (account) when asked to sign in

4. Install guest-agent and other virtio drivers, run the wizard in the iso drive

    - **guest-agent/qemu-ga-x86_64.msi**
    - **virtio-win-gt-x64.msi**

### PCIe Passthrough a GPU (WIP)

1. Make sure IOMMU is enabled on the motherboard and CPU supports it
2. With recent linux kernels (6.8 or newer), IOMMU is enabled by default.
3. Add these modules: `printf "\nvfio\nvfio_iommu_type1\nvfio_pci" >> /etc/modules`
4. Find vendor & device ID with: `lspci -ns 01:00 -v`
5. Disable VGA: `echo "options vfio-pci ids=10de:1f02 disable_vga=1" > /etc/modprobe.d/vfio.conf`
6. Blacklist drivers so Proxmox does not load them `printf "blacklist nouveau\nblacklist nvidia\nblacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf`
7. Update `update-initramfs -u -k all`

#### Optional lines

```bash
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf
```

## Windows Server Domain Controller VM

❗Load ISO into Proxmox first!

Copy this line in the Proxmox Shell.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/juronja/homelab-configs/refs/heads/main/Infrastructure/Proxmox/scripts/windows-domain-controller-vm.sh)"
```

STEPS:

1. Choose Server edition

2. Load virtio drivers when installing

    - **disk** (amd64/2k25)

3. Install guest-agent and other virtio drivers, run the wizard in the iso drive

    - **guest-agent/qemu-ga-x86_64.msi**
    - **virtio-win-gt-x64.msi**

    You can unmount the ISO and virtio drives now.
