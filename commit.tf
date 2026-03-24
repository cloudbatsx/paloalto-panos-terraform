##############################################################################
# PAN-OS Commit
# CRITICAL: terraform apply only stages changes in the candidate config.
# You MUST commit to activate the configuration on the firewall.
#
# This uses a null_resource to call the PAN-OS XML API commit endpoint
# after all other resources are created.
##############################################################################

resource "null_resource" "panos_commit" {
  # Re-trigger commit whenever any config resource changes
  triggers = {
    security_policy = jsonencode(panos_security_policy.main)
    nat_policy      = jsonencode(panos_nat_policy.main)
    interfaces      = "${panos_ethernet_interface.untrust.name}-${panos_ethernet_interface.trust.name}"
    zones           = "${panos_zone.untrust.name}-${panos_zone.trust.name}"
    router          = panos_virtual_router.default.name
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      API_KEY=$(curl -sk "https://${var.panos_hostname}/api/?type=keygen&user=${var.panos_username}&password=${var.panos_password}" | grep -oP '(?<=<key>).*?(?=</key>)')
      curl -sk "https://${var.panos_hostname}/api/?type=commit&cmd=<commit></commit>&key=$API_KEY"
    EOT
  }

  depends_on = [
    panos_security_policy.main,
    panos_nat_policy.main,
    panos_virtual_router_static_route_ipv4.default_route,
    panos_virtual_router_static_route_ipv4.vpc_route,
    panos_address.trust_subnet,
    panos_address.untrust_subnet,
    panos_address.vpc_cidr,
    panos_address.workload_server,
    panos_address_group.internal_subnets,
  ]
}
