# KrishiMitra on Supabase (PostgreSQL) — Setup Guide

This is the **default, free** way to run KrishiMitra: a Supabase PostgreSQL
database + Storage, a Node.js/Express API, and a small Vite + React web UI.
Everything here uses free tiers. The Oracle artifacts (`db/ddl`, `db/plsql`,
`db/ords`, `apex/`, `functions/`, `infra/terraform`) are kept as **legacy** and
are not needed for this path.

Commands are written for **Windows PowerShell**.

---

## 1. Create a Supabase project (free)

1. Sign up at <https://supabase.com> and create a new project (free tier).
2. Choose a region close to you and set a strong database password.
3. Wait for the project to finish provisioning.

## 2. Create the schema + seed data

Open **SQL Editor** in the Supabase dashboard and run, in order, the contents of:

1. `db/postgres/01_schema.sql`
2. `db/postgres/02_indexes.sql`
3. `db/postgres/03_triggers.sql`
4. `db/postgres/04_seed.sql`  (creates ~1,000 farmers, prices, scans, matches)

> Alternatively, with `psql` installed locally:
>
> ```powershell
> cd "db/postgres"
> psql "$env:DATABASE_URL" -f deploy.sql
> ```

## 3. Create the Storage bucket

1. In the dashboard go to **Storage → Create bucket**.
2. Name it `disease-scans`. Make it **Public** (so scan image URLs render in the UI).

## 4. Collect your keys

From **Project Settings**:

- **Database → Connection string (URI)** → `DATABASE_URL`
- **API → Project URL** → `SUPABASE_URL`
- **API → `anon` public key** → `SUPABASE_ANON_KEY`
- **API → `service_role` key** → `SUPABASE_SERVICE_ROLE` (server-side only!)
- **API → JWT Settings → JWT Secret** → `JWT_SECRET` (only if you enable auth)

## 5. Configure and run the API

```powershell
cd backend
Copy-Item .env.example .env
# Edit .env: paste DATABASE_URL, SUPABASE_*, and (optionally) SMTP_* values.
# For local dev keep AUTH_DISABLED=true.
npm install
npm start
```

The API listens on <http://localhost:3000>. Health check:

```powershell
curl http://localhost:3000/health
```

### Email alerts (optional, free)

Set `SMTP_*` in `.env` to any free relay (e.g. a Gmail account with an
**App Password**, or Brevo's free SMTP). Without SMTP, alerts still appear
in-app (the Alerts tab) — email is simply skipped.

### Background jobs (optional)

Set `ENABLE_JOBS=true` on **one** running instance to enable the cron jobs
(weather/mandi/scheme ingestion, scheme matching, price sweep, alert dispatch).
`DATAGOV_API_KEY` (free from <https://data.gov.in>) is required for mandi/scheme
ingestion; weather (Open-Meteo) needs no key.

## 6. Run the web UI

```powershell
cd frontend
Copy-Item .env.example .env   # optional; dev proxy works out of the box
npm install
npm run dev
```

Open <http://localhost:5173>. The dev server proxies `/api` to the backend on
port 3000. Use the **Farmer ID** box (top-right) to switch farmers, and the
**EN / हिं** button to toggle language.

Pages: **Disease Scan** (upload a leaf photo → result), **Market Prices**,
**Govt Schemes** (with on-demand re-match), **Alerts**, **My Profile**.

## 7. Disease classification model (optional)

The classifier runs **in Node** with `onnxruntime-node`. Drop these into
`backend/ml-artifacts/` (created by you):

- `disease_mobilenetv3.onnx` — the exported MobileNetV3 model (see `ml/`)
- `class_labels.json` — array of class names in training order
- `disease_lookup.json` — `{ label: { disease, severity, treatment, treatment_hi } }`

If the model file is absent, the endpoint still works and returns a
"needs review" result, so you can build the rest first.

## 8. ML predictions (sowing / price)

The API serves predictions from the `ml_predictions` table. Populate it from
your trained models with `ml/sidecar/populate_predictions.py`, or run the
**optional** FastAPI sidecar (`ml/sidecar/main.py`) for live inference.

---

## Production notes

- Deploy the API to any free Node host (Render, Fly.io, Railway free tier, or an
  Always-Free VM). Set `AUTH_DISABLED=false` and configure `JWT_SECRET`
  (Supabase JWT secret) so the existing JWT middleware validates Supabase tokens.
- Build the UI with `npm run build` (output in `frontend/dist/`) and host it as
  static files (Supabase hosting, Netlify, GitHub Pages, etc.). Set
  `VITE_API_BASE` to the API's public URL.
- Run cron jobs on a single instance (`ENABLE_JOBS=true`) and set
  `TZ=Asia/Kolkata` so schedules match IST.
