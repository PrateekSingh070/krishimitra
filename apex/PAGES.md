# KrishiMitra APEX — Page Blueprint (Application 100)

Each page below lists its regions, items, and processes, and the supporting
view/LOV it binds to (from `install/01_supporting_objects.sql`). This is the
spec the APEX builder app is assembled from; the binary app ships as `f100.sql`.

Global (Shared Components):
- **Theme:** Universal Theme + `#APP_IMAGES#krishimitra.css`, `lang-toggle.js`.
- **Auth:** APEX Authentication = "Custom" backed by OTP/phone (farmers) or SSO
  (admins); `APP_USER` maps to `farmers.phone`. Session state protection on.
- **Application Item `P_LANG`** (hi/en) + Ajax process `SET_LANG`.
- **Navigation menu** labels from `ui_messages` (NAV_*).
- **PWA:** "Install Progressive Web App" enabled; offline-capable Home.

| Page | Hindi | English | Key components |
|------|-------|---------|----------------|
| 1 | होम | Home | Weather card (`vw_home_weather`), active alerts list (`vw_home_active_alerts`), quick-action buttons |
| 2 | फसल रोग जांच | Disease Scanner | File upload (image/*) -> Object Storage, processing spinner, result region (`vw_disease_scans`), severity badge, "Share with Officer" -> report-generator Function |
| 3 | बुवाई सलाहकार | Sowing Advisor | Input form (district LOV `vw_lov_districts`, soil radio, acres, budget slider) -> calls Sowing Model Deployment, Top-3 crop cards |
| 4 | बाजार भाव | Market Prices | Tabs: Current (`vw_latest_mandi_prices`), Forecast (JET line chart `vw_mandi_price_forecast`), Sell Alerts |
| 5 | मेरी फसलें | My Crops | Interactive Grid on `vw_my_crops` (CRUD via `farmer_crops`) |
| 6 | सतर्कता | Alerts | Alert history (`alerts` filtered by `:APP_USER`), notification settings |
| 7 | सरकारी योजनाएँ | Govt Schemes | Cards on `vw_scheme_matches` ranked by match_score, filters, Apply Now |
| 8 | मेरी प्रोफ़ाइल | My Profile | Form on `farmers` (calls `PKG_FARMER.update_farmer`) |
| 100 | Admin | Admin | Native APEX analytics charts (free; no OAC), user management (restricted to admin auth scheme) |

## Page 1 — Home
- **R_WEATHER** (Static/Card): source `vw_home_weather` where `district = :P1_DISTRICT`.
- **R_ALERTS** (Classic Report): `vw_home_active_alerts` where `farmer_id = :APP_USER_ID`.
- **Buttons:** to pages 2/3/4 (NAV_* labels). Offline: cache via PWA service worker.

## Page 2 — Disease Scanner
- **P2_IMAGE** (File Browse, accept `image/*`): on submit, process `UPLOAD_TO_OS`
  PUTs to bucket `krishimitra-disease-scans` under `disease-scans/:APP_USER_ID/`.
- The Object Storage event triggers the `disease-classifier` Function, which
  writes the scan via ORDS. The page polls `vw_disease_scans` for the latest row.
- **R_RESULT:** disease (hi+en), `<span class="km-sev km-sev-&P2_SEVERITY.">`,
  confidence %, treatment steps.
- **BTN_SHARE:** Ajax -> `report-generator` Function -> open returned PAR URL.

## Page 3 — Sowing Advisor
- **Form items:** `P3_DISTRICT` (LOV `vw_lov_districts`), `P3_SOIL` (radio:
  Sandy/Loamy/Clay/Black/Silt), `P3_ACRES`, `P3_BUDGET` (slider).
- **Process `RECOMMEND`:** POST features to the free `model-server` Function
  (`{"model":"sowing","instances":[...]}`) — not a paid Model Deployment —
  insert into `ml_predictions`, render Top-3 crop cards
  (name hi/en, expected yield qtl/acre, est. revenue, water need, sowing window,
  confidence badge).

## Page 4 — Market Prices
- **Tab Current:** Interactive Report on `vw_latest_mandi_prices` with trend arrow.
- **Tab Forecast:** APEX JET line chart, series from `vw_mandi_price_forecast`
  vs historical `mandi_prices`.
- **Tab Sell Alerts:** form writing a threshold; a DB job / `PKG_PRICE_TRACKER`
  raises the alert when crossed.

## Page 5–8, 100
- **5 My Crops:** Interactive Grid on `vw_my_crops`, DML to `farmer_crops`.
- **6 Alerts:** report on `alerts`; settings stored on `farmers.preferred_lang`/channel.
- **7 Govt Schemes:** Cards region on `vw_scheme_matches`, eligibility checkmarks,
  Apply Now -> `apply_url`.
- **8 My Profile:** Form on `farmers`; Save calls `PKG_FARMER.update_farmer`.
- **100 Admin [FREE PATH]:** native APEX dashboard (no OAC iframe), admin-only auth:
  - KPI tiles (Display-only/Cards) from `vw_admin_stats` (active farmers, scans 30d,
    pending alerts, alerts 7d, farmers with matches, active schemes).
  - **Scans/day** — APEX line chart on `vw_admin_scans_per_day` (x: `scan_day`,
    series: `scan_count`, `severe_count`).
  - **Alerts by type** — stacked bar / pie on `vw_admin_alerts_by_type`.
  - **Top diseases** — horizontal bar on `vw_admin_top_diseases`.
  - **Price trends** — multi-series line on `vw_admin_price_trends` (series per crop).
  All charts are built-in APEX (Oracle JET) regions — zero external BI cost. The
  paid OAC embed is no longer used.

## Accessibility & responsiveness
- WCAG 2.1 AA: labels on all items, color-contrast-safe severity badges, keyboard
  nav. Mobile-first: validated at 375px (see media query in `krishimitra.css`).
