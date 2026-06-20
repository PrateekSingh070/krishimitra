# KrishiMitra — Detailed Setup Guide (Windows / PowerShell)

> ⚠️ **This guide covers the LEGACY Oracle/OCI deployment.** The default,
> free-by-design stack is now **Supabase (PostgreSQL) + Node.js + React** —
> follow **[`SUPABASE-SETUP.md`](SUPABASE-SETUP.md)** instead. Keep reading only
> if you specifically want to run the original Oracle implementation.

A step-by-step guide to take this repo from source to a running platform.
Written for **Windows PowerShell** (your environment). Two rules to remember:

- Set environment variables with `$env:NAME = "value"` (NOT `export`).
- After installing a CLI, **open a new PowerShell window** so it's on your PATH.

You do not have to do everything at once. The fastest way to see something work
is **Phase 0 -> 1 -> 4 -> 5** (install tools, OCI account, create ATP, run the
DB + API locally). The rest (Functions, ML, APEX, load balancer, CI/CD) layers
on top afterwards.

> ### 💸 This setup is FREE by default
> Everything below uses **OCI Always Free** + free external APIs. You will not be
> charged on the default path. Paid phases (OIC, API Gateway + WAF, Streaming,
> Vault, paid Vision/Language AI, Data Science Model Deployment, OAC) are clearly
> marked **OPTIONAL / PAID** and are not required. See [`FREE-TIER.md`](FREE-TIER.md)
> for the full paid→free mapping. Keep these limits in mind: Ampere A1 ≤ 4 OCPU /
> 24 GB total, Flexible Load Balancer at **10 Mbps** (min=max) to stay free, and
> two Always Free Autonomous DBs max.

---

## Phase 0 — Install the tools

Run PowerShell **as Administrator**. Using `winget` (built into Windows 11):

```powershell
winget install --id Hashicorp.Terraform -e
winget install --id Oracle.SQLcl -e          # SQL command line (needs Java; see note)
winget install --id OpenJS.NodeJS.LTS -e     # Node 20 (you already have v22 - fine)
winget install --id Python.Python.3.12 -e
winget install --id Docker.DockerDesktop -e
winget install --id Git.Git -e
```

Install the **OCI CLI** (separate installer):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command `
  "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1'))"
```

Install the **Fn CLI** (for OCI Functions) — easiest via Docker Desktop being
present, then download the Windows binary from the Fn releases page and add it to
PATH, or use it from WSL. (You only need this in Phase 6.)

> SQLcl note: it needs Java 11+. If `sql` isn't found, install Temurin JDK
> (`winget install EclipseAdoptium.Temurin.21.JDK`) and re-open PowerShell.

**Close and reopen PowerShell**, then verify:

```powershell
terraform -version
oci --version
node --version
python --version
sql -version
```

---

## Phase 1 — Create your OCI account

1. Sign up at https://www.oracle.com/cloud/free/ and pick a **home region in
   India**: `India South (Hyderabad)` = `ap-hyderabad-1`, or
   `India West (Mumbai)` = `ap-mumbai-1`. (Required for data localisation.)
2. In the Console, note your **Tenancy OCID** and create (or pick) a
   **Compartment** — note its OCID. (Profile/avatar -> Tenancy; Identity ->
   Compartments.)
3. Configure the CLI (creates an API key and `~/.oci/config`):

```powershell
oci setup config
```

Follow the prompts (user OCID, tenancy OCID, region). It generates a key at
`C:\Users\<you>\.oci\oci_api_key.pem`. Then in the Console: **Identity -> Users
-> your user -> API Keys -> Add API Key -> Paste Public Key** (paste the contents
of `oci_api_key_public.pem`).

4. Test it:

```powershell
oci iam region list
```

---

## Phase 2 — Get external API keys (free)

The free path needs just **one** key:

- **data.gov.in** — https://data.gov.in (register -> get a free API key). Used by
  the Mandi-price and scheme sync packages.

No key needed for weather: the free path uses **Open-Meteo** (keyless). You will
store the data.gov.in key as a `DBMS_CLOUD` credential in Phase 4 (never in
source).

> **OPTIONAL / PAID:** OpenWeatherMap (https://openweathermap.org/api) and
> Fast2SMS (https://www.fast2sms.com) are only needed if you enable the paid
> weather provider or SMS alerts. The free path uses email + in-app alerts.

---

## Phase 3 — Provision infrastructure with Terraform

```powershell
cd "D:\farmer oracle\infra\terraform"
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars     # fill in tenancy_ocid and compartment_ocid, set region
```

Set the ATP admin password (PowerShell syntax — note `$env:`):

```powershell
$env:TF_VAR_atp_admin_password = "Krishi#Mitra2026"
```

> ATP password rules: 12-30 chars, at least one uppercase, lowercase, and number,
> and it cannot contain the word "admin".

Then run Terraform:

```powershell
terraform init
terraform plan
terraform apply        # type 'yes' when prompted
```

> **Free vs paid:** the default `enable_paid_services = false` provisions an
> Always Free **Ampere A1 compute** + Always Free **Flexible Load Balancer** as
> the public entrypoint (no API Gateway, no Streaming). Set
> `enable_paid_services = true` only if you want the paid gateway/streaming. Set
> your A1 host SSH key first: `$env:TF_VAR_ssh_public_key = (Get-Content ~/.ssh/id_rsa.pub -Raw)`.

When it finishes, record the outputs:

```powershell
terraform output
```

You'll get the VCN id, ATP id, bucket names, the app host private IP, and the
Load Balancer public IP (your API entrypoint).

> If `terraform plan` fails with auth errors, your `~/.oci/config` profile isn't
> set up — redo Phase 1 step 3. If it complains about the region, make sure
> `region` in `terraform.tfvars` is `ap-mumbai-1` or `ap-hyderabad-1`.

---

## Phase 4 — Set up the database (ATP)

### 4a. Download the wallet

In the Console: **Oracle Database -> Autonomous Database -> krishimitradb ->
Database Connection -> Download Wallet**. Set a wallet password, save the zip,
and unzip it to e.g. `D:\farmer oracle\backend\wallet`.

(Or via CLI:)

```powershell
oci db autonomous-database generate-wallet --autonomous-database-id <atp-ocid> `
  --password "WalletPass#123" --file wallet.zip
Expand-Archive wallet.zip -DestinationPath "D:\farmer oracle\backend\wallet"
```

### 4b. Create the app schema + grant crypto (as ADMIN)

```powershell
$env:TNS_ADMIN = "D:\farmer oracle\backend\wallet"
sql admin/"Krishi#Mitra2026"@krishimitradb_high
```

In the SQL prompt:

```sql
CREATE USER krishimitra IDENTIFIED BY "Krishi#Mitra2026";
GRANT CONNECT, RESOURCE TO krishimitra;
ALTER USER krishimitra QUOTA UNLIMITED ON DATA;
GRANT EXECUTE ON DBMS_CRYPTO TO krishimitra;   -- needed for Aadhaar hashing
GRANT EXECUTE ON UTL_SMTP TO krishimitra;      -- free email alerts (PKG_NOTIFY)
GRANT EXECUTE ON DBMS_CLOUD TO krishimitra;    -- credentials for data.gov.in/email
```

Still as ADMIN, allow ATP outbound calls for the free ingestion/email path
(Open-Meteo + data.gov.in; add your SMTP host too):

```sql
@db/ddl/04_network_acls.sql
EXIT;
```

Then, as `KRISHIMITRA`, store the free API key + (optional) SMTP credentials in
`app_config` — run this from a separate, **un-committed** script (not in git):

```sql
MERGE INTO app_config t USING (
  SELECT 'DATAGOV_API_KEY'     k, '<your free data.gov.in key>' v FROM dual UNION ALL
  SELECT 'EMAIL_SMTP_USER',       '<ocid-smtp-user>'             FROM dual UNION ALL
  SELECT 'EMAIL_SMTP_PASSWORD',   '<smtp-password>'              FROM dual
) s ON (t.cfg_key = s.k)
WHEN MATCHED THEN UPDATE SET t.cfg_value = s.v
WHEN NOT MATCHED THEN INSERT (cfg_key, cfg_value) VALUES (s.k, s.v);
COMMIT;
```

### 4c. Deploy schema, PL/SQL, ORDS, and seed data

```powershell
cd "D:\farmer oracle"
sql krishimitra/"Krishi#Mitra2026"@krishimitradb_high @db/deploy.sql
```

Verify:

```powershell
sql krishimitra/"Krishi#Mitra2026"@krishimitradb_high
```
```sql
SELECT COUNT(*) FROM farmers;        -- ~1000
SELECT COUNT(*) FROM mandi_prices;   -- thousands
SELECT COUNT(*) FROM scheme_matches; -- > 0
EXIT;
```

---

## Phase 5 — Run the Node API (local first, then cloud)

### 5a. Run locally against ATP

```powershell
cd "D:\farmer oracle\backend"
Copy-Item .env.example .env
notepad .env
```

Set in `.env`:

```
DB_USER=krishimitra
DB_PASSWORD=Krishi#Mitra2026
DB_CONNECT_STRING=krishimitradb_high
TNS_ADMIN=D:\farmer oracle\backend\wallet
AUTH_DISABLED=true
```

Then:

```powershell
npm install
npm start
```

In another PowerShell window, test it:

```powershell
Invoke-RestMethod http://localhost:3000/health
Invoke-RestMethod http://localhost:3000/api/v1/mandi-prices
Invoke-RestMethod http://localhost:3000/api/v1/crops
```

That proves the whole data + service layer works end-to-end.

### 5b. Containerise + push to OCIR (when ready for cloud)

```powershell
cd "D:\farmer oracle\backend"
docker build -t krishimitra-api .
docker tag krishimitra-api <region>.ocir.io/<namespace>/krishimitra-api:latest
docker login <region>.ocir.io     # username: <namespace>/<your-oci-username>, password: an Auth Token
docker push <region>.ocir.io/<namespace>/krishimitra-api:latest
```

(Find `<namespace>` in Console -> Tenancy details -> Object Storage Namespace.
Create an Auth Token under Identity -> your user -> Auth Tokens.)

Then deploy the image to a Compute VM behind the Load Balancer, with env vars
injected from Vault and the wallet mounted at `/app/wallet`. Health check:
`GET /health`. Turn OFF `AUTH_DISABLED` in cloud and set `JWT_JWKS_URI`.

---

## Phase 6 — IAM (+ optional Vault)

1. **IAM groups + policies:** create `krishimitra-developers`,
   `krishimitra-farmers`, `krishimitra-admins` with least-privilege policies.
2. **Dynamic groups + policies** so Functions (resource principals) can read
   Object Storage (models + images). No Streaming needed on the free path.
3. **Secrets without paid Vault:** on the free path, secrets live as
   `DBMS_CLOUD` credentials in ATP (Phase 4) and as **Function/Compute config**
   values. Nothing is hardcoded in source.

> **OPTIONAL / PAID — OCI Vault.** If you prefer Vault: Identity & Security ->
> Vault -> create Key -> create Secrets for the DB password, SMTP password,
> data.gov.in key, and JWKS URI, then reference their OCIDs from the Functions.
> The free path does not require this.

---

## Phase 7 — Deploy the OCI Functions (free)

```powershell
fn create context oci-km --provider oracle
fn use context oci-km
fn update context oracle.compartment-id <compartment-ocid>
fn update context registry <region>.ocir.io/<namespace>/krishimitra-fn

cd "D:\farmer oracle\functions\disease-classifier"; fn -v deploy --app krishimitra-fn-app
cd "..\model-server";      fn -v deploy --app krishimitra-fn-app
cd "..\report-generator";  fn -v deploy --app krishimitra-fn-app
```

These are all free-path Functions:
- **disease-classifier** runs **ONNX** inference locally (no paid Vision AI) and
  serves **pre-translated Hindi** advice (no paid Language AI). Upload
  `disease_mobilenetv3.onnx`, `disease_class_labels.json`, and
  `disease_lookup.json` to the `krishimitra-model-artifacts` bucket (Phase 8).
- **model-server** serves sowing + price predictions from models in Object
  Storage (no paid Model Deployment).

In the Console, set each function's config (ORDS URL, `MODEL_BUCKET`,
`OBJECT_NAMESPACE`). Then create the trigger:

- **Events:** Object Storage "Object - Create" on `krishimitra-disease-scans`
  bucket -> invoke `disease-classifier`.

Alerts need **no Function** on the free path — the DB job `JOB_ALERT_DISPATCH`
emails unsent alerts every 15 minutes (Phase 4 deployed it).

> **OPTIONAL / PAID:** `alert-dispatcher` defaults to emailing from ATP (free);
> its `func_stream_optional.py` (OCI Streaming + Fast2SMS) is only for the paid
> SMS path. Deploy it only if you enabled `enable_paid_services`.

Run the function tests anytime locally:

```powershell
cd "D:\farmer oracle\functions"
python -m pip install -r requirements-dev.txt
python -m pytest tests -q       # 33 passing
```

---

## Phase 8 — Train the ML models for free + export to Object Storage

Train **locally** (your PC) or in a **free Colab/Kaggle GPU** — no paid Data
Science notebook needed:

1. `pip install -r ml/requirements.txt`
2. **Sowing recommender:** run `02_sowing_recommender.ipynb` ->
   `joblib.dump(pipeline, "sowing_model.joblib")`.
3. **Price forecaster:** run `03_price_forecaster.ipynb` -> one pickle per crop
   at `price_models/prophet_crop_<id>.pkl`.
4. **Disease classifier:** run `01_disease_classifier.ipynb` (free Colab GPU is
   ideal for PlantVillage), export to ONNX with `tf2onnx` ->
   `disease_mobilenetv3.onnx` + `disease_class_labels.json`. Keep
   `disease_lookup.json` (English + pre-translated Hindi).
5. Upload all artifacts to the free `krishimitra-model-artifacts` bucket:
   ```powershell
   oci os object put -bn krishimitra-model-artifacts --file sowing_model.joblib
   oci os object put -bn krishimitra-model-artifacts --file disease_mobilenetv3.onnx
   oci os object put -bn krishimitra-model-artifacts --file disease_class_labels.json
   oci os object put -bn krishimitra-model-artifacts --file disease_lookup.json
   oci os object put -bn krishimitra-model-artifacts --file price_models/prophet_crop_5.pkl --name price_models/prophet_crop_5.pkl
   ```

The `disease-classifier` and `model-server` Functions load these on first call.

> **OPTIONAL / PAID:** to use an ADS Model Deployment instead, see the snippet in
> [`ml/README.md`](ml/README.md). Not needed for the free path.

---

## Phase 9 — Data ingestion (free, already deployed)

There is **no OIC** on the free path. Ingestion runs inside ATP as PL/SQL on
`DBMS_SCHEDULER` (deployed by `db/deploy.sql` + `jobs.sql` in Phase 4):

- `JOB_WEATHER_SYNC` — every 6h, `PKG_WEATHER_SYNC.run` (Open-Meteo, keyless).
- `JOB_MANDI_SYNC` — daily 06:00 IST, `PKG_MANDI_SYNC.run` (Agmarknet).
- `JOB_SCHEME_SYNC` — weekly Sun 02:00 IST, `PKG_SCHEME_SYNC.run` (data.gov.in).

Verify / run on demand:

```sql
EXEC pkg_weather_sync.run;
EXEC pkg_mandi_sync.run;
SELECT job_name, state, last_start_date FROM user_scheduler_jobs;
```

> **OPTIONAL / PAID — OIC.** If you ever want OIC instead, the designs are in
> `oic/` (specs + sample payloads + field mappings). Not required for the free path.

---

## Phase 10 — Build & import the APEX portal

1. Run the supporting objects:

```powershell
sql krishimitra/"Krishi#Mitra2026"@krishimitradb_high @apex/install/01_supporting_objects.sql
```

2. Open **APEX** (your ATP's APEX URL, free with ATP), create/confirm workspace
   `KRISHIMITRA`, and build the 9 pages exactly per [`apex/PAGES.md`](apex/PAGES.md).
3. Shared Components -> Static Application Files -> upload
   `apex/static/css/krishimitra.css` and `apex/static/js/lang-toggle.js`.
4. Wire page 2 to the disease-scans bucket, page 3 to the **`model-server`
   Function** (`model=sowing`), page 4 chart to `vw_mandi_price_forecast`, page 7
   to `vw_scheme_matches`, and the **admin page 100 to the `vw_admin_*` views as
   native APEX charts** (no OAC).
5. Export with `apex export -applicationid 100` (SQLcl) and commit `f100.sql`.

---

## Phase 11 — Go public (free: Load Balancer)

On the free path the **Always Free Flexible Load Balancer** (provisioned in
Phase 3) is your public entrypoint:
- It forwards port 80 to the Node API on the Ampere A1 host (port 3000).
- Health check is `GET /health`.
- Security is enforced in-app: JWT/OAuth2 middleware, `helmet`, CORS, and rate
  limiting (set `AUTH_DISABLED=false` and `JWT_JWKS_URI` in cloud).
- Point your DNS at the Load Balancer public IP (`terraform output
  load_balancer_public_ip`).

> **OPTIONAL / PAID — API Gateway + WAF.** Set `enable_paid_services = true` and
> re-apply Terraform to add an API Gateway (JWT authorizer, route `/api/v1/*` ->
> Node API, `/ords/*` -> ORDS) and attach WAF managed rules (SQLi, XSS).

---

## Phase 12 — CI/CD, testing, monitoring, demo

1. **CI/CD:** push this repo to GitHub (`krishimitra-platform`), connect it in
   OCI DevOps, and create pipelines from `devops/build_spec.yaml` and
   `devops/deploy_spec.yaml`.
2. **Load test:**
   ```powershell
   jmeter -n -t "devops\jmeter\krishimitra_load_test.jmx" -JBASE_URL=http://<lb-public-ip> -JBEARER=<jwt> -l results.jtl -e -o report
   ```
   Targets: disease-scan p95 < 5s, reads < 2s. (Note the free LB is 10 Mbps —
   size your test accordingly.)
3. **Monitoring:** create OCI Alarms (ATP CPU > 80%, Function error rate > 5%),
   enable centralized Logging.
4. **Demo video:** record the 5 modules working end-to-end.

---

## Cost summary

| Component | Service (free path) | Cost |
|-----------|---------------------|------|
| Database | Always Free Autonomous DB (ATP) | ₹0 |
| App host | Always Free Ampere A1 compute | ₹0 |
| Entrypoint | Always Free Flexible Load Balancer (10 Mbps) | ₹0 |
| Object storage | Always Free Object Storage (20 GB) | ₹0 |
| Disease AI | ONNX in Function (no Vision AI) | ₹0 |
| Translation | Pre-translated Hindi lookup (no Language AI) | ₹0 |
| ML serving | model-server Function (no Model Deployment) | ₹0 |
| Ingestion | PL/SQL + DBMS_SCHEDULER (no OIC) | ₹0 |
| Weather | Open-Meteo (keyless) | ₹0 |
| Prices / schemes | data.gov.in (free key) | ₹0 |
| Alerts | Email (OCI Email Delivery free tier) + in-app | ₹0 |
| Dashboards | Native APEX charts (no OAC) | ₹0 |
| **Total** | | **₹0 / month** |

Optional paid upgrades (only if you choose them): OIC, API Gateway + WAF,
Streaming, Vault, Vision/Language AI, Data Science Model Deployment, OAC, SMS.

## Quick troubleshooting

| Symptom | Fix |
|---------|-----|
| `export : not recognized` | Use `$env:NAME = "value"` in PowerShell |
| `terraform : not recognized` | Install it (Phase 0), then reopen PowerShell |
| `sql : not recognized` | Install SQLcl + a JDK, reopen PowerShell |
| ATP connect fails | `$env:TNS_ADMIN` must point to the unzipped wallet folder; use the `_high` service |
| `ORA-20001` on register | Phone already exists (expected — it's the unique constraint) |
| API 500 on startup | Check `.env` DB settings; ensure `GRANT EXECUTE ON DBMS_CRYPTO` was run |
| Terraform auth error | Re-run `oci setup config` and upload the public API key |
