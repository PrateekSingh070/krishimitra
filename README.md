# KrishiMitra — Farmer Advisory & Crop Intelligence Platform

> AI-powered advisory platform for Indian farmers. *KrishiMitra* means
> "Farmer's Friend".

> ## ✅ Default stack: Supabase (PostgreSQL) + Node.js + React
> The platform now runs **entirely free on [Supabase](https://supabase.com)**
> (PostgreSQL + Storage + Auth) with a Node.js/Express API and a small Vite +
> React web UI. All Oracle-specific business logic (PL/SQL) has been ported into
> Node services, ingestion runs as `node-cron` jobs, disease inference runs
> in-Node via ONNX, and the React UI replaces APEX.
>
> **➡ Start here: [`SUPABASE-SETUP.md`](SUPABASE-SETUP.md).** Schema lives in
> [`db/postgres/`](db/postgres), the API in [`backend/`](backend), and the UI in
> [`frontend/`](frontend).
>
> The original **Oracle/OCI** implementation (`db/ddl`, `db/plsql`, `db/ords`,
> `apex/`, `functions/`, `infra/terraform`, `oic/`) is preserved as
> **legacy/optional** and documented in the sections below.

This repository also contains the original **full Oracle KrishiMitra platform**
across all 5 modules: the data model, business logic, service API + contract,
the 3 ML notebooks, the OCI Functions, the APEX portal, the infrastructure
(Terraform), and the CI/CD + performance tooling. The full master specification
lives in [`farmer_advisory_platform_prompt.md`](farmer_advisory_platform_prompt.md).

> ### Runs free by default 💸→0
> The default path runs entirely on **OCI Always Free** + free external APIs —
> **no recurring cost**. Ingestion is native PL/SQL (no OIC), disease detection
> runs ONNX inside a Function (no paid Vision AI), Hindi advice is pre-translated
> (no Language AI), ML is served by a free Function (no Model Deployment), alerts
> go out by **email + in-app** (no paid SMS), and the entrypoint is an Always
> Free Load Balancer + Ampere A1 compute (no API Gateway). Paid services are kept
> as clearly-marked optional upgrades. Full mapping in **[`FREE-TIER.md`](FREE-TIER.md)**.

## Repository layout

```
db/postgres/  ★ DEFAULT 01_schema.sql, 02_indexes.sql, 03_triggers.sql,
              04_seed.sql, deploy.sql  (Supabase/PostgreSQL)
backend/      ★ DEFAULT Node.js + Express + pg API. src/services/ (ported
              PL/SQL), src/jobs/ (node-cron ingestion), src/routes/
frontend/     ★ DEFAULT Vite + React web UI (replaces APEX)
SUPABASE-SETUP.md  ★ DEFAULT setup guide

--- legacy / optional (original Oracle implementation) ---
db/
  ddl/      01_tables.sql, 02_indexes.sql, 03_audit_triggers.sql,
            04_network_acls.sql (ATP egress), 05_app_config.sql (free config)
  plsql/    PKG_FARMER, PKG_ALERTS, PKG_NOTIFY (email), PKG_SCHEME_MATCHER,
            PKG_PRICE_TRACKER, PKG_WEATHER_SYNC / PKG_MANDI_SYNC / PKG_SCHEME_SYNC
            (free ingestion), TRG_DISEASE_SCAN_ALERT, jobs.sql
  ords/     ords_setup.sql  (REST module /api/v1)
  seed/     crops, government schemes, 1000 farmers + activity data
  deploy.sql  master deploy script (run order)
backend/    Node.js + Express + node-oracledb REST API (JWT auth) + Dockerfile
api/        openapi.yaml  (OpenAPI 3.0 contract)
ml/         3 model notebooks + score.py (export artifacts to Object Storage)
functions/  OCI Functions: disease-classifier (ONNX), model-server (sowing/price),
            alert-dispatcher (email), report-generator; *_optional.py = paid path
oic/        OPTIONAL/legacy OIC designs (replaced by the free PL/SQL sync packages)
apex/       APEX portal: supporting views/LOVs + admin charts, theme assets, blueprint
infra/terraform/  VCN, ATP, Object Storage, Functions, compute + load_balancer (free);
                  streaming + api_gateway gated behind enable_paid_services
devops/     OCI DevOps build/deploy specs + JMeter load test
tests/      utPLSQL suite (PKG_SCHEME_MATCHER); Jest in backend/tests; pytest in functions/tests
FREE-TIER.md  the paid->free mapping + free-tier limits
```

## Architecture (free default)

```
[ Farmer's Phone / Browser ]
          |
          v
[ Always Free Load Balancer (10 Mbps) ]      (paid alt: API Gateway + WAF)
          |
    +-----+------+
    |            |
[ APEX/ORDS ]  [ Node.js API on Always Free Ampere A1 compute ]
    |            |
    +-----+------+
          |
[ Oracle ATP (Always Free Autonomous DB) ]
    |          |
[ ORDS ]   [ PL/SQL Packages, Triggers & DBMS_SCHEDULER jobs ]
          |
   +------+---------------------------+-----------------------+
   |                  |               |                       |
[ Free ingestion ]  [ Functions ]  [ PKG_NOTIFY ]      [ APEX charts ]
 (APEX_WEB_SERVICE)  disease(ONNX)   email + in-app      (admin BI)
   |                 model-server                          (paid alt: OAC)
   +--> Open-Meteo (weather, keyless)
   +--> Agmarknet / data.gov.in (prices, schemes; free key)
          |
[ Always Free Object Storage ]  (Images / Reports / Model Artifacts)
```

Paid alternatives (OIC, OCI Streaming, API Gateway/WAF, Vision/Language AI, Data
Science Model Deployment, OAC) remain in the repo as optional upgrades — see
[`FREE-TIER.md`](FREE-TIER.md). The Terraform skeleton provisions the free OCI
resources; application code (PL/SQL, ORDS, Node API, Functions, ML, APEX) is
deployed onto them via the DevOps pipelines.

## The 5 modules

| # | Module | Where it lives (free default) |
|---|--------|-------------------------------|
| 1 | Crop Disease Scanner | `functions/disease-classifier` (ONNX + pre-translated Hindi), `ml/01_disease_classifier.ipynb`, `TRG_DISEASE_SCAN_ALERT`, APEX page 2 |
| 2 | Smart Sowing Advisor | `ml/02_sowing_recommender.ipynb`, `functions/model-server` (`model=sowing`), APEX page 3 |
| 3 | Market Price Predictor | `ml/03_price_forecaster.ipynb`, `functions/model-server` (`model=price`), `PKG_PRICE_TRACKER`, `PKG_MANDI_SYNC`, APEX page 4 |
| 4 | Early Warning Alerts | `PKG_ALERTS` + `PKG_NOTIFY` (email + in-app), `JOB_ALERT_DISPATCH`; optional `functions/alert-dispatcher` |
| 5 | Govt Scheme Matcher | `PKG_SCHEME_MATCHER`, `PKG_SCHEME_SYNC`, APEX page 7 |

## Prerequisites

- An Oracle Autonomous Database (ATP) — Always Free is fine for dev. The DB
  scripts use `DBMS_CRYPTO`, `JSON_TABLE`, and `DBMS_SCHEDULER` (all available
  on ATP). `DBMS_CRYPTO` execute may need to be granted to the schema by ADMIN.
- [SQLcl](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/) (or
  SQL*Plus) to run the scripts.
- Node.js >= 18 for the API (uses node-oracledb **Thin** mode — no Instant
  Client required).
- (Optional) [utPLSQL v3](https://utplsql.org) to run the PL/SQL tests, and
  Terraform >= 1.5 + the OCI provider for the infra skeleton.

## Setup — database

Run as the application schema owner (e.g. `KRISHIMITRA`). ADMIN must first grant
crypto privileges and (for the free ingestion/email path) the outbound network
ACLs once:

```sql
-- as ADMIN
GRANT EXECUTE ON DBMS_CRYPTO TO krishimitra;
-- allow ATP egress to Open-Meteo + data.gov.in (+ your SMTP host) for the free
-- ingestion/email path:
@db/ddl/04_network_acls.sql
```

Then, as `KRISHIMITRA`, set the free `DATAGOV_API_KEY` (and optional SMTP
user/password) in `app_config` from an **un-committed** script — see the
guidance in [`db/ddl/05_app_config.sql`](db/ddl/05_app_config.sql).

Then deploy everything in order:

```bash
sql krishimitra/<password>@<atp_high_tns> @db/deploy.sql
```

`deploy.sql` runs: tables → indexes → audit triggers → PL/SQL packages
(PKG_ALERTS first, as others depend on it) → disease-scan trigger → scheduler
jobs → ORDS module → seed data. The seed step generates 1,000 farmers, ~500
disease scans (HIGH/CRITICAL ones fire alerts via the trigger), 365 days of
Mandi prices, and runs an initial scheme-match pass.

To run pieces individually, execute the files under `db/ddl`, `db/plsql`,
`db/ords`, and `db/seed` in the order listed in `deploy.sql`.

## Setup — API

```bash
cd backend
cp .env.example .env        # fill in DB + JWT settings (or AUTH_DISABLED=true for dev)
npm install
npm start                   # http://localhost:3000  (health: GET /health)
```

For ATP wallet connections, point `TNS_ADMIN` at your unzipped wallet directory
and set `DB_CONNECT_STRING` to a TNS alias (e.g. `krishimitradb_high`). Secrets
are read from the environment; in OCI they are injected from **OCI Vault** /
resource principals — nothing is hardcoded.

Key endpoints (all under `/api/v1`, JWT-protected — see [`api/openapi.yaml`](api/openapi.yaml)):

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/farmers` | Register a farmer (Aadhaar hashed in DB) |
| GET/PATCH/DELETE | `/farmers/{id}` | Profile read / update / deactivate |
| GET | `/crops` | Crop master data |
| POST/GET | `/disease-scans` | Record / list scans (HIGH→auto alert) |
| GET | `/mandi-prices`, `/mandi-prices/history` | Latest prices + time series |
| GET | `/alerts`, POST `/alerts/dispatch` | Alert history; batch dispatch (admin) |
| GET | `/schemes`, `/schemes/farmer/{id}` | Schemes + personalised matches |
| POST | `/schemes/farmer/{id}/match` | Recompute matches |
| GET | `/recommendations/{farmerCropId}` | Stored ML predictions |

## Tests

```bash
# PL/SQL (requires utPLSQL v3 installed):
sql krishimitra/<pwd>@<tns> @tests/utplsql/test_pkg_scheme_matcher.pkb
-- then:  EXEC ut.run('test_pkg_scheme_matcher');

# Node API:
cd backend && npm test
```

The Jest suite mocks the Oracle layer, so it runs without a database.

## Security notes (implemented in this layer)

- **Aadhaar** is only ever stored as a SHA-256 hash (`PKG_FARMER.hash_aadhaar`
  via `DBMS_CRYPTO`); the raw number is never persisted.
- **Zero hardcoded secrets** — DB/JWT/API credentials come from env / OCI Vault.
- **JWT/OAuth2** auth middleware (HS256 dev secret or RS256 JWKS for prod),
  rate limiting, `helmet`, and CORS on the API.
- Oracle errors are mapped to safe HTTP responses; logs redact auth headers and
  Aadhaar fields.
- Terraform pins the region to an **India region** (data localisation) and uses
  private subnets for the DB.

## Component guides

Each area has its own README with setup/deploy steps:

- **ML notebooks:** [`ml/README.md`](ml/README.md) — train + deploy Models 1-3.
- **OCI Functions:** [`functions/README.md`](functions/README.md) — `fn deploy`,
  local `pytest` (33 tests, no SDK needed).
- **OIC integrations (optional/legacy):** [`oic/README.md`](oic/README.md) —
  replaced by the free PL/SQL sync packages; kept for the paid path.
- **Free-tier mapping:** [`FREE-TIER.md`](FREE-TIER.md) — paid→free per component.
- **APEX portal:** [`apex/README.md`](apex/README.md) + [`apex/PAGES.md`](apex/PAGES.md)
  — supporting views, theme assets, and the 9-page blueprint.
- **Infrastructure:** [`infra/terraform/README.md`](infra/terraform/README.md).
- **CI/CD + perf:** [`devops/README.md`](devops/README.md) — build/deploy
  pipelines, Dockerfile, JMeter 10k-farmer load test.

## Test commands at a glance

```bash
cd backend  && npm install && npm test     # Node API (Jest)  -> 3 passing
cd functions && python -m pytest tests -q   # Functions logic  -> 33 passing
# PL/SQL (needs utPLSQL): EXEC ut.run('test_pkg_scheme_matcher');
```

## Notes / limitations

- Live OCI provisioning/deployment is not performed from this repo; all
  artifacts are production-accurate source intended to run against a real OCI
  tenancy + Oracle ATP. The ML notebooks synthesise representative data so they
  execute end-to-end without cloud access (swap the `load_*` functions for the
  real ATP/Object Storage extracts).
- The free path needs **no OIC**: ingestion is native PL/SQL
  (`PKG_WEATHER_SYNC` / `PKG_MANDI_SYNC` / `PKG_SCHEME_SYNC`) on `DBMS_SCHEDULER`.
  The `oic/` specs remain as an optional/legacy paid alternative.
- The APEX app ships as its reproducible source (supporting objects, theme
  assets, page blueprint); generate `f100.sql` via `apex export -applicationid 100`.
