locals {
  homelab_ip = "192.168.178.11"
}

# Owner of the tailnet, used in the policy tests
data "tailscale_users" "owner" {
  role = "owner"
}

resource "tailscale_acl" "policy" {
  acl = templatefile("${path.module}/policy.hujson.tftpl", {
    admin_login = data.tailscale_users.owner.users[0].login_name
    homelab_ip  = local.homelab_ip
  })
}
