data "cloudflare_ip_ranges" "cloudflare" {}

resource "cloudflare_r2_bucket" "visionir-bucket" {
  account_id = var.cloudflare_account_id
  name       = "visionir"
  location   = "WEUR"
}

resource "cloudflare_zone" "visionir_io" {
  account_id = var.cloudflare_account_id
  zone       = "visionir.io"
  plan       = "free"
}

resource "cloudflare_zone_dnssec" "visionir_io" {
  zone_id = cloudflare_zone.visionir_io.id
}

resource "cloudflare_record" "root_domain" {
  zone_id         = cloudflare_zone.visionir_io.id
  allow_overwrite = true
  name            = "@"
  value           = oci_core_instance.visionir.public_ip
  type            = "A"
  ttl             = 1
  proxied         = true
  depends_on      = [oci_core_instance.visionir, cloudflare_zone.visionir_io]
}

output "visionir_io_nameservers" {
  value = cloudflare_zone.visionir_io.name_servers
}

output "cloudflare-ipv4-ranges" {
  value = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
}
