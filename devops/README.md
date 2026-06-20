# KrishiMitra :: DevOps & CI/CD

OCI DevOps build + deploy configuration, container image, and the JMeter
performance plan.

```
build_spec.yaml     OCI DevOps Build Pipeline (utPLSQL -> pytest -> jest -> docker)
deploy_spec.yaml    OCI DevOps Deployment Pipeline (rolling to Compute + APEX + Functions)
jmeter/             krishimitra_load_test.jmx  (10k concurrent farmers)
../backend/Dockerfile  API image (node-oracledb Thin mode, non-root, healthcheck)
```

## Build pipeline (build_spec.yaml)

| Stage | Action |
|-------|--------|
| 1 | utPLSQL suites via SQLcl (gated on DB creds from the DevOps vault) |
| 2 | `pytest functions/tests` |
| 3 | `npm ci && npm test` in `backend/` |
| 4 | `docker build` the API image; exported as `krishimitra_api_image` |

Wire it to the GitHub repo `krishimitra-platform`; push the artifact to OCI
Container Registry (OCIR) via a delivered-artifact stage.

## Deploy pipeline (deploy_spec.yaml)

Rolling deployment (50% batches, health-gated on `/health`) to an OCI Compute
instance group behind a Load Balancer, then APEX import via SQLcl and
`fn deploy` for the three Functions. All secrets come from OCI Vault.

## Environments

- **DEV:** OCI Always Free where possible (ATP Free, small Compute, Functions).
- **PROD:** paid tier, auto-scaling instance pool, backups, OCI Monitoring
  alarms (ATP CPU > 80%, Function error rate > 5%), centralised OCI Logging.

## Performance test

```bash
jmeter -n -t devops/jmeter/krishimitra_load_test.jmx \
  -JBASE_URL=https://api.krishimitra.example -JBEARER=<jwt> \
  -l results.jtl -e -o report
```

Targets: disease-scan API p95 < 5s; read endpoints p95 < 2s; APEX pages < 2s on
4G. The plan ramps 10,000 threads over 5 minutes and holds for 10 minutes.
