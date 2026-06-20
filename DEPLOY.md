# KrishiMitra — Free Cloud Deployment

Deploy the backend to **Render** (free web service) and the frontend to **Vercel** (free static hosting). The database and file storage stay on **Supabase** (already configured).

> **Cron job note:** Render's free tier spins down after 15 minutes of inactivity (~30 s cold start on next request). Scheduled jobs (weather/mandi sync) will not fire while the server is asleep. For always-on jobs, upgrade to Render's $7/month plan or switch to Fly.io.

---

## Prerequisites

- A [GitHub](https://github.com) account (free)
- Your code pushed to a GitHub repository

### 1 — Push to GitHub

```bash
# From d:\farmer oracle
git init          # if not already a git repo
git add .
git commit -m "KrishiMitra ready for deployment"
```

Then create a new **private** repository on https://github.com/new and push:

```bash
git remote add origin https://github.com/<your-username>/<repo-name>.git
git branch -M main
git push -u origin main
```

---

## Part A — Deploy Backend to Render

### 2 — Create a Render account

Go to **https://render.com** → Sign up (free, use GitHub login).

### 3 — Create a Web Service

1. Dashboard → **New** → **Web Service**
2. Connect your GitHub account and select your repository.
3. Fill in:
   - **Name:** `krishimitra-api`
   - **Root Directory:** `backend`
   - **Runtime:** `Node`
   - **Build Command:** `npm ci && npm run build`
   - **Start Command:** `node src/server.js`
   - **Instance Type:** `Free`
4. Click **Create Web Service** — Render will deploy automatically.

### 4 — Set environment variables in Render

Go to your service → **Environment** tab → Add the following variables one by one:

| Key | Value |
|-----|-------|
| `NODE_ENV` | `production` |
| `DATABASE_URL` | *(your Supabase Session Pooler URL from `.env`)* |
| `SUPABASE_URL` | `https://wfkcnzgkoxvrtuuotplx.supabase.co` |
| `SUPABASE_ANON_KEY` | *(your publishable key)* |
| `SUPABASE_SERVICE_ROLE` | *(your secret key)* |
| `SUPABASE_DISEASE_BUCKET` | `disease-scans` |
| `AUTH_DISABLED` | `true` |
| `ENABLE_JOBS` | `true` |
| `DATAGOV_API_KEY` | *(your data.gov.in key)* |
| `AGMARKNET_RESOURCE_ID` | `9ef84268-d588-465a-a308-a864a43d0070` |
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_SECURE` | `false` |
| `SMTP_USER` | *(your Gmail address)* |
| `SMTP_PASSWORD` | *(your 16-char App Password, no spaces)* |
| `SMTP_SENDER` | `KrishiMitra <you@gmail.com>` |
| `DB_SSL` | `true` |
| `DB_POOL_MAX` | `5` |

After saving, Render redeploys automatically.

### 5 — Note your backend URL

Once deployed, Render gives you a URL like:
```
https://krishimitra-api.onrender.com
```
Copy this — you'll need it for the frontend.

### 6 — Verify

Open in a browser:
```
https://krishimitra-api.onrender.com/health
```
You should see `{"status":"ok"}`.

---

## Part B — Deploy Frontend to Vercel

### 7 — Create a Vercel account

Go to **https://vercel.com** → Sign up (free, use GitHub login).

### 8 — Import the project

1. Dashboard → **Add New** → **Project**
2. Select your GitHub repository.
3. Set **Root Directory** to `frontend`.
4. Framework: Vercel auto-detects **Vite** — leave defaults.

### 9 — Set environment variable

In the **Environment Variables** section before deploying, add:

| Key | Value |
|-----|-------|
| `VITE_API_BASE` | `https://krishimitra-api.onrender.com` |

### 10 — Deploy

Click **Deploy**. Vercel builds and gives you a URL like:
```
https://krishimitra.vercel.app
```

Open it — your full KrishiMitra app is live on the internet.

---

## Updating the app

Any `git push` to `main` automatically redeploys both Render and Vercel.

---

## Summary of free limits

| Service | Limit |
|---------|-------|
| Render (free) | 750 hrs/month, spins down after 15 min idle |
| Vercel (free) | 100 GB bandwidth/month, unlimited deployments |
| Supabase (free) | 500 MB DB, 1 GB storage, 2 GB bandwidth |
| data.gov.in | Unlimited (fair use) |
| Open-Meteo | Unlimited (keyless) |
| Gmail SMTP | 500 emails/day |
