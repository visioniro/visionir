data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = var.oci_tenancy_id
}

resource "oci_core_vcn" "visionir" {
  cidr_block     = var.subnet_cidr_block
  compartment_id = var.oci_tenancy_id
  dns_label      = "vsnirvcn"
  display_name   = "visionir_vcn"
}

resource "oci_core_subnet" "visionir" {
  cidr_block     = var.subnet_cidr_block
  compartment_id = var.oci_tenancy_id
  vcn_id         = oci_core_vcn.visionir.id
  route_table_id = oci_core_route_table.visionir.id
  dns_label      = "vsnirsubnet"
  depends_on     = [oci_core_route_table.visionir]
  display_name   = "visionir_subnet"
}

resource "oci_core_internet_gateway" "visionir" {
  compartment_id = var.oci_tenancy_id
  vcn_id         = oci_core_vcn.visionir.id
  enabled        = true
  display_name   = "visionir_igw"
}

resource "oci_core_route_table" "visionir" {
  compartment_id = var.oci_tenancy_id
  vcn_id         = oci_core_vcn.visionir.id
  display_name   = "visionir_rt"
  route_rules {
    network_entity_id = oci_core_internet_gateway.visionir.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_network_security_group" "visionir" {
  compartment_id = var.oci_tenancy_id
  vcn_id         = oci_core_vcn.visionir.id
  display_name   = "visionir_nsg"
}

resource "oci_core_network_security_group_security_rule" "outbound_https" {
  description               = "Allow HTTPS traffic to the internet"
  network_security_group_id = oci_core_network_security_group.visionir.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = "0.0.0.0/0"
  stateless                 = false
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "outbound_http" {
  description               = "Allow HTTP traffic to the internet"
  network_security_group_id = oci_core_network_security_group.visionir.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = "0.0.0.0/0"
  stateless                 = false
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "inbound_cloudflare_http" {
  description               = "Allow HTTP traffic from Cloudflare"
  for_each                  = toset(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks)
  network_security_group_id = oci_core_network_security_group.visionir.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  stateless                 = false
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}
resource "oci_core_network_security_group_security_rule" "inbound_cloudflare_https" {
  description               = "Allow HTTPS traffic from Cloudflare"
  for_each                  = toset(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks)
  network_security_group_id = oci_core_network_security_group.visionir.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  stateless                 = false
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_instance" "visionir" {
  display_name        = "visionir"
  availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0].name
  compartment_id      = var.oci_tenancy_id
  shape               = "VM.Standard.A1.Flex"
  create_vnic_details {
    assign_public_ip          = true
    assign_private_dns_record = true
    nsg_ids                   = [oci_core_network_security_group.visionir.id]
    subnet_id                 = oci_core_subnet.visionir.id
  }
  metadata = {
    "ssh_authorized_keys" = var.oci_ssh_key
  }
  source_details {
    source_type = "image"
    source_id   = var.oci_ubuntu_image_id
  }
  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }
}

output "compute-ip-address" {
  value       = oci_core_instance.visionir.public_ip
  description = "value of the public ip address of the compute instance"
}
