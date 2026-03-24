##############################################################################
# Address Objects + Groups + Service Objects
# Reusable objects referenced by security and NAT policies
##############################################################################

# ---------------------------------------------------------------------
# Address Objects
# ---------------------------------------------------------------------

resource "panos_address" "trust_subnet" {
  location    = { vsys = {} }
  name        = "trust-subnet"
  description = "Trust subnet CIDR (internal workloads)"
  ip_netmask  = var.trust_subnet_cidr
}

resource "panos_address" "untrust_subnet" {
  location    = { vsys = {} }
  name        = "untrust-subnet"
  description = "Untrust subnet CIDR (internet-facing)"
  ip_netmask  = var.untrust_subnet_cidr
}

resource "panos_address" "vpc_cidr" {
  location    = { vsys = {} }
  name        = "vpc-cidr"
  description = "Entire VPC CIDR block"
  ip_netmask  = var.vpc_cidr
}

# Example workload server address (for the change scenario demo)
resource "panos_address" "workload_server" {
  location    = { vsys = {} }
  name        = "workload-server-01"
  description = "Example workload server in trust zone"
  ip_netmask  = "10.100.3.50/32"
}

# ---------------------------------------------------------------------
# Address Group
# ---------------------------------------------------------------------

resource "panos_address_group" "internal_subnets" {
  location    = { vsys = {} }
  name        = "all-internal-subnets"
  description = "All internal subnet address objects"

  static = [
    panos_address.trust_subnet.name,
  ]
}
