# [FREE PATH] Always Free Ampere A1 compute instance to host the Node.js API
# (and optionally ORDS). With the default shape/ocpus/memory this stays within
# the Always Free A1 allowance (up to 4 OCPUs / 24 GB total across A1 in a
# tenancy). No recurring cost.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }
variable "nsg_ids" {
  type    = list(string)
  default = []
}
variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}
variable "ocpus" {
  type    = number
  default = 1
}
variable "memory_gbs" {
  type    = number
  default = 6
}
variable "image_ocid" {
  type    = string
  default = ""
}
variable "ssh_public_key" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

resource "oci_core_instance" "app" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "${var.name_prefix}-app"
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = var.nsg_ids
    assign_public_ip = false
  }

  source_details {
    source_type = "image"
    source_id   = var.image_ocid
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # cloud-init installs Node + the API; replace with your bootstrap.
    user_data = base64encode(<<-EOF
      #!/bin/bash
      dnf install -y nodejs git
      # git clone <repo> /opt/krishimitra && cd /opt/krishimitra/backend && npm ci && npm start
    EOF
    )
  }

  freeform_tags = var.tags
}

output "instance_id" { value = oci_core_instance.app.id }
output "private_ip" { value = oci_core_instance.app.private_ip }
