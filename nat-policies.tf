##############################################################################
# NAT Policy
# Source NAT for outbound traffic from trust zone → internet
# Without NAT, return traffic from the internet won't route back correctly.
##############################################################################

resource "panos_nat_policy" "main" {
  location = { vsys = {} }

  rules = [
    # Source NAT: Trust → Untrust (outbound internet)
    # Translates the source IP to the untrust interface IP
    {
      name                  = "outbound-snat"
      description           = "Source NAT for outbound traffic from trust to internet"
      source_zones          = [panos_zone.trust.name]
      destination_zone      = [panos_zone.untrust.name]
      source_addresses      = [panos_address.trust_subnet.name]
      destination_addresses = ["any"]
      service               = "any"

      source_translation = {
        dynamic_ip_and_port = {
          interface_address = {
            interface = panos_ethernet_interface.untrust.name
          }
        }
      }
    },
  ]
}
