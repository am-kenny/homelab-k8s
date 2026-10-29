resource "vault_mount" "homelab" {
  path        = "homelab"
  type        = "kv"
  options     = { version = "2" }
  description = "Secrets for homelab workloads"
}
