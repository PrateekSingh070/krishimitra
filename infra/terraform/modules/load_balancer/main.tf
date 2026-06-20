# [FREE PATH] Always Free Flexible Load Balancer (10 Mbps min/max stays free).
# Fronts the Node.js API running on the Always Free compute instance and is the
# public entrypoint in place of the paid API Gateway.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }
variable "backend_ip" { type = string }
variable "backend_port" {
  type    = number
  default = 3000
}
variable "min_bandwidth_mbps" {
  type    = number
  default = 10
}
variable "max_bandwidth_mbps" {
  type    = number
  default = 10
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "oci_load_balancer_load_balancer" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-lb"
  shape          = "flexible"
  subnet_ids     = [var.subnet_id]
  is_private     = false

  shape_details {
    minimum_bandwidth_in_mbps = var.min_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.max_bandwidth_mbps
  }

  freeform_tags = var.tags
}

resource "oci_load_balancer_backend_set" "api" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "krishimitra-api-bset"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.backend_port
    url_path          = "/health"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend" "api" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  backendset_name  = oci_load_balancer_backend_set.api.name
  ip_address       = var.backend_ip
  port             = var.backend_port
  weight           = 1
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  name                     = "http"
  default_backend_set_name = oci_load_balancer_backend_set.api.name
  port                     = 80
  protocol                 = "HTTP"
}

output "load_balancer_id" { value = oci_load_balancer_load_balancer.this.id }
output "public_ip" {
  value = oci_load_balancer_load_balancer.this.ip_address_details[0].ip_address
}
