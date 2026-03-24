##############################################################################
# Outputs — Layer 2 Configuration Summary
##############################################################################

output "zones" {
  description = "Configured security zones"
  value = {
    untrust = panos_zone.untrust.name
    trust   = panos_zone.trust.name
  }
}

output "interfaces" {
  description = "Configured ethernet interfaces"
  value = {
    untrust = "${panos_ethernet_interface.untrust.name} (${var.untrust_ip})"
    trust   = "${panos_ethernet_interface.trust.name} (${var.trust_ip})"
  }
}

output "virtual_router" {
  description = "Virtual router name"
  value       = panos_virtual_router.default.name
}

output "address_objects" {
  description = "Configured address objects"
  value = [
    panos_address.trust_subnet.name,
    panos_address.untrust_subnet.name,
    panos_address.vpc_cidr.name,
    panos_address.workload_server.name,
  ]
}

output "configuration_note" {
  description = "Important PAN-OS lifecycle note"
  value       = "terraform apply stages changes. The null_resource commit activates them. Verify in PAN-OS UI: Policies > Security."
}
