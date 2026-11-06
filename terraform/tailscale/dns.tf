# Resolve *.amhome.app with Pi-hole
resource "tailscale_dns_split_nameservers" "amhome" {
  domain      = "amhome.app"
  nameservers = [local.homelab_ip]
}
