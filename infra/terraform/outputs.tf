output "vcn_id" {
  value       = module.network.vcn_id
  description = "OCID of the KrishiMitra VCN."
}

output "atp_id" {
  value       = module.atp.atp_id
  description = "OCID of the Autonomous Database."
}

output "disease_scans_bucket" {
  value       = module.object_storage.disease_scans_bucket
  description = "Name of the disease-scans Object Storage bucket."
}

# --- FREE PATH (default) ---
output "app_private_ip" {
  value       = module.compute.private_ip
  description = "Private IP of the Always Free app host."
}

output "load_balancer_public_ip" {
  value       = module.load_balancer.public_ip
  description = "Public IP of the Always Free Flexible Load Balancer (API entrypoint)."
}

# --- OPTIONAL / PAID (only when enable_paid_services = true) ---
output "alerts_stream_id" {
  value       = var.enable_paid_services ? module.streaming[0].alerts_stream_id : null
  description = "OCID of the krishimitra-alerts-stream (paid Streaming; null on free path)."
}

output "api_gateway_hostname" {
  value       = var.enable_paid_services ? module.api_gateway[0].gateway_hostname : null
  description = "Hostname of the public API Gateway (paid; null on free path)."
}
