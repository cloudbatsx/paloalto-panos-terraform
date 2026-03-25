# Palo Alto PAN-OS Configuration as Code (Layer 2)

**Terraform-managed firewall configuration for Palo Alto Networks VM-Series — security policies, NAT, zones, routing, and address objects deployed as code.**

Developed and maintained by [CloudBats LLC](https://github.com/cloudbatsx).

---

## Overview

This repository manages the complete PAN-OS firewall configuration for a Palo Alto Networks VM-Series deployment using the official [PAN-OS Terraform provider](https://registry.terraform.io/providers/PaloAltoNetworks/panos/latest). It represents **Layer 2** of a two-layer architecture:

| Layer | Repository | Provider | Scope |
|-------|-----------|----------|-------|
| **Layer 1** | [`paloalto-vmseries-aws-terraform`](https://github.com/cloudbatsx/paloalto-vmseries-aws-terraform) | `hashicorp/aws` | AWS infrastructure — VPC, subnets, ENIs, EC2, S3 bootstrap, IAM |
| **Layer 2 (this repo)** | `paloalto-panos-terraform` | `paloaltonetworks/panos` | Firewall configuration — zones, security policies, NAT, routing |

The PAN-OS provider communicates directly with the firewall's XML API to configure interfaces, zones, security policies, NAT rules, routing, and address objects — all as declarative Terraform code. Because the PAN-OS provider is cloud-agnostic, this configuration works identically whether the VM-Series runs on AWS, Azure, GCP, or on-premises hardware.

---

## What Gets Configured

This Terraform root module deploys **15 PAN-OS resources** that define a complete zone-based firewall policy:

### Interfaces & Zones (4 resources)

| Interface | IP Address | Zone | Role |
|-----------|-----------|------|------|
| `ethernet1/1` | `<untrust_ip>/24` | **untrust** | Internet-facing data plane |
| `ethernet1/2` | `<trust_ip>/24` | **trust** | Internal workloads |

Both interfaces operate in Layer 3 mode with 1500 MTU. Zone assignments enforce that all inter-zone traffic must match an explicit security policy rule.

### Security Policy (5 rules)

Rules are evaluated **top-to-bottom, first match wins**. All rules have end-of-session logging enabled.

| # | Rule Name | Source Zone | Dest Zone | Application | Action |
|---|-----------|------------|-----------|-------------|--------|
| 1 | `allow-outbound-web` | trust | untrust | ssl, web-browsing | **Allow** |
| 2 | `allow-dns` | trust | untrust | dns | **Allow** |
| 3 | `allow-ping` | trust | untrust | ping | **Allow** |
| 4 | `allow-trust-ssh` | trust | trust | ssh | **Allow** |
| 5 | `deny-all` | any | any | any | **Deny** |

Security policies use PAN-OS **App-ID** for application-aware enforcement rather than port-based rules. The `application-default` service setting ensures applications are only allowed on their standard ports (e.g., DNS on UDP/53, SSL on TCP/443). The final `deny-all` rule is an explicit cleanup rule ensuring a default-deny posture.

### NAT Policy (1 rule)

| Rule | Source Zone | Dest Zone | Source Address | Translation |
|------|-----------|-----------|----------------|-------------|
| `outbound-snat` | trust | untrust | trust-subnet | Dynamic IP and Port via `ethernet1/1` |

All outbound traffic from the trust zone is source-NATed to the untrust interface IP, enabling internet egress for internal workloads.

### Virtual Router & Routing (3 resources)

| Route | Destination | Next Hop | Metric | Purpose |
|-------|------------|----------|--------|---------|
| `default-route` | `0.0.0.0/0` | Untrust gateway | 10 | Internet egress via untrust interface |
| `vpc-internal` | `10.100.0.0/16` | Trust gateway | 20 | Return path to internal VPC subnets |

Both interfaces are attached to the `default` virtual router. Static routes direct internet-bound traffic out the untrust interface and internal VPC traffic back through the trust interface.

### Address Objects & Groups (5 resources)

| Object | Type | Value | Description |
|--------|------|-------|-------------|
| `trust-subnet` | IP Netmask | `10.100.3.0/24` | Trust subnet CIDR |
| `untrust-subnet` | IP Netmask | `10.100.2.0/24` | Untrust subnet CIDR |
| `vpc-cidr` | IP Netmask | `10.100.0.0/16` | Entire VPC CIDR block |
| `workload-server-01` | IP Netmask | `10.100.3.50/32` | Example workload host |
| `all-internal-subnets` | Address Group | `[trust-subnet]` | Logical grouping of internal subnets |

Address objects are referenced in security and NAT policies, enabling clean rule definitions and easy updates when network ranges change.

---

## The PAN-OS Commit Model

This is a critical PAN-OS concept: **`terraform apply` does not activate changes.** It stages them in the candidate configuration. Changes only become live after a **commit**.

```
terraform apply          ──►  Candidate Config (staged, not active)
                                      │
                                      ▼
               commit    ──►  Running Config (live on the firewall)
```

This repository includes automated commit via a `null_resource` provisioner that calls the PAN-OS XML API after every apply. The commit triggers whenever security policies, NAT rules, interfaces, zones, or routing changes are detected.

This staged-then-commit lifecycle provides an audit window between staging and activation — in production, this maps naturally to change management workflows where plan review and commit approval are separate steps.

---

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- A running Palo Alto VM-Series instance with management access (deployed via [Layer 1](https://github.com/cloudbatsx/paloalto-vmseries-aws-terraform))
- PAN-OS admin credentials (username + password)
- Management IP reachable from the machine running Terraform
- `bash` and `curl` available (used by the commit provisioner)

---

## Usage

### 1. Deploy Layer 1 first

This configuration requires a running VM-Series instance. Deploy [Layer 1](https://github.com/cloudbatsx/paloalto-vmseries-aws-terraform) and note the outputs.

### 2. Clone and configure

```bash
git clone git@github.com:cloudbatsx/paloalto-panos-terraform.git
cd paloalto-panos-terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with values from Layer 1 outputs
```

### 3. Set provider credentials

```bash
export PANOS_HOSTNAME="<management-eip>"
export PANOS_USERNAME="admin"
export PANOS_PASSWORD="<your-password>"
```

### 4. Deploy

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

`terraform apply` stages all configuration changes and then automatically commits them to the running firewall via the XML API.

### 5. Verify

Log into the PAN-OS web UI at `https://<management-eip>` and confirm:

- **Policies > Security** — 5 rules in correct order + 2 PAN-OS defaults
- **Policies > NAT** — `outbound-snat` rule present
- **Network > Interfaces** — `ethernet1/1` (untrust) and `ethernet1/2` (trust) both UP
- **Network > Zones** — `trust` and `untrust` zones with correct interface mappings
- **Network > Virtual Routers** — `default` router with 2 static routes
- **Objects > Addresses** — 4 address objects with correct CIDRs

---

## Making Policy Changes

To add, modify, or remove firewall rules, edit the Terraform configuration and apply. For example, to allow a new workload to receive HTTPS traffic on a custom port:

```hcl
# 1. Add an address object for the server (objects.tf)
resource "panos_address" "new_workload" {
  location = { vsys = {} }
  name        = "app-server-01"
  description = "Application server in trust zone"
  ip_netmask  = "10.100.3.100/32"
}

# 2. Add a security rule ABOVE the deny-all rule (security-policies.tf)
#    Insert into the panos_security_policy.main rule list:
{
  name                  = "allow-app-https"
  source_zones          = ["trust"]
  destination_zones     = ["untrust"]
  source_addresses      = ["app-server-01"]
  destination_addresses = ["any"]
  applications          = ["ssl"]
  services              = ["application-default"]
  action                = "allow"
  log_end               = true
}
```

```bash
terraform plan    # Review the diff
terraform apply   # Stage + auto-commit
```

The commit provisioner activates the changes automatically. Verify the new rule in the PAN-OS web UI under **Policies > Security**.

---

## Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `panos_hostname` | `string` | Yes | — | PAN-OS management IP or hostname |
| `panos_username` | `string` | No | `admin` | PAN-OS admin username |
| `panos_password` | `string` | Yes | — | PAN-OS admin password (sensitive) |
| `untrust_ip` | `string` | Yes | — | Private IP of untrust ENI (ethernet1/1) |
| `trust_ip` | `string` | Yes | — | Private IP of trust ENI (ethernet1/2) |
| `untrust_gw` | `string` | Yes | — | Default gateway for untrust subnet |
| `trust_gw` | `string` | Yes | — | Default gateway for trust subnet |
| `untrust_subnet_cidr` | `string` | No | `10.100.2.0/24` | CIDR of untrust subnet |
| `trust_subnet_cidr` | `string` | No | `10.100.3.0/24` | CIDR of trust subnet |
| `vpc_cidr` | `string` | No | `10.100.0.0/16` | CIDR of entire VPC |

All dynamic values (IPs, gateways) come from Layer 1 Terraform outputs. The `terraform.tfvars.example` file documents the mapping.

## Outputs

| Output | Description |
|--------|-------------|
| `zones` | Map of configured security zones (untrust, trust) |
| `interfaces` | Map of configured interfaces with IP addresses |
| `virtual_router` | Virtual router name |
| `address_objects` | List of configured address object names |
| `configuration_note` | Lifecycle note about the commit model |

---

## CI/CD

GitHub Actions runs on every push and pull request to `main`:

| Step | Command | Purpose |
|------|---------|---------|
| Format | `terraform fmt -check -recursive` | Enforce consistent formatting |
| Init | `terraform init` | Initialize providers |
| Validate | `terraform validate` | Syntax and configuration validation |

Apply and commit are intentionally excluded from CI — firewall policy changes require human review before activation.

---

## Extending to Production

### Panorama Integration

For managing multiple VM-Series firewalls at scale, integrate with [Panorama](https://docs.paloaltonetworks.com/panorama):

- **Device Groups** define shared security and NAT policies pushed to all managed firewalls
- **Template Stacks** define shared network configuration (interfaces, zones, routing)
- The PAN-OS Terraform provider supports Panorama as a target, enabling centralized policy-as-code across an entire firewall fleet

### VRF-Based Segmentation

PAN-OS virtual routers function as VRFs (Virtual Routing and Forwarding instances), enabling macro-segmentation within a single firewall:

- Each virtual router maintains its own routing table and interface assignments
- Inter-VR traffic can be controlled via policy-based forwarding rules
- This architecture supports extending routing domains from data center to cloud without additional firewall instances

### Multi-Cloud

The PAN-OS provider is cloud-agnostic — it connects to any PAN-OS device via the XML API regardless of where it runs. This Layer 2 configuration is reusable across:

- AWS VM-Series
- Azure VM-Series
- GCP VM-Series
- On-premises PA-Series appliances

Only the provider connection details (hostname, credentials) change between environments. The security policies, NAT rules, and routing remain consistent.

### Advanced Routing

For production environments requiring dynamic routing:

- **BGP** peering with cloud routers (e.g., AWS Transit Gateway, Azure Route Server)
- **OSPF** for internal routing adjacencies
- **Policy-Based Forwarding** for application-aware traffic steering
- **ECMP** for load distribution across multiple paths

---

## Project Structure

```
.
├── main.tf                          # PAN-OS provider configuration
├── interfaces.tf                    # Ethernet interfaces + security zones
├── routing.tf                       # Virtual router + static routes
├── objects.tf                       # Address objects + address groups
├── security-policies.tf             # Security policy rules (5 rules)
├── nat-policies.tf                  # NAT policy rules (source NAT)
├── commit.tf                        # Automated PAN-OS commit via XML API
├── variables.tf                     # Input variable definitions
├── outputs.tf                       # Output definitions
├── terraform.tfvars.example         # Example variable values (copy to terraform.tfvars)
├── .github/
│   └── workflows/
│       └── terraform.yml            # CI/CD: fmt, validate
├── .gitignore                       # Excludes state and tfvars files
└── LICENSE                          # MIT License
```

---

## Lessons Learned

Operational insights from deploying and configuring VM-Series with Terraform:

- **PAN-OS 12.x PAYG has no default web UI password.** The admin password must be set via SSH using the EC2 key pair before the web UI or API is accessible.
- **IMDSv2 blocks PAN-OS SSH key retrieval.** Set `http_tokens = optional` on the EC2 instance metadata options to allow PAN-OS to read the SSH key from instance metadata.
- **The default virtual router pre-exists on PAN-OS.** It must be imported into Terraform state (`terraform import`) rather than created — creating it will fail with a conflict.
- **`terraform apply` only stages changes.** The PAN-OS commit model requires an explicit commit to activate configuration. This is by design and is a strength for production change management.
- **API-based commit can silently fail.** SSH-based commit from PAN-OS config mode (`configure` > `commit`) is more reliable as a fallback.
- **Windows local-exec defaults to `cmd.exe`.** Use `interpreter = ["bash", "-c"]` for provisioners that use bash syntax.

---

## Related

- [Layer 1: AWS Infrastructure](https://github.com/cloudbatsx/paloalto-vmseries-aws-terraform) — VPC, EC2, bootstrap, and IAM for VM-Series
- [PAN-OS Terraform Provider](https://registry.terraform.io/providers/PaloAltoNetworks/panos/latest) — Official provider documentation
- [pan.dev/terraform](https://pan.dev/terraform/) — Palo Alto Networks Terraform tutorials and guides
- [VM-Series Deployment Guide](https://docs.paloaltonetworks.com/vm-series) — Palo Alto Networks documentation

---

## Built by CloudBats

<p align="center">
  <strong>CloudBats LLC</strong> — Network Security & Cloud Infrastructure, Automated
</p>

This repository is a working example of how we deliver firewall policy automation for our clients. What you see here — zone-based security policies, NAT, routing, and address objects managed entirely as Terraform code with automated commits and CI/CD — is the same approach we bring to production environments at scale.

### What We Deliver

- **Firewall policy as code** — Palo Alto security rules, NAT, routing, and objects managed through Terraform with full Git history, peer review, and automated validation
- **End-to-end VM-Series deployments** — from AWS/Azure/GCP infrastructure provisioning through PAN-OS configuration, delivered as two clean Terraform layers your team owns
- **Panorama-managed fleets** — centralized policy management across dozens of firewalls using device groups, template stacks, and the PAN-OS Terraform provider
- **Network segmentation architecture** — VRF-based macro-segmentation, zone design, and traffic steering tailored to your compliance and security requirements
- **Custom Terraform providers** — purpose-built providers for network platforms without native Terraform support, published and maintained for community or private use
- **Operational handoff** — production-ready code, CI/CD pipelines, runbooks, and knowledge transfer so your team maintains full ownership from day one

### Why Clients Work With Us

We bring deep Terraform expertise and hands-on network security experience to every engagement. Our team has built and published open-source Terraform providers, deployed firewall infrastructure across multi-site global organizations, and automated network operations end-to-end. We understand both the infrastructure engineering and the security policy design — and we deliver solutions that bridge the two.

### Get in Touch

Whether you're automating an existing Palo Alto deployment, planning a new cloud security architecture, or migrating from legacy firewall management, we're ready to help.

**GitHub:** [github.com/cloudbatsx](https://github.com/cloudbatsx)
**Email:** [sales@cloudbats.com](mailto:sales@cloudbats.com)

---

## License

MIT License. See [LICENSE](LICENSE) for details.
