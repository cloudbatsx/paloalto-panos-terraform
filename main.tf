##############################################################################
# Provider Configuration — PAN-OS Terraform Provider (Layer 2)
# CloudBats x Palo Alto Networks
#
# This is Layer 2 of the two-layer architecture:
#   Layer 1 (AWS provider)  → deploys the VM-Series EC2 instance
#   Layer 2 (PAN-OS provider) → configures the firewall itself
#
# Separate state files, separate repos, different change cadences.
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    panos = {
      source  = "PaloAltoNetworks/panos"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# The PAN-OS provider connects to the firewall's management interface
# Credentials should be set via environment variables:
#   export PANOS_HOSTNAME=<management-eip>
#   export PANOS_USERNAME=admin
#   export PANOS_PASSWORD=<instance-id>
#
# Or via terraform.tfvars (which is gitignored)
provider "panos" {
  hostname                = var.panos_hostname
  username                = var.panos_username
  password                = var.panos_password
  skip_verify_certificate = true # Self-signed cert on VM-Series
}
