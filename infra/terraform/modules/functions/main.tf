# OCI Functions application hosting the disease-classifier and alert-dispatcher
# functions. Individual functions are deployed via the Fn CLI / DevOps pipeline;
# here we provision the Functions application + log group.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

resource "oci_functions_application" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-fn-app"
  subnet_ids     = [var.subnet_id]
  freeform_tags  = var.tags
}

resource "oci_logging_log_group" "fn" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-fn-logs"
}

output "functions_application_id" { value = oci_functions_application.this.id }
output "log_group_id" { value = oci_logging_log_group.fn.id }
