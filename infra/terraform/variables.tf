variable "tenancy_ocid" {
  type        = string
  description = "OCID of the tenancy."
}

variable "compartment_ocid" {
  type        = string
  description = "OCID of the compartment to deploy KrishiMitra into."
}

variable "region" {
  type        = string
  description = "OCI region. Pinned to an India region for data localisation."
  default     = "ap-mumbai-1"

  validation {
    condition     = contains(["ap-mumbai-1", "ap-hyderabad-1"], var.region)
    error_message = "Per data-localisation requirements, region must be ap-mumbai-1 or ap-hyderabad-1."
  }
}

variable "project_name" {
  type    = string
  default = "krishimitra"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev/prod)."
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "vcn_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "atp_db_name" {
  type    = string
  default = "krishimitradb"
}

variable "atp_admin_password" {
  type        = string
  description = "ADMIN password for the ATP instance. Supply via TF_VAR / Vault, never commit."
  sensitive   = true
}

variable "atp_cpu_core_count" {
  type    = number
  default = 1
}

variable "atp_storage_tbs" {
  type    = number
  default = 1
}

variable "atp_is_free_tier" {
  type        = bool
  description = "Use Always Free ATP in dev."
  default     = true
}

variable "enable_paid_services" {
  type        = bool
  description = <<-EOT
    Master switch for paid OCI services. FALSE (default) = the free path:
    API Gateway and Streaming are NOT created; the app is fronted by an Always
    Free Flexible Load Balancer on an Always Free Ampere A1 compute instance.
    Set TRUE only if you intentionally want the paid API Gateway + Streaming.
  EOT
  default     = false
}

variable "compute_shape" {
  type        = string
  description = "Compute shape for the app host. Default is Always Free Ampere A1."
  default     = "VM.Standard.A1.Flex"
}

variable "compute_ocpus" {
  type        = number
  description = "OCPUs for the app host (Always Free allows up to 4 across A1)."
  default     = 1
}

variable "compute_memory_gbs" {
  type        = number
  description = "Memory (GB) for the app host (Always Free allows up to 24 across A1)."
  default     = 6
}

variable "compute_image_ocid" {
  type        = string
  description = "OS image OCID for the app host (e.g. Oracle Linux 8 aarch64)."
  default     = ""
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for the app host. Supply via TF_VAR, never commit."
  default     = ""
}

variable "lb_min_bandwidth_mbps" {
  type        = number
  description = "Flexible LB minimum bandwidth. 10 Mbps keeps it in Always Free."
  default     = 10
}

variable "lb_max_bandwidth_mbps" {
  type        = number
  description = "Flexible LB maximum bandwidth. 10 Mbps keeps it in Always Free."
  default     = 10
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
