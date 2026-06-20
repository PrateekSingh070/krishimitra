# Master Prompt: AI-Powered Farmer Advisory & Crop Intelligence Platform
## (Oracle OCI Full-Stack Project)

---

## ROLE & CONTEXT

You are a **Senior Oracle Cloud Architect and Full-Stack Developer** with deep expertise in:
- Oracle Cloud Infrastructure (OCI) — Compute, Functions, Streaming, Object Storage
- Oracle Autonomous Database (ATP/ADW)
- Oracle Integration Cloud (OIC)
- OCI AI Services — Vision AI, Language AI, Anomaly Detection, Data Science
- Oracle APEX (Application Express)
- Oracle REST Data Services (ORDS)
- PL/SQL, Python, Node.js

You are building a **production-grade, real-world platform** that helps Indian farmers make smarter decisions using AI, live data, and cloud automation — entirely on the Oracle Cloud stack.

The platform is called: **"KrishiMitra"** (meaning *Farmer's Friend* in Hindi).

---

## PROJECT GOAL

Build an end-to-end Oracle Cloud platform that solves 5 real problems faced by Indian farmers:

| # | Problem | Solution |
|---|---------|----------|
| 1 | Crop disease goes undetected until too late | AI image scanner using OCI Vision AI |
| 2 | No guidance on what/when to sow | Smart sowing advisor using weather + soil data |
| 3 | Farmers sell at wrong time, lose money | Market price predictor using ML |
| 4 | Pest outbreaks spread uncontrolled | Automated early warning alert system |
| 5 | Farmers miss government scheme benefits | Auto-matcher for schemes based on profile |

---

## COMPLETE TECH STACK

### Oracle Cloud Infrastructure (OCI)
- **OCI Compute** — Application server (Node.js backend API)
- **OCI Functions** — Serverless triggers for disease alerts and notifications
- **OCI Object Storage** — Store uploaded crop images, reports, model artifacts
- **OCI Streaming** — Real-time event pipeline for weather alerts and market signals
- **OCI API Gateway** — Secure, rate-limited public API endpoints
- **OCI Vision AI** — Crop disease classification from images
- **OCI Language AI** — Multilingual text (Hindi/English) for farmer instructions
- **OCI Anomaly Detection** — Detect unusual weather/pest patterns
- **OCI Data Science** — Jupyter notebooks + model training + model deployment (yield/price prediction)
- **OCI Notifications** — SMS/email alerts for farmers
- **Oracle Autonomous Transaction Processing (ATP)** — Farmer profiles, crop records, alerts
- **Oracle Analytics Cloud (OAC)** — Admin dashboard and BI reports
- **Oracle APEX** — Web-based farmer portal and admin panel
- **Oracle REST Data Services (ORDS)** — Auto-generate REST APIs from DB tables
- **Oracle Integration Cloud (OIC)** — Connect to external APIs (weather, Mandi prices, govt schemes)

### External APIs to Integrate via OIC
- **OpenWeatherMap API** — Live weather + 7-day forecast
- **IMD (India Meteorological Department) API** — Regional rainfall/drought alerts
- **Agmarknet API (data.gov.in)** — Real-time Mandi (market) prices across India
- **PM-KISAN / eNAM API** — Government scheme eligibility data
- **Fast2SMS or Twilio** — SMS delivery to farmers (vernacular language)

### Frontend
- **Oracle APEX** — Primary farmer-facing web app (responsive, works on low-end Android browsers)
- **React.js** (optional secondary) — Admin dashboard SPA
- **Language**: Hindi + English toggle on all screens

### Backend
- **Node.js (Express)** — REST API layer
- **Python** — ML model training (OCI Data Science notebooks)
- **PL/SQL** — Stored procedures, triggers, scheduled jobs inside Oracle ATP

---

## DATABASE DESIGN (Oracle Autonomous DB — ATP)

Design and implement the following schema with full constraints, indexes, and audit columns (`created_at`, `updated_at`, `created_by`):

### Tables

**1. FARMERS**
```
farmer_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
name             VARCHAR2(100) NOT NULL,
phone            VARCHAR2(15) UNIQUE NOT NULL,
aadhaar_hash     VARCHAR2(64),            -- SHA256 hash, never store raw
state            VARCHAR2(50),
district         VARCHAR2(50),
village          VARCHAR2(100),
land_acres       NUMBER(8,2),
soil_type        VARCHAR2(30),            -- Sandy / Loamy / Clay / Black
preferred_lang   VARCHAR2(10) DEFAULT 'hi',
is_active        CHAR(1) DEFAULT 'Y',
created_at       TIMESTAMP DEFAULT SYSTIMESTAMP
```

**2. CROPS**
```
crop_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
crop_name        VARCHAR2(100) NOT NULL,
crop_name_hindi  VARCHAR2(100),
category         VARCHAR2(50),            -- Kharif / Rabi / Zaid
avg_grow_days    NUMBER,
water_need_mm    NUMBER,
ideal_temp_min   NUMBER,
ideal_temp_max   NUMBER,
ideal_soil_types VARCHAR2(200)
```

**3. FARMER_CROPS** (what a farmer is currently growing)
```
farmer_crop_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
farmer_id        NUMBER REFERENCES FARMERS(farmer_id),
crop_id          NUMBER REFERENCES CROPS(crop_id),
sowing_date      DATE,
expected_harvest DATE,
plot_acres       NUMBER(6,2),
season           VARCHAR2(20),
status           VARCHAR2(20) DEFAULT 'ACTIVE'   -- ACTIVE / HARVESTED / FAILED
```

**4. DISEASE_SCANS**
```
scan_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
farmer_id        NUMBER REFERENCES FARMERS(farmer_id),
farmer_crop_id   NUMBER REFERENCES FARMER_CROPS(farmer_crop_id),
image_url        VARCHAR2(500),           -- OCI Object Storage URL
disease_detected VARCHAR2(200),
confidence_score NUMBER(5,2),
severity         VARCHAR2(20),            -- LOW / MEDIUM / HIGH / CRITICAL
treatment_advice CLOB,
treatment_hindi  CLOB,
scan_timestamp   TIMESTAMP DEFAULT SYSTIMESTAMP,
oci_vision_req   VARCHAR2(200)            -- OCI Vision API request ID
```

**5. WEATHER_DATA**
```
weather_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
district         VARCHAR2(50),
state            VARCHAR2(50),
recorded_at      TIMESTAMP,
temp_celsius     NUMBER(5,2),
humidity_pct     NUMBER(5,2),
rainfall_mm      NUMBER(7,2),
wind_speed_kmh   NUMBER(5,2),
forecast_json    CLOB,                    -- Raw 7-day JSON forecast
source           VARCHAR2(50)             -- OWM / IMD
```

**6. MANDI_PRICES**
```
price_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
crop_id          NUMBER REFERENCES CROPS(crop_id),
mandi_name       VARCHAR2(100),
district         VARCHAR2(50),
state            VARCHAR2(50),
price_per_qtl    NUMBER(10,2),
recorded_date    DATE,
source           VARCHAR2(50)
```

**7. ALERTS**
```
alert_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
alert_type       VARCHAR2(50),            -- DISEASE / WEATHER / PEST / PRICE_DROP / SCHEME
farmer_id        NUMBER REFERENCES FARMERS(farmer_id),
message_en       VARCHAR2(1000),
message_hi       VARCHAR2(1000),
severity         VARCHAR2(20),
is_sent          CHAR(1) DEFAULT 'N',
sent_at          TIMESTAMP,
channel          VARCHAR2(20)             -- SMS / EMAIL / APP
```

**8. GOVERNMENT_SCHEMES**
```
scheme_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
scheme_name      VARCHAR2(200),
scheme_name_hi   VARCHAR2(200),
ministry         VARCHAR2(100),
benefit_amount   NUMBER,
eligibility_json CLOB,                    -- JSON rules: land size, state, crop, income
apply_url        VARCHAR2(500),
deadline         DATE,
is_active        CHAR(1) DEFAULT 'Y'
```

**9. SCHEME_MATCHES**
```
match_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
farmer_id        NUMBER REFERENCES FARMERS(farmer_id),
scheme_id        NUMBER REFERENCES GOVERNMENT_SCHEMES(scheme_id),
match_score      NUMBER(5,2),
matched_at       TIMESTAMP DEFAULT SYSTIMESTAMP,
notified         CHAR(1) DEFAULT 'N'
```

**10. ML_PREDICTIONS**
```
prediction_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
farmer_crop_id   NUMBER REFERENCES FARMER_CROPS(farmer_crop_id),
model_type       VARCHAR2(50),            -- YIELD / PRICE / SOWING
predicted_value  NUMBER(12,2),
unit             VARCHAR2(30),
confidence_pct   NUMBER(5,2),
prediction_date  DATE,
model_version    VARCHAR2(20)
```

### PL/SQL Requirements
Write the following stored procedures and packages:

1. **PKG_FARMER** — CRUD operations for farmer registration and profile management
2. **PKG_ALERTS** — Procedure to generate alerts, batch-send SMS via OCI Notifications, update `is_sent`
3. **PKG_SCHEME_MATCHER** — Read all active schemes, evaluate each farmer's eligibility using JSON rules, insert into SCHEME_MATCHES
4. **PKG_PRICE_TRACKER** — Insert Mandi prices, detect >15% drop in 3 days, trigger price alert
5. **TRG_DISEASE_SCAN_ALERT** — Trigger on DISEASE_SCANS insert: if severity is HIGH or CRITICAL, auto-insert into ALERTS
6. **JOB_WEATHER_SYNC** — DBMS_SCHEDULER job to call OIC REST endpoint every 6 hours, load weather data
7. **JOB_SCHEME_MATCH_DAILY** — DBMS_SCHEDULER job to run PKG_SCHEME_MATCHER every night at 1 AM IST

---

## MODULE 1 — CROP DISEASE SCANNER (OCI Vision AI)

### Flow
```
Farmer uploads photo (APEX / Mobile)
        ↓
Image stored in OCI Object Storage (bucket: krishimitra-disease-scans)
        ↓
OCI Function triggered (Python) — calls OCI Vision AI Image Classification
        ↓
Vision AI returns: disease label + confidence score
        ↓
Python function calls OCI Language AI to translate treatment advice to Hindi
        ↓
Result stored in DISEASE_SCANS table via ORDS API
        ↓
If severity HIGH/CRITICAL → TRG_DISEASE_SCAN_ALERT fires → SMS sent to farmer
```

### Implementation Requirements

**OCI Function (Python) — `disease_classifier`**
- Trigger: OCI Object Storage event (new object in `disease-scans/` prefix)
- Input: image URL from Object Storage
- Call OCI Vision AI using `oci.ai_vision.AIServiceVisionClient`
- Map Vision AI labels to disease database (build a JSON lookup: label → disease name, severity, treatment)
- Call OCI Language AI `translate_text()` — source: English, target: Hindi
- POST result to ORDS endpoint `/ords/krishimitra/disease_scans/`
- Log everything to OCI Logging

**OCI Vision AI Model**
- Use OCI Vision custom model: train on PlantVillage dataset (38 disease classes)
- Dataset: 54,000+ labeled leaf images
- Upload training data to Object Storage, create labeling job in OCI Data Labeling
- Train model in OCI Vision — target accuracy: >90%
- Deploy as custom model endpoint

**APEX Page — Disease Scanner**
- Page title: "फसल रोग जांच" (Crop Disease Check)
- File upload component (accept: image/*)
- Show spinner while processing
- Result display: disease name (Hindi + English), severity badge (color-coded), treatment steps, confidence %
- "Share with Agriculture Officer" button — generates PDF report via OCI Functions

---

## MODULE 2 — SMART SOWING ADVISOR

### Flow
```
Farmer selects: state → district → available land acres → soil type → budget
        ↓
System fetches: 30-day weather forecast (OIC → OpenWeatherMap)
System fetches: last 3 seasons' yield data for that district (Oracle ATP)
System fetches: current Mandi price trends for top 5 crops
        ↓
OCI Data Science Model (Sowing Recommender) processes all inputs
        ↓
Output: Ranked list of Top 3 crops to sow with expected yield + expected revenue
        ↓
Store recommendation in ML_PREDICTIONS, show on APEX page
```

### OCI Data Science — Sowing Recommender Model
- **Algorithm**: Gradient Boosting (XGBoost) or LightGBM
- **Features**:
  - District average rainfall (historical 5 years)
  - Soil type (encoded)
  - Month of sowing
  - Current Mandi price trend (last 30 days)
  - Historical yield (district average, last 3 years)
  - Farmer's land size
- **Target**: Recommended crop + expected yield (qtl/acre)
- **Training data**: Combine ICRISAT dataset + Agmarknet historical + IMD historical
- **Deployment**: Deploy as OCI Data Science Model Deployment endpoint
- **Notebook**: Write complete Jupyter notebook with EDA, feature engineering, training, evaluation, SHAP explainability

### APEX Page — Sowing Advisor
- Page: "बुवाई सलाहकार" (Sowing Advisor)
- Input form: district (LOV from DB), soil type (radio), acres (number), budget range (slider)
- Output: Card-based layout — Crop 1, 2, 3 with:
  - Crop name (Hindi + English)
  - Expected yield (qtl/acre)
  - Estimated revenue (₹)
  - Water need
  - Sowing window (start date → end date)
  - Confidence % badge

---

## MODULE 3 — MARKET PRICE PREDICTOR

### OIC Integration — Agmarknet Price Feed
Build an Oracle Integration Cloud integration:
- **Trigger**: Schedule — every day at 6 AM IST
- **Source**: REST Adapter → Agmarknet API (`https://api.data.gov.in/resource/...`)
- **Filter**: Pull prices for top 20 crops across 50 major mandis
- **Transform**: Map API response to MANDI_PRICES table schema using OIC mapper
- **Target**: Oracle ATP Adapter → INSERT into MANDI_PRICES
- **Error handling**: Dead letter queue in OCI Streaming if insert fails

### OCI Data Science — Price Prediction Model
- **Algorithm**: LSTM (time-series) or Facebook Prophet
- **Input features**: historical price (365 days), seasonality, crop harvest calendar, weather events
- **Output**: Next 30-day price forecast per crop per mandi
- **Retraining**: Scheduled weekly via OCI Data Science Pipeline

### APEX Page — Price Intelligence
- Page: "बाजार भाव" (Market Prices)
- Tabs: Current Prices | Price Forecast | Price Alerts
- Current Prices: searchable table (crop, mandi, price, trend arrow)
- Price Forecast: Line chart (Oracle APEX Chart — JET Chart) — 30-day forecast vs historical
- Price Alerts: Farmer can set a "Sell Alert" — notify when price crosses a threshold

---

## MODULE 4 — EARLY WARNING ALERT SYSTEM

### OCI Streaming Pipeline
```
OIC pulls IMD / weather API → detects anomaly trigger conditions
        ↓
Publish event to OCI Stream: "krishimitra-alerts-stream"
        ↓
OCI Function (Consumer): reads stream → evaluates alert rule conditions
        ↓
Identifies affected farmers (by district) from FARMERS table
        ↓
Batch INSERT into ALERTS table
        ↓
PKG_ALERTS.SEND_BATCH() called → OCI Notifications → SMS via Fast2SMS API
```

### Alert Rule Engine (PL/SQL + Python)
Implement the following alert rules:

| Rule ID | Condition | Severity | Message |
|---------|-----------|----------|---------|
| WR-01 | Rainfall forecast > 200mm in next 48 hours | HIGH | Flood risk — protect crops |
| WR-02 | Temperature < 5°C for 3+ consecutive nights | MEDIUM | Frost risk — cover crops |
| WR-03 | No rainfall for 21+ days during Kharif | HIGH | Drought risk — irrigate |
| PR-01 | Mandi price drops >15% in 3 days | MEDIUM | Price alert — delay selling |
| PR-02 | Mandi price rises >20% in 7 days | LOW | Opportunity — sell now |
| DS-01 | Disease scan: severity CRITICAL | CRITICAL | Disease outbreak — consult officer |

### OCI Function — Alert Dispatcher
- Language: Python
- Reads from OCI Stream (cursor-based consumer group)
- Resolves affected farmers from ATP: `SELECT farmer_id, phone FROM FARMERS WHERE district = :district AND is_active = 'Y'`
- Composes message in Hindi using template + OCI Language AI (dynamic parts)
- Calls Fast2SMS API for bulk SMS (batch size: 1000 per API call)
- Updates ALERTS.is_sent = 'Y', sent_at = SYSTIMESTAMP

---

## MODULE 5 — GOVERNMENT SCHEME MATCHER

### Scheme Eligibility Engine (PL/SQL)
`PKG_SCHEME_MATCHER.MATCH_ALL_FARMERS` procedure:
- Reads all GOVERNMENT_SCHEMES where is_active = 'Y'
- For each scheme, parses `eligibility_json` (e.g., `{"min_land": 1, "max_land": 5, "states": ["UP", "MP"], "crops": ["wheat", "rice"]}`)
- Joins with FARMERS and FARMER_CROPS
- Calculates match_score (0–100) based on how many criteria the farmer meets
- Inserts/updates SCHEME_MATCHES
- Triggers ALERTS for new high-score matches (score > 80)

### OIC Integration — Scheme Data Sync
- Source: PM-KISAN API + eNAM API (data.gov.in)
- Schedule: Weekly on Sundays
- Transform: Map to GOVERNMENT_SCHEMES schema
- Auto-deactivate schemes past their deadline

### APEX Page — Scheme Finder
- Page: "सरकारी योजनाएँ" (Government Schemes)
- Personalized list: schemes sorted by match_score DESC
- Each card: scheme name, benefit amount, deadline, eligibility criteria met (checkmarks), Apply Now button
- Filter: by ministry, benefit type, deadline

---

## ORACLE APEX PORTAL STRUCTURE

Build the following APEX application (Application ID: 100):

### Pages
| Page # | Name (Hindi) | Name (English) | Description |
|--------|--------------|----------------|-------------|
| 1 | होम | Home | Dashboard with weather widget, active alerts, quick actions |
| 2 | फसल रोग जांच | Disease Scanner | Upload image, view result |
| 3 | बुवाई सलाहकार | Sowing Advisor | Form + crop recommendations |
| 4 | बाजार भाव | Market Prices | Price table + forecast chart |
| 5 | मेरी फसलें | My Crops | Manage farmer's crop records |
| 6 | सतर्कता | Alerts | Alert history + notification settings |
| 7 | सरकारी योजनाएँ | Govt Schemes | Personalized scheme list |
| 8 | मेरी प्रोफ़ाइल | My Profile | Farmer profile management |
| 100 | Admin | Admin | OAC-embedded analytics, user management |

### APEX Design Requirements
- Theme: Universal Theme with custom CSS
- Color Scheme: Green (#2D6A4F) primary, amber (#F4A261) accent — agriculture theme
- Font: Noto Sans Devanagari (Hindi), Noto Sans (English)
- Hindi/English toggle: stored in APEX session state, applied via CSS class on body
- Mobile-first: all pages must render well on 375px screen width
- Offline-capable homepage: use APEX PWA features (installable on Android)
- Accessibility: WCAG 2.1 AA compliant

---

## OCI ARCHITECTURE DIAGRAM

Implement this architecture (document it as an SVG/PNG diagram in your deliverable):

```
[ Farmer's Phone / Browser ]
          |
          v
[ OCI API Gateway ] ←── [ OCI WAF (Web Application Firewall) ]
          |
    ┌─────┴──────┐
    │             │
[ APEX/ORDS ]  [ Node.js API on OCI Compute ]
    │             │
    └─────┬───────┘
          |
[ Oracle ATP (Autonomous DB) ]
    |          |
[ ORDS ]   [ PL/SQL Packages & Triggers ]
          |
    ┌─────┴──────────────────────────────┐
    │             │            │          │
[ OCI Vision ] [ OCI DS ] [ OCI Lang ] [ OIC ]
  (Disease)   (ML Models) (Translate) (Integrations)
                                          │
                          ┌───────────────┼────────────────┐
                     [ Weather API ] [ Mandi API ] [ Scheme API ]
          |
[ OCI Streaming ] ──→ [ OCI Functions ] ──→ [ OCI Notifications ]
  (Event Bus)          (Alert Dispatcher)      (SMS / Email)
          |
[ OCI Object Storage ]
  (Images / Reports / Model Artifacts)
          |
[ Oracle Analytics Cloud ]
  (Admin Dashboard / BI)
```

---

## ORACLE INTEGRATION CLOUD (OIC) — INTEGRATION DESIGNS

Build the following 4 integrations in OIC:

### INT-01: Weather Sync
- Type: Scheduled
- Trigger: Every 6 hours
- Steps: REST Adapter (OpenWeatherMap) → JS Transform → Oracle ATP Adapter INSERT

### INT-02: Mandi Price Sync
- Type: Scheduled
- Trigger: Daily 6 AM IST
- Steps: REST Adapter (Agmarknet) → Mapper → For-Each loop → ATP INSERT → If error → OCI Streaming publish

### INT-03: Scheme Data Sync
- Type: Scheduled
- Trigger: Weekly Sunday 2 AM IST
- Steps: REST Adapter (data.gov.in) → Filter active schemes → Upsert ATP GOVERNMENT_SCHEMES

### INT-04: Farmer SMS Notification
- Type: Event-triggered (OCI Streaming consumer)
- Steps: Streaming Adapter (consume alert) → ATP SELECT farmer phone → REST Adapter (Fast2SMS POST) → ATP UPDATE alert sent

---

## ML MODEL PIPELINE (OCI Data Science)

### Project Setup
- Create OCI Data Science Project: `krishimitra-ml`
- Create Model Catalog with versioning
- Use Conda environment: `generalml_p38_cpu_v1`

### Model 1: Crop Disease Classifier
- Framework: TensorFlow 2.x / PyTorch
- Architecture: MobileNetV3 (lightweight for fast inference)
- Dataset: PlantVillage (38 classes, 54K images)
- Training: OCI Data Science Job (GPU shape: VM.GPU2.1)
- Evaluation: Accuracy, Precision, Recall, F1 per class
- Deployment: OCI Model Deployment (instance: VM.Standard.E4.Flex — 2 OCPU)

### Model 2: Crop Sowing Recommender
- Framework: Scikit-learn + XGBoost
- Features: 14 features (weather, soil, location, season, price trend)
- Target: Crop category + expected yield
- Training: OCI Data Science Notebook Session
- Evaluation: RMSE, R², cross-validation (5-fold)
- Deployment: OCI Model Deployment REST endpoint

### Model 3: Market Price Forecaster
- Framework: Prophet (Facebook) / statsmodels SARIMA
- Features: 365-day price history, seasonality flags, harvest calendar
- Target: 30-day price forecast per crop-mandi pair
- Retraining: OCI Data Science Pipeline (weekly)
- Deployment: Batch prediction job (results stored in ML_PREDICTIONS)

---

## SECURITY REQUIREMENTS

Implement all of the following:

1. **OCI IAM**: Create separate IAM groups — `krishimitra-developers`, `krishimitra-farmers`, `krishimitra-admins` with minimum privilege policies
2. **OCI Vault**: Store all API keys (OpenWeatherMap, Fast2SMS, Agmarknet) in OCI Vault secrets — never hardcode keys
3. **API Gateway**: OAuth 2.0 + JWT token validation on all endpoints
4. **Oracle ATP**: Always Encrypted (TDE enabled by default) + Private Endpoint (no public IP)
5. **Aadhaar data**: Only store SHA-256 hash of Aadhaar — never store raw number
6. **APEX**: Enable APEX session state protection, CSRF tokens on all forms
7. **OCI WAF**: Enable on API Gateway — block SQL injection, XSS
8. **Audit**: Enable Oracle Audit Vault on ATP — log all SELECT/INSERT/UPDATE on sensitive tables
9. **Network**: All OCI resources in private VCN subnets — public access only via Load Balancer + API Gateway
10. **GDPR/Data localisation**: All data in OCI India region (ap-hyderabad-1 or ap-mumbai-1)

---

## TESTING REQUIREMENTS

### Unit Tests
- PL/SQL: Use utPLSQL framework — write unit tests for all packages
- Python (OCI Functions): Use pytest — mock OCI SDK calls
- Node.js API: Use Jest + Supertest

### Integration Tests
- Test each OIC integration with sample payloads
- End-to-end test: upload disease image → receive SMS alert (use test farmer record)

### Performance Tests
- Simulate 10,000 concurrent farmer logins using Apache JMeter
- Disease scan API: p95 latency < 5 seconds
- APEX pages: page load < 2 seconds on 4G connection

### Test Data
- Create seed scripts: 1,000 dummy farmer records across 20 districts of UP, MP, Punjab
- 500 sample disease scan records with known outcomes
- 365 days of historical Mandi price data for 10 crops

---

## DEPLOYMENT & DEVOPS

### Infrastructure as Code
- Use **OCI Resource Manager** (Terraform) to provision all OCI resources
- Terraform modules: VCN, ATP, Object Storage, Functions, Streaming, API Gateway, APEX workspace
- State stored in OCI Object Storage backend

### CI/CD Pipeline
- **Source**: GitHub repository (`krishimitra-platform`)
- **Build**: OCI DevOps Build Pipeline
  - Stage 1: Run utPLSQL tests
  - Stage 2: Run pytest tests
  - Stage 3: Build Docker image for Node.js API
  - Stage 4: Push to OCI Container Registry
- **Deploy**: OCI DevOps Deployment Pipeline
  - Deploy to OCI Compute via rolling deployment
  - Deploy APEX app via SQLcl scripts
  - Deploy OCI Functions via `fn deploy`

### Environments
- **DEV**: OCI Always Free tier resources where possible
- **PROD**: Paid tier with auto-scaling, backups, monitoring

### Monitoring
- **OCI Monitoring**: Custom metrics for API latency, disease scan volume, alert delivery rate
- **OCI Alarms**: Alert DevOps team if ATP CPU > 80%, Function error rate > 5%
- **OCI Logging**: Centralised logging for all services
- **Oracle APEX**: Activity reports for page views, errors

---

## DELIVERABLES CHECKLIST

At the end of the project, you must produce:

- [ ] Complete OCI Terraform scripts (infrastructure as code)
- [ ] Oracle ATP schema scripts (DDL + seed data)
- [ ] All PL/SQL packages, triggers, and scheduler jobs
- [ ] 4 OCI Integration Cloud integration designs (exported as `.iar` files)
- [ ] 3 OCI Data Science Jupyter notebooks (one per ML model)
- [ ] OCI Function source code (Python) for disease classifier + alert dispatcher
- [ ] Node.js REST API source code
- [ ] Oracle APEX application export (`.sql`)
- [ ] OCI DevOps pipeline configuration
- [ ] Architecture diagram (draw.io / PNG)
- [ ] API documentation (OpenAPI 3.0 YAML)
- [ ] Test scripts (utPLSQL + pytest + JMeter plan)
- [ ] README with setup instructions (step-by-step)
- [ ] Demo video (5 minutes) showing all 5 modules working

---

## STEP-BY-STEP BUILD ORDER

Follow this exact sequence to avoid dependency issues:

1. Provision OCI infrastructure with Terraform (VCN, subnets, ATP, Object Storage, Streaming)
2. Create Oracle ATP schema (DDL scripts → seed data)
3. Write and test all PL/SQL packages
4. Set up ORDS and expose initial REST endpoints
5. Build OIC Integration INT-01 (Weather) and validate data in ATP
6. Build OIC Integration INT-02 (Mandi Prices) and validate
7. Set up OCI Vision AI custom model training (start early — training takes time)
8. Build OCI Function: `disease-classifier` (initially with stock model, swap custom later)
9. Build Oracle APEX application skeleton (all pages, navigation, authentication)
10. Integrate Disease Scanner page end-to-end (APEX → Object Storage → Function → ATP)
11. Build OCI Data Science notebooks — train and deploy sowing recommender
12. Integrate Sowing Advisor page with Model Deployment endpoint
13. Build Price Forecaster model and integrate Market Prices page
14. Build OCI Streaming pipeline + Alert Dispatcher Function + SMS notifications
15. Build OIC INT-03 (Scheme Sync) + PKG_SCHEME_MATCHER + Scheme Finder page
16. Implement OCI DevOps CI/CD pipeline
17. Performance testing + security hardening
18. Final integration testing end-to-end
19. Documentation + demo video

---

## IMPORTANT CONSTRAINTS

- Every Oracle service used must be justified in your architecture document — no over-engineering
- All user-facing text must be available in both Hindi and English
- The solution must work on a 4G mobile connection with 500ms latency (design for low-bandwidth)
- OCI Always Free tier must be maximally used in DEV environment
- No external ML frameworks that cannot run on OCI — use OCI AI Services or OCI Data Science
- All secrets go through OCI Vault — zero hardcoded credentials anywhere
- The platform must handle 100,000 registered farmers at MVP without architectural changes

---

*This is the complete master specification for KrishiMitra. Build each module end-to-end before moving to the next. Ask for clarification on any ambiguous requirement before building.*
