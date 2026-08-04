variable "project_name" {
  type        = string
  description = "Short project identifier used in resource names."

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.project_name))
    error_message = "project_name must be 3-10 lowercase alphanumeric characters."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  type        = string
  default     = "centralindia"
  description = "Azure region for all resources."
}

# ---------------------------------------------------------------------------
# GUARDRAIL: mandatory tagging policy
# Every resource must carry these tags. Terraform will refuse to plan/apply
# if any required tag is missing — this is enforced structurally, not by
# convention, via the variable validation block below.
# ---------------------------------------------------------------------------
variable "tags" {
  type        = map(string)
  description = "Resource tags. Must include Environment, Owner, CostCenter, Project."

  validation {
    condition = alltrue([
      for k in ["Environment", "Owner", "CostCenter", "Project"] : contains(keys(var.tags), k)
    ])
    error_message = "tags must include: Environment, Owner, CostCenter, Project."
  }
}

# variable "admin_username" {
#   type        = string
#   default     = "azureadmin"
#   description = "Admin username for the VM."
# }

# variable "ssh_public_key" {
#   type        = string
#   description = "SSH public key content for VM login (password auth is disabled by policy)."
# }

# variable "vm_size" {
#   type        = string
#   default     = "Standard_B2s"
#   description = "VM SKU. Kept small/cheap by default; override per environment."
# }

variable "allowed_ssh_source_cidr" {
  type        = string
  description = "CIDR allowed to reach SSH (22). Never use 0.0.0.0/0 in prod (enforced below)."

  validation {
    condition     = var.allowed_ssh_source_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_source_cidr must not be 0.0.0.0/0 — restrict to a known IP/CIDR."
  }
}
