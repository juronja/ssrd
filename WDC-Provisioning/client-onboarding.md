# Windows Client Onboarding

Describes how to setup a windows machine and join AD.

## Prerequisites

- Make/Decide Clients VLAN
- Add firewall traffic rule: Allow DNS, DHCP ports for both VLANS (53,67) to reach gateway.
- Add firewall traffic rule: Allow Client VLAN to reach WDC Server ports (88 123 135 389 445 464 3268 49152-65535)
- In your router `DNS forward` to WDC controller (don't use WDC as DNS). Whitelist domain if needed.

## Install / Setup Windows 11

1. Install Windows with local `Admin` account
2. Rename PC, Join AD & Install Wazuh

    Run this script inside Terminal (Run as Administrator)

    ```powershell
    irm https://raw.githubusercontent.com/juronja/ssrd/refs/heads/main/WDC-Provisioning/scripts/win-client-post-install.ps1 | iex
    ```
