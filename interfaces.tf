##############################################################################
# Ethernet Interfaces + Zones
# Maps AWS ENIs to PAN-OS interfaces and security zones
##############################################################################

# ---------------------------------------------------------------------
# Ethernet Interfaces (Layer 3 mode)
# ---------------------------------------------------------------------

# ethernet1/1 → Untrust (internet-facing)
resource "panos_ethernet_interface" "untrust" {
  location = { ngfw = {} }
  name     = "ethernet1/1"
  comment  = "Untrust interface - internet-facing (AWS untrust subnet)"

  layer3 = {
    ips = [{ name = "${var.untrust_ip}/24" }]
    mtu = 1500
  }
}

# ethernet1/2 → Trust (internal-facing)
resource "panos_ethernet_interface" "trust" {
  location = { ngfw = {} }
  name     = "ethernet1/2"
  comment  = "Trust interface - internal-facing (AWS trust subnet)"

  layer3 = {
    ips = [{ name = "${var.trust_ip}/24" }]
    mtu = 1500
  }
}

# ---------------------------------------------------------------------
# Security Zones
# All inter-zone traffic requires an explicit security rule
# ---------------------------------------------------------------------

resource "panos_zone" "untrust" {
  location = { vsys = {} }
  name     = "untrust"

  network = {
    layer3 = [panos_ethernet_interface.untrust.name]
  }
}

resource "panos_zone" "trust" {
  location = { vsys = {} }
  name     = "trust"

  network = {
    layer3                          = [panos_ethernet_interface.trust.name]
    enable_packet_buffer_protection = false
  }
}
