# Oracle Autonomous Transaction Processing (ATP) with a private endpoint.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "db_name" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "cpu_core_count" { type = number }
variable "storage_tbs" { type = number }
variable "is_free_tier" { type = bool }
variable "subnet_id" { type = string }
variable "nsg_ids" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}

resource "oci_database_autonomous_database" "this" {
  compartment_id           = var.compartment_ocid
  db_name                  = var.db_name
  display_name             = "${var.name_prefix}-atp"
  db_workload              = "OLTP"
  is_free_tier             = var.is_free_tier
  admin_password           = var.admin_password
  cpu_core_count           = var.is_free_tier ? null : var.cpu_core_count
  data_storage_size_in_tbs = var.is_free_tier ? null : var.storage_tbs

  # Private endpoint: no public IP (security req #4). Free tier ignores these.
  subnet_id           = var.is_free_tier ? null : var.subnet_id
  nsg_ids             = var.is_free_tier ? null : var.nsg_ids
  freeform_tags       = var.tags
}

output "atp_id" { value = oci_database_autonomous_database.this.id }
output "atp_connection_strings" {
  value     = oci_database_autonomous_database.this.connection_strings
  sensitive = true
}
