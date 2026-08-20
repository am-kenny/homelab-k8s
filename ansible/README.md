## SSH access

Ansible connects to the target node over SSH, so a working keypair needs to
be in place before anything else here works.

1. Generate a keypair on the control node, if one doesn't already exist:

   ```bash
   ssh-keygen -t ed25519 -C "Homelab" -f ~/.ssh/id_ed25519_homelab
   ```

2. Copy the public key to the target node:

   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519_homelab.pub <ssh_user>@<machine_host>
   ```

3. Add node to SSH config:

   ```bash
   vim ~/.ssh/config
   ```

   Add entry:

   ```text
   Host <machine_name>
         User <ssh_user>
         IdentityFile ~/.ssh/id_ed25519_homelab
   ```

4. Confirm passwordless login works:

   ```bash
   ssh <machine_name>
   ```

If this logs in without a password prompt, the keypair is set up correctly.

## Node setup

### If sudo is missing or user is not sudo

Login as root

Install sudo:

```bash
apt update
apt install sudo -y
```

Make user sudo:

```bash
usermod -aG sudo <username>
```

To avoid password prompt create a file:

```bash
sudo visudo -f /etc/sudoers.d/ansible
```

With the following content:
```
<ssh_user> ALL=(ALL) NOPASSWD: ALL
```

## Configure Ansible inventory

List your nodes in `inventory/hosts.yaml`

```yaml
k8s_master:
  hosts:
    <machine_name1>:
    <machine_name2>:
k8s_worker:
  hosts:
    <machine_name3>:
    <machine_name4>:
wifi:  # Wi-Fi capable hosts
   hosts:
    <machine_name2>:
    <machine_name4>:
      
```

## Running Ansible

Change directory

```bash
cd ansible
```

Install collections

```bash
ansible-galaxy collection install -r requirements.yaml
```

Dry-run provisioning

```bash
# pass -i inventory/hosts.yaml if ansible.cfg is being avoided (known issue with WSL)
ansible-playbook playbook.yaml --check
```

Run provisioning

```bash
# pass -i inventory/hosts.yaml if ansible.cfg is being avoided (known issue with WSL)
ansible-playbook playbook.yaml
```

## Bonded network with Wi-Fi setup

The `wifi` role configures an active-backup bond with Ethernet as primary and Wi-Fi as backup interfaces.

The Wi-Fi passphrase must be 8 to 63 characters. `wpa_supplicant` treats a 64-char
value as a hex key and will reject a passphrase of that length.

### Reserve IP

In order for Ansible not to hang post-reboot it is required to reserve IP for the target host.

Set a static IP reservations in your router's admin panel against the node's
**Ethernet** MAC and note it as `bond_address`, you will set it as a host variable later. Reboot the node, so it takes the new IP address.

### Get predictable network interface names

Run on the target node:

```bash
networkctl list
```

Note the interface names of type 'ether' and 'wlan', e.g. `enp4s0` and `wlp5s0`.

### Encrypt sensitive data

Never store sensitive values as plaintext in VCS. It is best to encrypt Wi-Fi SSID and PSK  with `ansible-vault`.

```bash
ansible-vault encrypt_string <wifi-ssid> --name wifi_ssid

# Encryption successful
# wifi_ssid: !vault |
#           $ANSIBLE_VAULT;1.1;AES256
#           <ansible-vault-encrypted-ssid>
```

```bash
ansible-vault encrypt_string <wifi-psk> --name wifi_psk

# Encryption successful
# wifi_psk: !vault |
#           $ANSIBLE_VAULT;1.1;AES256
#           <ansible-vault-encrypted-psk>
```


You will paste those outputs in the next step as group variables.

For details on how to use ansible vault visit [Official documentation](https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html).

### Set variables

Create a file with host variables at `host_vars/<machine-name>.yaml`:

```yaml
wifi_firmware_package: <firmware-package-name> # Can be omitted if resolved by OS installer
eth_interface: <eth-if-name>
wifi_interface: <wlan-if-name>

bond_address: <reserved-address>
bond_prefix: 24
```

Paste the encrypted values from the previous step into `group_vars/wifi.yaml`,
then set the remaining values for your network:

```yaml
wifi_ssid: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <ansible-vault-encrypted-ssid>

wifi_psk: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          <ansible-vault-encrypted-psk>

default_gateway: <default-gateway>
wifi_country: <country-code>
# Nothing maintains /etc/resolv.conf once the bond is configured.
# Omit those only if you manage /etc/resolv.conf another way or agree with pre-resolved values
dns_domain: <dns-domain>
dns_nameservers:
  - <nameserver1>
  - <nameserver2>
```

Defaults for optional variables live in `roles/wifi/meta/argument_specs.yml`.

### Post-run verification

Assert the bond is created with `Primary Slave: <eth-if-name>` and that all slave interfaces are listed and have `MII Status: up`. Check with:

```bash
cat /proc/net/bonding/<bond-name>
```

At this point you may run a manual test by pinging the target node and detaching the cable.

```bash
ping <host-address>
```

Bond should automatically change to Wi-Fi interface on cable detach and back on cable attach. It is expected for request to hang, while active interface is being changed.
