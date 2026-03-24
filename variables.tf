##############################################################################
# Variables — Palo Alto PAN-OS Configuration (Layer 2)
# CloudBats x Palo Alto Networks
##############################################################################

variable "panos_hostname" {
  description = "PAN-OS management IP or hostname (from Layer 1 output: management_eip)"
  type        = string
}

variable "panos_username" {
  description = "PAN-OS admin username"
  type        = string
  default     = "admin"
}

variable "panos_password" {
  description = "PAN-OS admin password (for PAYG: the EC2 instance ID)"
  type        = string
  sensitive   = true
}

# These IPs come from the Layer 1 Terraform output (layer2_connection_info)
variable "untrust_ip" {
  description = "Private IP of the untrust ENI (ethernet1/1) from Layer 1"
  type        = string
}

variable "trust_ip" {
  description = "Private IP of the trust ENI (ethernet1/2) from Layer 1"
  type        = string
}

variable "untrust_gw" {
  description = "Default gateway for the untrust subnet (first IP in subnet)"
  type        = string
}

variable "trust_gw" {
  description = "Default gateway for the trust subnet (first IP in subnet)"
  type        = string
}

variable "untrust_subnet_cidr" {
  description = "CIDR of the untrust subnet"
  type        = string
  default     = "10.100.2.0/24"
}

variable "trust_subnet_cidr" {
  description = "CIDR of the trust subnet"
  type        = string
  default     = "10.100.3.0/24"
}

variable "vpc_cidr" {
  description = "CIDR of the entire VPC"
  type        = string
  default     = "10.100.0.0/16"
}
