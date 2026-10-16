<div align="center">

# AmHome

**A two-node k3s homelab, provisioned with Ansible and deployed with Helmfile.**

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
| Provisioning | Ansible |
| Kubernetes | k3s |
| Deployment | Helm and Helmfile |
| Ingress | Traefik (bundled with k3s) |
| Certificates | cert-manager with a Let's Encrypt issuer via Cloudflare DNS-01 |
| DNS | Pi-hole |
| Monitoring | K8sGPT |

## Services

| Service | What it does | Node |
| --- | --- | --- |
| [Pi-hole](https://pi-hole.net) | Network-wide ad blocking and local DNS | `am-server` |
| [Homepage](https://gethomepage.dev) | Dashboard with widgets | `am-server` |
| [Overleaf](https://github.com/yu-i-i/overleaf-cep) | LaTeX editor (Extended CE) | `am-wanderer` |
| [AmPulsar](https://github.com/am-kenny/ampulsar) | Twitch and TikTok live notifications to Telegram | Any |
| [K8sGPT](https://k8sgpt.ai) | Scans the cluster for issues | Any |
| [cert-manager](https://cert-manager.io) | Issues and renews certificates | Any |

## How it works

- **Private by default:** Pi-hole resolves `*.amhome.app` to the server's LAN address and Traefik serves a wildcard certificate that cert-manager obtains through a Cloudflare DNS-01 challenge. Real HTTPS without exposing anything publicly.
- **One always-on node, one ejectable node:** `am-server` hosts crucial services, like DNS. `am-wanderer` is a laptop that can leave the cluster at any time, so it only runs services that can go offline with it. A third node is planned for the near future.
- **Wi-Fi failover:** The laptop's Ethernet and Wi-Fi are bonded in active-backup mode with systemd-networkd. This way the node is safe from accidental cable disconnects.
- **Local LLM:** K8sGPT sends its scan results to Ollama on an external desktop. A selectorless Service and an EndpointSlice give that machine a stable in-cluster name.
- **Safe to re-run:** The Ansible playbook updates packages, reboots only if required, disables swap, opens required firewalld ports and installs k3s. Running it again changes nothing unless something drifted.

## Getting started

You will need Ansible, kubectl, Helm with the [helm-diff](https://github.com/databus23/helm-diff) plugin and Helmfile.

### 1. Provision the nodes

Provisioning with Ansible is described in [`ansible/README.md`](ansible/README.md).

The `kubeconfig` is created at `/etc/rancher/k3s/k3s.yaml` on the server node.

### 2. Create the required secrets

Create each namespace, then its secret:

| Secret | Namespace | Keys |
| --- | --- | --- |
| `cloudflare-api-token` | `cert-manager` | `api-token` |
| `pihole-admin` | `pihole` | `password` |
| `homepage-secrets` | `homepage` | `HOMEPAGE_VAR_PIHOLE_KEY` |
| `overleaf-secrets` | `overleaf` | `OVERLEAF_SESSION_SECRET` |
| `am-pulsar-secrets` | `am-pulsar` | `TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET`, `TELEGRAM_BOT_TOKEN` |

### 3. Deploy

```bash
cd kubernetes
helmfile apply
```

## License

MIT © Andrii Prykhodko. See [LICENSE](LICENSE).
