locals {
  external_secrets_namespace       = "external-secrets"
  external_secrets_service_account = "external-secrets"
}

data "vault_policy_document" "external_secrets" {
  rule {
    path         = "${vault_mount.homelab.path}/data/*"
    capabilities = ["read"]
    description  = "Read homelab secrets to sync them into the cluster"
  }
}

resource "vault_policy" "external_secrets" {
  name   = "external-secrets"
  policy = data.vault_policy_document.external_secrets.hcl
}

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "external-secrets"
  bound_service_account_names      = [local.external_secrets_service_account]
  bound_service_account_namespaces = [local.external_secrets_namespace]
  audience                         = "vault"
  token_policies                   = [vault_policy.external_secrets.name]
  token_ttl                        = 3600
  token_max_ttl                    = 3600
}
