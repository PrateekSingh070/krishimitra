# KrishiMitra — Free-Tier Architecture

KrishiMitra runs end-to-end on **OCI Always Free** plus **free, keyless/low-cost
external APIs**. There are **no recurring charges** on the default path. Every
paid service has been replaced with a free equivalent; the paid implementations
are retained as clearly-marked optional upgrades.

## Paid → Free mapping

| Capability | Paid (optional) | Free default | Where |
|------------|-----------------|--------------|-------|
| Integrations / ingestion | Oracle Integration Cloud (OIC) | `DBMS_SCHEDULER` jobs + `APEX_WEB_SERVICE` in PL/SQL | `db/plsql/pkg_weather_sync`, `pkg_mandi_sync`, `pkg_scheme_sync`, `jobs.sql` |
| Weather data | OpenWeatherMap (key) | **Open-Meteo** (keyless) | `pkg_weather_sync` |
| Mandi prices | paid feeds | **Agmarknet / data.gov.in** (free key) | `pkg_mandi_sync` |
| Scheme data | manual / paid | **data.gov.in** (free key) | `pkg_scheme_sync` |
| Disease image classification | OCI Vision AI (custom model) | **ONNX MobileNetV3 in the Function** (onnxruntime) | `functions/disease-classifier` |
| Treatment translation | OCI Language AI | **Pre-translated Hindi lookup** | `functions/disease-classifier/disease_logic.py` |
| ML serving (sowing/price) | OCI Data Science Model Deployment | **`model-server` Function** loading models from Object Storage | `functions/model-server` |
| Real-time event bus | OCI Streaming | **`ALERTS` table + `JOB_ALERT_DISPATCH` polling** | `db/plsql/jobs.sql`, `pkg_alerts` |
| Alert delivery | Fast2SMS / Twilio (SMS) | **Email (OCI Email Delivery free tier) + in-app alerts** | `db/plsql/pkg_notify`, `functions/alert-dispatcher` |
| Public API entrypoint | API Gateway + WAF | **Always Free Flexible Load Balancer (10 Mbps)** + app-level JWT/helmet | `infra/terraform/modules/load_balancer` |
| API host | paid compute | **Always Free Ampere A1 compute** | `infra/terraform/modules/compute` |
| BI dashboards | Oracle Analytics Cloud (OAC) | **Native APEX charts** on `vw_admin_*` views | `apex/install/01_supporting_objects.sql`, `apex/PAGES.md` |
| Secrets | OCI Vault | **Function/Compute env + `DBMS_CLOUD` credentials** (still no secrets in source) | throughout |
| Database | — | **Always Free Autonomous DB (ATP)** | `infra/terraform/modules/atp` |
| Object storage | — | **Always Free Object Storage** | `infra/terraform/modules/object_storage` |
| App platform | — | **APEX + ORDS** (bundled with ATP, free) | `apex/`, `db/ords` |

## Alerts: email + in-app (default)

- Alerts are written to the `ALERTS` table by the business rules
  (`pkg_scheme_matcher`, `pkg_price_tracker`, the disease-scan trigger).
- The default channel is **`EMAIL`**. `JOB_ALERT_DISPATCH` runs every 15 minutes
  and calls `PKG_ALERTS.send_batch('EMAIL')` then `send_batch('APP')`.
- **EMAIL** is delivered by `PKG_NOTIFY` via `UTL_SMTP` (OCI Email Delivery free
  tier, or any free SMTP). **APP** alerts need no outbound call — they are the
  rows shown on the APEX **Alerts** page.
- **SMS is optional/paid** and is left for the optional `alert-dispatcher`
  stream consumer (`func_stream_optional.py`) if you ever enable it.

## What stays optional (paid) — kept, not deleted

- `oic/` — OIC integration designs (the PL/SQL sync packages replace them).
- `infra/terraform/modules/api_gateway` & `modules/streaming` — gated behind
  `enable_paid_services = true`.
- `functions/disease-classifier/func_vision_optional.py` — OCI Vision/Language AI.
- `functions/alert-dispatcher/func_stream_optional.py` — Streaming + Fast2SMS SMS.
- `ml/score.py` + the ADS deploy snippet — paid Model Deployment.

## Free-tier limits to keep in mind

- **Ampere A1 Always Free:** up to 4 OCPUs / 24 GB RAM total per tenancy. Default
  is 1 OCPU / 6 GB — fits comfortably.
- **Flexible Load Balancer:** keep min=max=**10 Mbps** to stay free.
- **Autonomous DB Always Free:** 2 instances max, 20 GB each, auto-stops after
  prolonged inactivity.
- **Object Storage:** 20 GB Always Free.
- **Functions:** generous monthly free invocations; cold starts apply.
- **OCI Email Delivery:** free monthly sending allowance; verify an approved
  sender and add the SMTP host to the ATP network ACL.
- **data.gov.in / Open-Meteo:** free; Open-Meteo is keyless, data.gov.in needs a
  free API key (stored as a `DBMS_CLOUD` credential, never in source).

## Zero hardcoded secrets

API keys and SMTP credentials are supplied at deploy time as `DBMS_CLOUD`
credentials or Function/Compute environment values — never committed. See
`db/ddl/05_app_config.sql` for the credential setup guidance.
