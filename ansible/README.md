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

On the target node, run:
```bash
sudo visudo -f /etc/sudoers.d/ansible
```

Add:
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
