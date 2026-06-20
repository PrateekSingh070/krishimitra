-- =============================================================================
-- KrishiMitra :: Oracle Autonomous DB (ATP) :: Core Schema DDL
-- File: 01_tables.sql
-- Run order: 1 of 3 (tables) -> 02_indexes.sql -> 03_audit_triggers.sql
--
-- All tables use:
--   * NUMBER GENERATED ALWAYS AS IDENTITY surrogate primary keys
--   * Audit columns: created_at, updated_at, created_by (maintained by triggers)
--   * CHECK constraints on enum-like columns
-- Idempotent drops are intentionally omitted; run against a clean schema or use
-- the deploy script which handles ordering. Drop in reverse dependency order if
-- you need to re-run.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FARMERS
-- -----------------------------------------------------------------------------
CREATE TABLE farmers (
    farmer_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             VARCHAR2(100)  NOT NULL,
    phone            VARCHAR2(15)   NOT NULL,
    email            VARCHAR2(150),                   -- free path: alert delivery via email
    aadhaar_hash     VARCHAR2(64),                    -- SHA-256 hash only, never raw
    state            VARCHAR2(50),
    district         VARCHAR2(50),
    village          VARCHAR2(100),
    land_acres       NUMBER(8,2),
    soil_type        VARCHAR2(30),
    preferred_lang   VARCHAR2(10)   DEFAULT 'hi',
    is_active        CHAR(1)        DEFAULT 'Y',
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT uq_farmers_phone        UNIQUE (phone),
    CONSTRAINT ck_farmers_lang         CHECK (preferred_lang IN ('hi', 'en')),
    CONSTRAINT ck_farmers_is_active    CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT ck_farmers_soil_type    CHECK (soil_type IN ('Sandy', 'Loamy', 'Clay', 'Black', 'Silt', 'Peaty', 'Chalky')),
    CONSTRAINT ck_farmers_land_acres   CHECK (land_acres >= 0)
);

COMMENT ON TABLE  farmers              IS 'Registered farmers. Aadhaar stored only as SHA-256 hash.';
COMMENT ON COLUMN farmers.aadhaar_hash IS 'SHA-256 hash of Aadhaar number. Raw number is never persisted.';
COMMENT ON COLUMN farmers.soil_type    IS 'Sandy / Loamy / Clay / Black / Silt / Peaty / Chalky';

-- -----------------------------------------------------------------------------
-- 2. CROPS (master/reference data)
-- -----------------------------------------------------------------------------
CREATE TABLE crops (
    crop_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    crop_name        VARCHAR2(100)  NOT NULL,
    crop_name_hindi  VARCHAR2(100),
    category         VARCHAR2(50),                    -- Kharif / Rabi / Zaid
    avg_grow_days    NUMBER,
    water_need_mm    NUMBER,
    ideal_temp_min   NUMBER,
    ideal_temp_max   NUMBER,
    ideal_soil_types VARCHAR2(200),
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT uq_crops_name        UNIQUE (crop_name),
    CONSTRAINT ck_crops_category    CHECK (category IN ('Kharif', 'Rabi', 'Zaid')),
    CONSTRAINT ck_crops_grow_days   CHECK (avg_grow_days IS NULL OR avg_grow_days > 0),
    CONSTRAINT ck_crops_temp_range  CHECK (ideal_temp_min IS NULL OR ideal_temp_max IS NULL OR ideal_temp_min <= ideal_temp_max)
);

COMMENT ON TABLE crops IS 'Crop master reference: agronomic parameters and bilingual names.';

-- -----------------------------------------------------------------------------
-- 3. FARMER_CROPS (what a farmer is currently growing)
-- -----------------------------------------------------------------------------
CREATE TABLE farmer_crops (
    farmer_crop_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_id        NUMBER         NOT NULL,
    crop_id          NUMBER         NOT NULL,
    sowing_date      DATE,
    expected_harvest DATE,
    plot_acres       NUMBER(6,2),
    season           VARCHAR2(20),
    status           VARCHAR2(20)   DEFAULT 'ACTIVE',
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT fk_fc_farmer      FOREIGN KEY (farmer_id) REFERENCES farmers (farmer_id),
    CONSTRAINT fk_fc_crop        FOREIGN KEY (crop_id)   REFERENCES crops (crop_id),
    CONSTRAINT ck_fc_status      CHECK (status IN ('ACTIVE', 'HARVESTED', 'FAILED')),
    CONSTRAINT ck_fc_plot_acres  CHECK (plot_acres IS NULL OR plot_acres >= 0),
    CONSTRAINT ck_fc_dates       CHECK (sowing_date IS NULL OR expected_harvest IS NULL OR sowing_date <= expected_harvest)
);

COMMENT ON TABLE farmer_crops IS 'Active and historical crop plantings per farmer.';

-- -----------------------------------------------------------------------------
-- 4. DISEASE_SCANS
-- -----------------------------------------------------------------------------
CREATE TABLE disease_scans (
    scan_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_id        NUMBER         NOT NULL,
    farmer_crop_id   NUMBER,
    image_url        VARCHAR2(500),                   -- OCI Object Storage URL
    disease_detected VARCHAR2(200),
    confidence_score NUMBER(5,2),
    severity         VARCHAR2(20),                    -- LOW / MEDIUM / HIGH / CRITICAL
    treatment_advice CLOB,
    treatment_hindi  CLOB,
    scan_timestamp   TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    oci_vision_req   VARCHAR2(200),                   -- OCI Vision API request ID
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT fk_ds_farmer       FOREIGN KEY (farmer_id)      REFERENCES farmers (farmer_id),
    CONSTRAINT fk_ds_farmer_crop  FOREIGN KEY (farmer_crop_id) REFERENCES farmer_crops (farmer_crop_id),
    CONSTRAINT ck_ds_severity     CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_ds_confidence   CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 100))
);

COMMENT ON TABLE disease_scans IS 'Crop disease scan results produced by the OCI Vision AI classifier Function.';

-- -----------------------------------------------------------------------------
-- 5. WEATHER_DATA
-- -----------------------------------------------------------------------------
CREATE TABLE weather_data (
    weather_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    district         VARCHAR2(50),
    state            VARCHAR2(50),
    recorded_at      TIMESTAMP,
    temp_celsius     NUMBER(5,2),
    humidity_pct     NUMBER(5,2),
    rainfall_mm      NUMBER(7,2),
    wind_speed_kmh   NUMBER(5,2),
    forecast_json    CLOB,                            -- Raw 7-day JSON forecast
    source           VARCHAR2(50),                    -- OWM / IMD
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT ck_wd_source      CHECK (source IN ('OWM', 'IMD')),
    CONSTRAINT ck_wd_humidity    CHECK (humidity_pct IS NULL OR (humidity_pct >= 0 AND humidity_pct <= 100)),
    CONSTRAINT ck_wd_forecast_json CHECK (forecast_json IS NULL OR forecast_json IS JSON)
);

COMMENT ON TABLE weather_data IS 'District-level weather observations and forecasts (OIC INT-01).';

-- -----------------------------------------------------------------------------
-- 6. MANDI_PRICES
-- -----------------------------------------------------------------------------
CREATE TABLE mandi_prices (
    price_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    crop_id          NUMBER         NOT NULL,
    mandi_name       VARCHAR2(100),
    district         VARCHAR2(50),
    state            VARCHAR2(50),
    price_per_qtl    NUMBER(10,2),
    recorded_date    DATE,
    source           VARCHAR2(50),
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT fk_mp_crop        FOREIGN KEY (crop_id) REFERENCES crops (crop_id),
    CONSTRAINT ck_mp_price       CHECK (price_per_qtl IS NULL OR price_per_qtl >= 0)
);

COMMENT ON TABLE mandi_prices IS 'Daily Mandi (market) prices per crop-mandi (OIC INT-02 / Agmarknet).';

-- -----------------------------------------------------------------------------
-- 7. ALERTS
-- -----------------------------------------------------------------------------
CREATE TABLE alerts (
    alert_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_type       VARCHAR2(50),                    -- DISEASE / WEATHER / PEST / PRICE_DROP / SCHEME
    farmer_id        NUMBER,
    message_en       VARCHAR2(1000),
    message_hi       VARCHAR2(1000),
    severity         VARCHAR2(20),
    is_sent          CHAR(1)        DEFAULT 'N',
    sent_at          TIMESTAMP,
    channel          VARCHAR2(20),                    -- SMS / EMAIL / APP
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT fk_al_farmer      FOREIGN KEY (farmer_id) REFERENCES farmers (farmer_id),
    CONSTRAINT ck_al_type        CHECK (alert_type IN ('DISEASE', 'WEATHER', 'PEST', 'PRICE_DROP', 'PRICE_RISE', 'SCHEME')),
    CONSTRAINT ck_al_severity    CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_al_is_sent     CHECK (is_sent IN ('Y', 'N')),
    CONSTRAINT ck_al_channel     CHECK (channel IN ('SMS', 'EMAIL', 'APP'))
);

COMMENT ON TABLE alerts IS 'Outbound farmer alerts across all channels; dispatched by PKG_ALERTS.';

-- -----------------------------------------------------------------------------
-- 8. GOVERNMENT_SCHEMES
-- -----------------------------------------------------------------------------
CREATE TABLE government_schemes (
    scheme_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scheme_name      VARCHAR2(200),
    scheme_name_hi   VARCHAR2(200),
    ministry         VARCHAR2(100),
    benefit_amount   NUMBER,
    eligibility_json CLOB,                            -- JSON rules: land size, state, crop, income
    apply_url        VARCHAR2(500),
    deadline         DATE,
    is_active        CHAR(1)        DEFAULT 'Y',
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT ck_gs_is_active   CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT ck_gs_elig_json   CHECK (eligibility_json IS NULL OR eligibility_json IS JSON)
);

COMMENT ON TABLE government_schemes IS 'Government schemes with JSON eligibility rules (OIC INT-03).';

-- -----------------------------------------------------------------------------
-- 9. SCHEME_MATCHES
-- -----------------------------------------------------------------------------
CREATE TABLE scheme_matches (
    match_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_id        NUMBER         NOT NULL,
    scheme_id        NUMBER         NOT NULL,
    match_score      NUMBER(5,2),
    matched_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    notified         CHAR(1)        DEFAULT 'N',
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT fk_sm_farmer      FOREIGN KEY (farmer_id) REFERENCES farmers (farmer_id),
    CONSTRAINT fk_sm_scheme      FOREIGN KEY (scheme_id) REFERENCES government_schemes (scheme_id),
    CONSTRAINT uq_sm_farmer_scheme UNIQUE (farmer_id, scheme_id),
    CONSTRAINT ck_sm_notified    CHECK (notified IN ('Y', 'N')),
    CONSTRAINT ck_sm_score       CHECK (match_score IS NULL OR (match_score >= 0 AND match_score <= 100))
);

COMMENT ON TABLE scheme_matches IS 'Farmer-to-scheme eligibility matches produced by PKG_SCHEME_MATCHER.';

-- -----------------------------------------------------------------------------
-- 10. ML_PREDICTIONS
-- -----------------------------------------------------------------------------
CREATE TABLE ml_predictions (
    prediction_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_crop_id   NUMBER,
    model_type       VARCHAR2(50),                    -- YIELD / PRICE / SOWING
    predicted_value  NUMBER(12,2),
    unit             VARCHAR2(30),
    confidence_pct   NUMBER(5,2),
    prediction_date  DATE,
    model_version    VARCHAR2(20),
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    created_by       VARCHAR2(100)  DEFAULT USER,
    CONSTRAINT fk_ml_farmer_crop FOREIGN KEY (farmer_crop_id) REFERENCES farmer_crops (farmer_crop_id),
    CONSTRAINT ck_ml_model_type  CHECK (model_type IN ('YIELD', 'PRICE', 'SOWING')),
    CONSTRAINT ck_ml_confidence  CHECK (confidence_pct IS NULL OR (confidence_pct >= 0 AND confidence_pct <= 100))
);

COMMENT ON TABLE ml_predictions IS 'Outputs from OCI Data Science model deployments (yield/price/sowing).';
