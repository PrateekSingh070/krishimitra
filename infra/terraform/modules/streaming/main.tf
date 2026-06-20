# OCI Streaming: the real-time event bus for weather/market/pest alerts.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

resource "oci_streaming_stream" "alerts" {
  compartment_id     = var.compartment_ocid
  name               = "krishimitra-alerts-stream"
  partitions         = 1
  retention_in_hours = 24
  freeform_tags      = var.tags
}

output "alerts_stream_id" { value = oci_streaming_stream.alerts.id }
output "alerts_stream_endpoint" { value = oci_streaming_stream.alerts.messages_endpoint }
