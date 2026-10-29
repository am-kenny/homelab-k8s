terraform {
  required_version = "~> 1.16"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
  }
}

# Token comes from VAULT_TOKEN
provider "vault" {
  address = "https://vault.amhome.app"
}
