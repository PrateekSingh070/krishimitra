# KrishiMitra :: Terraform (OCI Resource Manager)

Infrastructure-as-code skeleton for the KrishiMitra platform. This is a
**foundation-pass skeleton**: the module structure, variables, and resource
shapes are in place and valid HCL, but it is not wired to a live tenancy and
has not been `terraform apply`-ed from here.

## Free vs paid

By default (`enable_paid_services = false`) everything stays within **OCI Always
Free**: Always Free ATP, Object Storage, Functions, an Always Free **Ampere A1
compute** instance hosting the Node.js API, and an Always Free **Flexible Load
Balancer** (10 Mbps) as the public entrypoint. The paid **API Gateway** and
**Streaming** modules are gated behind `enable_paid_services` and are not created
on the free path.

## Modules

| Module | Provisions | Free? |
|--------|------------|-------|
| `modules/vcn` | VCN, IGW, NAT, public + private subnets, DB NSG | yes |
| `modules/atp` | Autonomous DB (ATP), Always Free in dev | yes |
| `modules/object_storage` | Buckets: disease-scans, reports, model-artifacts | yes |
| `modules/functions` | Functions application + log group | yes |
| `modules/compute` | **Always Free Ampere A1** host for the API | yes |
| `modules/load_balancer` | **Always Free Flexible LB** (10 Mbps) entrypoint | yes |
| `modules/streaming` | `krishimitra-alerts-stream` event bus | paid (gated) |
| `modules/api_gateway` | Public API Gateway + JWT authorizer | paid (gated) |

## Usage

```powershell
cd infra/terraform
Copy-Item terraform.tfvars.example terraform.tfvars   # fill in OCIDs
$env:TF_VAR_atp_admin_password = '...'                # never commit secrets
$env:TF_VAR_ssh_public_key     = 'ssh-rsa AAAA...'    # for the A1 host
terraform init
terraform plan
terraform apply
```

To enable the paid entrypoint instead of the free LB+compute, set
`enable_paid_services = true` in `terraform.tfvars`.

## Notes

- `region` is validated to an India region (`ap-mumbai-1` / `ap-hyderabad-1`) for
  data localisation.
- Secrets come from `TF_VAR_*` / OCI Vault, never from committed files.
- Remote state belongs in OCI Object Storage (S3-compatible) — see the commented
  `backend "s3"` block in `versions.tf`.
