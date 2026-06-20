terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }

  # Remote state in OCI Object Storage (S3-compatible). Fill in via -backend-config
  # or a backend.hcl file; bucket + credentials are environment-specific so they
  # are intentionally not hardcoded here.
  #
  # backend "s3" {
  #   bucket                      = "krishimitra-tfstate"
  #   key                         = "krishimitra/terraform.tfstate"
  #   region                      = "ap-mumbai-1"
  #   endpoints                   = { s3 = "https://<namespace>.compat.objectstorage.ap-mumbai-1.oraclecloud.com" }
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_requesting_account_id  = true
  #   skip_s3_checksum            = true
  #   use_path_style              = true
  # }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
  # Auth: prefer instance/resource principals in CI; for local dev set the
  # standard OCI config/key env vars. No keys are stored in this repo.
}
