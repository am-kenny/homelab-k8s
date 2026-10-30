resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  description = "Service accounts of the k3s cluster"
}

# Vault calls the TokenReview API with its own service account token
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc"
}
