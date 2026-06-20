# Object Storage buckets for disease-scan images, generated reports, and ML
# model artifacts.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "disease_scans" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "krishimitra-disease-scans"
  access_type    = "NoPublicAccess"
  freeform_tags  = var.tags
}

resource "oci_objectstorage_bucket" "reports" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "krishimitra-reports"
  access_type    = "NoPublicAccess"
  freeform_tags  = var.tags
}

resource "oci_objectstorage_bucket" "model_artifacts" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "krishimitra-model-artifacts"
  access_type    = "NoPublicAccess"
  freeform_tags  = var.tags
}

output "namespace" { value = data.oci_objectstorage_namespace.ns.namespace }
output "disease_scans_bucket" { value = oci_objectstorage_bucket.disease_scans.name }
output "reports_bucket" { value = oci_objectstorage_bucket.reports.name }
output "model_artifacts_bucket" { value = oci_objectstorage_bucket.model_artifacts.name }
