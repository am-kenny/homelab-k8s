<div align="center">

# AmHome

**A two-node k3s homelab, provisioned with Ansible and deployed with Helmfile.**

[![CI](https://github.com/am-kenny/homelab-k8s/actions/workflows/ci.yaml/badge.svg)](https://github.com/am-kenny/homelab-k8s/actions/workflows/ci.yaml)
[![k3s](https://img.shields.io/badge/k3s-v1.36-FFC61C?logo=k3s&logoColor=white)](https://k3s.io)
[![Helmfile](https://img.shields.io/badge/Helmfile-0F1689?logo=helm&logoColor=white)](https://helmfile.readthedocs.io)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com)
[![Let's Encrypt](https://img.shields.io/badge/TLS-Let's%20Encrypt-003A70?logo=letsencrypt&logoColor=white)](https://letsencrypt.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## About

This repository hosts all the playbooks, charts and configurations that run my homelab, from machine setup to the Helm releases. All the services are reachable only from the home network at `*.amhome.app`.

## Hardware

| Node | Machine | OS | Role |
| --- | --- | --- | --- |
| `am-server` | Small desktop PC | CentOS Stream 9 | Control plane, always-on |
| `am-wanderer` | Laptop | Debian 13 | Worker, removable |

Outside the cluster, my desktop PC runs Ollama as the LLM backend for K8sGPT.

## Stack

| Layer | Tool |
| --- | --- |
| Provisioning | Ansible, Terraform |
| Kubernetes | k3s |
| Deployment | Helm and Helmfile |
| Ingress | Traefik (bundled with k3s) |
| Certificates | cert-manager with a Let's Encrypt issuer via Cloudflare DNS-01 |
| Secrets | HashiCorp Vault |
| DNS | Pi-hole |
| Monitoring | Prometheus, Grafana and Alertmanager (kube-prometheus-stack), K8sGPT |

## Services

| Service | What it does | Node |
| --- | --- | --- |
| [Pi-hole](https://pi-hole.net) | Network-wide ad blocking and local DNS | `am-server` |
| [Homepage](https://gethomepage.dev) | Dashboard with widgets | `am-server` |
| [Overleaf](https://github.com/yu-i-i/overleaf-cep) | LaTeX editor (Extended CE) | `am-wanderer` |
| [CouchDB](https://couchdb.apache.org) | Sync server for Obsidian | `am-server` |
| [AmPulsar](https://github.com/am-kenny/ampulsar) | Twitch and TikTok live notifications to Telegram | Any |
| [Prometheus](https://prometheus.io) | Metrics collection | `am-server` |
| [Grafana](https://grafana.com) | Dashboards for cluster and node metrics | `am-server` |
| [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) | Sends alerts to Telegram | `am-server` |
| [K8sGPT](https://k8sgpt.ai) | Scans the cluster for issues | Any |
| [Headlamp](https://headlamp.dev) | Web UI for accessing the cluster | Any |
| [cert-manager](https://cert-manager.io) | Issues and renews certificates | Any |
| [Vault](https://developer.hashicorp.com/vault) | Stores the app secrets | `am-server` |
| [External Secrets Operator](https://external-secrets.io) | Syncs secrets from Vault into Kubernetes Secrets | Any |

## How it works

- **Private by default:** Pi-hole resolves `*.amhome.app` to the server's LAN address and Traefik serves a wildcard certificate that cert-manager obtains through a Cloudflare DNS-01 challenge. Real HTTPS without exposing anything publicly.
- **One always-on node, one ejectable node:** `am-server` hosts crucial services, like DNS. `am-wanderer` is a laptop that can leave the cluster at any time, so it only runs services that can go offline with it. A third node is planned for the near future.
- **Wi-Fi failover:** The laptop's Ethernet and Wi-Fi are bonded in active-backup mode with systemd-networkd. This way the node is safe from accidental cable disconnects.
- **Secrets in Vault:** Every app secret lives in a Vault KV mount. External Secrets Operator (ESO) authenticates to Vault with its own ServiceAccount and syncs Vault secrets into regular Kubernetes Secrets. The charts only reference Secrets by name. Vault's mount, auth method, policy and role are configured with Terraform.
- **Local LLM:** K8sGPT sends its scan results to Ollama on an external desktop. A selectorless Service and an EndpointSlice give that machine a stable in-cluster name.
- **Safe to re-run:** The Ansible playbook updates packages, reboots only if required, disables swap, opens required firewalld ports and installs k3s. Running it again changes nothing unless something drifted.

## Getting started

You will need Ansible, kubectl, Helm with the [helm-diff](https://github.com/databus23/helm-diff) plugin, Helmfile and Terraform.

### 1. Provision the nodes

Provisioning with Ansible is described in [`ansible/README.md`](ansible/README.md).

The `kubeconfig` is created at `/etc/rancher/k3s/k3s.yaml` on the server node. Before running `kubectl` or `helmfile` from your local machine, securely copy it to a local file, restrict its permissions with `chmod 600` and replace `127.0.0.1` in its API server URL with the server's reachable LAN IP or hostname. Export `KUBECONFIG` to the copied file's local path and confirm that `kubectl get nodes` succeeds before continuing.

### 2. Deploy and unseal Vault

```bash
cd kubernetes
helmfile -l name=vault apply
```

The `vault-0` pod stays at `0/1` until Vault is initialized and unsealed. Initialize it once and store the unseal keys and root token in safe places:

```bash
kubectl -n vault exec -it vault-0 -- vault operator init -key-shares=3 -key-threshold=2
```

Vault unseal is required for a fresh Vault instance and on each restart. To unseal run the following command once per required key:

```bash
kubectl -n vault exec -it vault-0 -- vault operator unseal
```

### 3. Configure Vault

The KV mount, the Kubernetes auth method and the External Secrets policy and role are managed with Terraform in [`terraform/vault`](terraform/vault).

On a fresh cluster `vault.amhome.app` is not reachable yet, because DNS and the certificate depend on secrets stored in Vault. Forward Vault's port instead:

```bash
kubectl -n vault port-forward pod/vault-0 8200
```

Apply the configuration with the root token in a fresh terminal:

```bash
cd terraform/vault
export TF_VAR_vault_address=http://127.0.0.1:8200
read -rs VAULT_TOKEN && export VAULT_TOKEN
terraform init
terraform apply
```

### 4. Store the secrets

Create each secret in the `homelab` KV mount, for example in the UI at `http://127.0.0.1:8200` while the port-forward is running. ESO copies every key into a Kubernetes Secret with the same name in the matching namespace.

| Vault path | Keys |
| --- | --- |
| `cert-manager/cloudflare-api-token` | `api-token` |
| `pihole/pihole-admin` | `password` |
| `homepage/homepage-secrets` | `HOMEPAGE_VAR_PIHOLE_KEY` |
| `overleaf/overleaf-secrets` | `OVERLEAF_SESSION_SECRET`, `OVERLEAF_INVITE_TOKEN_SECRET` |
| `obsidian/couchdb-admin` | `adminUsername`, `adminPassword`, `cookieAuthSecret`, `erlangCookie` |
| `monitoring/grafana-admin` | `admin-user`, `admin-password` |
| `monitoring/alertmanager-telegram` | `bot-token`, `chat-id` |
| `am-pulsar/am-pulsar-secrets` | `TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET`, `TELEGRAM_BOT_TOKEN` |

### 5. Deploy External Secrets Operator

```bash
cd kubernetes
helmfile -l namespace=external-secrets apply
kubectl get clustersecretstore vault
```

The store should report `Valid`. Otherwise `kubectl describe clustersecretstore vault` shows why it can't authenticate to Vault.

### 6. Deploy everything else

```bash
helmfile apply
```

## License

MIT © Andrii Prykhodko. See [LICENSE](LICENSE).
