# Windows Client Setup

Describes how to setup a windows machine and join AD.

## Prerequisites

- Make/Decide Clients VLAN
- Allow DNS, DHCP ports for both VLANS (53,67)
- Allow Client VLAN to reach WDC Server ports (88 123 135 389 445 464 3268 49152-65535)
- DNS forward to WDC controller (don't use WDC as DNS). Whitelist domain if needed.

## Install / Setup Windows

1. Install Windows with local `Admin` account
2. Rename PC, Join AD & Install Wazuh

    Run this script inside Terminal (Administrator)

    ```powershell
    irm https://raw.githubusercontent.com/juronja/homelab-configs/main/OS-Windows/windows-domain-controller/scripts/win-client-post-install.ps1 | iex
    ```
