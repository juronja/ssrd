# Onboard new linux servers

1. Deploy VM - Follow [these](https://github.com/juronja/ssrd/blob/main/Proxmox/proxmox-VM-installs.md#basic-cloud-init-install) steps.

2. Dont forget to generate and add public SSH key to VM cloud-init.

3. Add private SSH key to Ansible machine and edit permitions

    If new keys - restrict private key permissions for each

    ```shell
    chmod 600 ~/.ssh/id_ubuntu-general
    chmod 600 ~/.ssh/id_ubuntu-general2
    chmod 600 ~/.ssh/id_ubuntu-general3
    ```

4. Add local DNS (eg. ubuntu1.lan)

## Run the playbook

1. Go to eg. `~/ansible`

2. Edit Wazuh version in `vars/variables.yaml` if needed. It has to be the same version as your running Wazuh server.

3. Add a local domain (eg. ubuntu1.lan) of newly deployed server to `inventory/hosts.yaml` file.

4. Run Ansible playbook

    ```shell
    ansible-playbook provision-ubuntu-vm.yaml
    ```
