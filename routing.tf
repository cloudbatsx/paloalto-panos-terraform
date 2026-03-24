##############################################################################
# Virtual Router + Static Routes
# Routes traffic between zones and to the internet
##############################################################################

# ---------------------------------------------------------------------
# Virtual Router — default VR with both data interfaces
# ---------------------------------------------------------------------
resource "panos_virtual_router" "default" {
  location = { ngfw = {} }
  name     = "default"

  interfaces = [
    panos_ethernet_interface.untrust.name,
    panos_ethernet_interface.trust.name,
  ]
}

# ---------------------------------------------------------------------
# Static Routes
# ---------------------------------------------------------------------

# Default route → untrust subnet gateway (for internet egress)
resource "panos_virtual_router_static_route_ipv4" "default_route" {
  location       = { ngfw = {} }
  virtual_router = panos_virtual_router.default.name
  name           = "default-route"
  destination    = "0.0.0.0/0"

  nexthop = {
    ip_address = var.untrust_gw
  }

  metric = 10
}

# Route to VPC CIDR via trust gateway (for return traffic to internal subnets)
resource "panos_virtual_router_static_route_ipv4" "vpc_route" {
  location       = { ngfw = {} }
  virtual_router = panos_virtual_router.default.name
  name           = "vpc-internal"
  destination    = var.vpc_cidr

  nexthop = {
    ip_address = var.trust_gw
  }

  metric = 20
}
