# OCI API Gateway: the secure public entrypoint. Deployment routes + JWT
# authorizer + WAF association are defined where the gateway is fronted; this
# skeleton provisions the gateway itself in the public subnet.

variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

resource "oci_apigateway_gateway" "this" {
  compartment_id = var.compartment_ocid
  endpoint_type  = "PUBLIC"
  subnet_id      = var.subnet_id
  display_name   = "${var.name_prefix}-apigw"
  freeform_tags  = var.tags
}

# Deployment placeholder: define routes to ORDS + the Node API, plus a JWT
# authorizer (OAuth2). Kept commented until backend hostnames are known.
#
# resource "oci_apigateway_deployment" "v1" {
#   compartment_id = var.compartment_ocid
#   gateway_id     = oci_apigateway_gateway.this.id
#   path_prefix    = "/api/v1"
#   specification {
#     request_policies {
#       authentication {
#         type                        = "JWT"
#         token_header                = "Authorization"
#         token_auth_scheme           = "Bearer"
#         issuers                     = ["https://identity.oraclecloud.com/"]
#         audiences                   = ["krishimitra-api"]
#         public_keys { type = "REMOTE_JWKS" uri = "<jwks-uri>" }
#       }
#     }
#     routes { ... }
#   }
# }

output "gateway_id" { value = oci_apigateway_gateway.this.id }
output "gateway_hostname" { value = oci_apigateway_gateway.this.hostname }
