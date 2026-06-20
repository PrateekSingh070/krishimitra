# VCN with one public subnet (LB / API Gateway) and one private subnet
# (ATP, Functions, Compute). Per security reqs, app + DB live in private subnets.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "vcn_cidr" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = "krishimitra"
  freeform_tags  = var.tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-igw"
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-nat"
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = cidrsubnet(var.vcn_cidr, 8, 0)
  display_name               = "${var.name_prefix}-public"
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = cidrsubnet(var.vcn_cidr, 8, 1)
  display_name               = "${var.name_prefix}-private"
  prohibit_public_ip_on_vnic = true
  freeform_tags              = var.tags
}

resource "oci_core_network_security_group" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-db-nsg"
}

output "vcn_id" { value = oci_core_vcn.this.id }
output "public_subnet_id" { value = oci_core_subnet.public.id }
output "private_subnet_id" { value = oci_core_subnet.private.id }
output "db_nsg_id" { value = oci_core_network_security_group.db.id }
