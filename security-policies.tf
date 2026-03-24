##############################################################################
# Security Policy Rules
# Controls traffic between zones — rules are evaluated top-to-bottom
#
# IMPORTANT: Rule order matters! The first match wins.
# The deny-all cleanup rule must always be LAST.
##############################################################################

resource "panos_security_policy" "main" {
  location = { vsys = {} }

  rules = [
    # Rule 1: Allow outbound web browsing (trust → untrust)
    {
      name                  = "allow-outbound-web"
      source_zones          = [panos_zone.trust.name]
      destination_zones     = [panos_zone.untrust.name]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      applications          = ["ssl", "web-browsing"]
      services              = ["application-default"]
      action                = "allow"
      log_end               = true
      description           = "Allow trust zone to browse the web (SSL + HTTP)"
    },

    # Rule 2: Allow DNS (trust → untrust)
    {
      name                  = "allow-dns"
      source_zones          = [panos_zone.trust.name]
      destination_zones     = [panos_zone.untrust.name]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      applications          = ["dns"]
      services              = ["application-default"]
      action                = "allow"
      log_end               = true
      description           = "Allow DNS resolution from trust zone"
    },

    # Rule 3: Allow ICMP/ping (trust → untrust)
    {
      name                  = "allow-ping"
      source_zones          = [panos_zone.trust.name]
      destination_zones     = [panos_zone.untrust.name]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      applications          = ["ping"]
      services              = ["application-default"]
      action                = "allow"
      log_end               = true
      description           = "Allow ping from trust zone for connectivity testing"
    },

    # Rule 4: Allow SSH within trust zone (intra-zone)
    {
      name                  = "allow-trust-ssh"
      source_zones          = [panos_zone.trust.name]
      destination_zones     = [panos_zone.trust.name]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      applications          = ["ssh"]
      services              = ["application-default"]
      action                = "allow"
      log_end               = true
      description           = "Allow SSH within the trust zone"
    },

    # Rule 5: Deny all (cleanup rule — MUST be last)
    {
      name                  = "deny-all"
      source_zones          = ["any"]
      destination_zones     = ["any"]
      source_addresses      = ["any"]
      destination_addresses = ["any"]
      applications          = ["any"]
      services              = ["any"]
      action                = "deny"
      log_end               = true
      description           = "Explicit deny-all cleanup rule (log and drop)"
    },
  ]
}
