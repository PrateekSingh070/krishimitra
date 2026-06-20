# =============================================================================
# KrishiMitra :: root module
# Wires the per-service modules together. Each module is a thin, valid-HCL
# skeleton in ./modules/* that you flesh out with concrete resources. Nothing
# here is applied automatically in the foundation pass.
# =============================================================================

module "network" {
  source           = "./modules/vcn"
  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  vcn_cidr         = var.vcn_cidr
  tags             = local.common_tags
}

module "atp" {
  source             = "./modules/atp"
  compartment_ocid   = var.compartment_ocid
  name_prefix        = local.name_prefix
  db_name            = var.atp_db_name
  admin_password     = var.atp_admin_password
  cpu_core_count     = var.atp_cpu_core_count
  storage_tbs        = var.atp_storage_tbs
  is_free_tier       = var.atp_is_free_tier
  subnet_id          = module.network.private_subnet_id
  nsg_ids            = [module.network.db_nsg_id]
  tags               = local.common_tags
}

module "object_storage" {
  source           = "./modules/object_storage"
  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  tags             = local.common_tags
}

module "functions" {
  source           = "./modules/functions"
  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  subnet_id        = module.network.private_subnet_id
  tags             = local.common_tags
}

# -----------------------------------------------------------------------------
# FREE PATH (default): Always Free compute + Flexible Load Balancer host the API
# and front ORDS/APEX. No API Gateway, no Streaming.
# -----------------------------------------------------------------------------
module "compute" {
  source             = "./modules/compute"
  compartment_ocid   = var.compartment_ocid
  name_prefix        = local.name_prefix
  subnet_id          = module.network.private_subnet_id
  nsg_ids            = [module.network.db_nsg_id]
  shape              = var.compute_shape
  ocpus              = var.compute_ocpus
  memory_gbs         = var.compute_memory_gbs
  image_ocid         = var.compute_image_ocid
  ssh_public_key     = var.ssh_public_key
  tags               = local.common_tags
}

module "load_balancer" {
  source             = "./modules/load_balancer"
  compartment_ocid   = var.compartment_ocid
  name_prefix        = local.name_prefix
  subnet_id          = module.network.public_subnet_id
  backend_ip         = module.compute.private_ip
  backend_port       = 3000
  min_bandwidth_mbps = var.lb_min_bandwidth_mbps
  max_bandwidth_mbps = var.lb_max_bandwidth_mbps
  tags               = local.common_tags
}

# -----------------------------------------------------------------------------
# OPTIONAL / PAID (only when enable_paid_services = true): API Gateway + Streaming.
# -----------------------------------------------------------------------------
module "streaming" {
  source           = "./modules/streaming"
  count            = var.enable_paid_services ? 1 : 0
  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  tags             = local.common_tags
}

module "api_gateway" {
  source           = "./modules/api_gateway"
  count            = var.enable_paid_services ? 1 : 0
  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  subnet_id        = module.network.public_subnet_id
  tags             = local.common_tags
}
