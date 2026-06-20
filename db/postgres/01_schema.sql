-- =============================================================================
-- KrishiMitra :: PostgreSQL (Supabase) :: Core Schema DDL
-- File: db/postgres/01_schema.sql   (run order: 1 of 4)
--
-- PostgreSQL port of the original Oracle schema (db/ddl/01_tables.sql).
--   * identity PKs      -> bigint GENERATED ALWAYS AS IDENTITY
--   * CLOB              -> text
--   * forecast/eligibility JSON -> jsonb (native; no IS JSON check needed)
--   * CHAR(1) Y/N flags -> char(1) with CHECK (kept for parity with the app)
--   * audit columns maintained by triggers (see 03_triggers.sql)
--
-- Safe to re-run: tables are dropped first in reverse-dependency order.
-- =============================================================================

DROP TABLE IF EXISTS ml_predictions   CASCADE;
DROP TABLE IF EXISTS scheme_matches    CASCADE;
DROP TABLE IF EXISTS government_schemes CASCADE;
DROP TABLE IF EXISTS alerts            CASCADE;
DROP TABLE IF EXISTS mandi_prices      CASCADE;
DROP TABLE IF EXISTS weather_data      CASCADE;
DROP TABLE IF EXISTS disease_scans     CASCADE;
DROP TABLE IF EXISTS farmer_crops      CASCADE;
DROP TABLE IF EXISTS crops             CASCADE;
DROP TABLE IF EXISTS farmers           CASCADE;

-- -----------------------------------------------------------------------------
-- 1. FARMERS
-- -----------------------------------------------------------------------------
CREATE TABLE farmers (
    farmer_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             varchar(100)  NOT NULL,
    phone            varchar(15)   NOT NULL,
    email            varchar(150),                    -- alert delivery via email
    aadhaar_hash     varchar(64),                     -- SHA-256 hash only, never raw
    state            varchar(50),
    district         varchar(50),
    village          varchar(100),
    land_acres       numeric(8,2),
    soil_type        varchar(30),
    preferred_lang   varchar(10)   DEFAULT 'hi',
    is_active        char(1)       DEFAULT 'Y',
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT uq_farmers_phone     UNIQUE (phone),
    CONSTRAINT ck_farmers_lang      CHECK (preferred_lang IN ('hi', 'en')),
    CONSTRAINT ck_farmers_is_active CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT ck_farmers_soil_type CHECK (soil_type IS NULL OR soil_type IN
        ('Sandy', 'Loamy', 'Clay', 'Black', 'Silt', 'Peaty', 'Chalky')),
    CONSTRAINT ck_farmers_land_acres CHECK (land_acres IS NULL OR land_acres >= 0)
);
COMMENT ON TABLE farmers IS 'Registered farmers. Aadhaar stored only as SHA-256 hash.';

-- -----------------------------------------------------------------------------
-- 2. CROPS (master/reference data)
-- -----------------------------------------------------------------------------
CREATE TABLE crops (
    crop_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    crop_name        varchar(100)  NOT NULL,
    crop_name_hindi  varchar(100),
    category         varchar(50),                     -- Kharif / Rabi / Zaid
    avg_grow_days    integer,
    water_need_mm    integer,
    ideal_temp_min   integer,
    ideal_temp_max   integer,
    ideal_soil_types varchar(200),
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT uq_crops_name       UNIQUE (crop_name),
    CONSTRAINT ck_crops_category   CHECK (category IS NULL OR category IN ('Kharif', 'Rabi', 'Zaid')),
    CONSTRAINT ck_crops_grow_days  CHECK (avg_grow_days IS NULL OR avg_grow_days > 0),
    CONSTRAINT ck_crops_temp_range CHECK (ideal_temp_min IS NULL OR ideal_temp_max IS NULL OR ideal_temp_min <= ideal_temp_max)
);
COMMENT ON TABLE crops IS 'Crop master reference: agronomic parameters and bilingual names.';

-- -----------------------------------------------------------------------------
-- 3. FARMER_CROPS (what a farmer is currently growing)
-- -----------------------------------------------------------------------------
CREATE TABLE farmer_crops (
    farmer_crop_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_id        bigint        NOT NULL REFERENCES farmers (farmer_id),
    crop_id          bigint        NOT NULL REFERENCES crops (crop_id),
    sowing_date      date,
    expected_harvest date,
    plot_acres       numeric(6,2),
    season           varchar(20),
    status           varchar(20)   DEFAULT 'ACTIVE',
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT ck_fc_status     CHECK (status IN ('ACTIVE', 'HARVESTED', 'FAILED')),
    CONSTRAINT ck_fc_plot_acres CHECK (plot_acres IS NULL OR plot_acres >= 0),
    CONSTRAINT ck_fc_dates      CHECK (sowing_date IS NULL OR expected_harvest IS NULL OR sowing_date <= expected_harvest)
);
COMMENT ON TABLE farmer_crops IS 'Active and historical crop plantings per farmer.';

-- -----------------------------------------------------------------------------
-- 4. DISEASE_SCANS
-- -----------------------------------------------------------------------------
CREATE TABLE disease_scans (
    scan_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_id        bigint        NOT NULL REFERENCES farmers (farmer_id),
    farmer_crop_id   bigint        REFERENCES farmer_crops (farmer_crop_id),
    image_url        varchar(500),                    -- Supabase Storage URL
    disease_detected varchar(200),
    confidence_score numeric(5,2),
    severity         varchar(20),                     -- LOW / MEDIUM / HIGH / CRITICAL
    treatment_advice text,
    treatment_hindi  text,
    scan_timestamp   timestamptz   DEFAULT now() NOT NULL,
    oci_vision_req   varchar(200),                    -- legacy column (request id / model tag)
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT ck_ds_severity   CHECK (severity IS NULL OR severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_ds_confidence CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 100))
);
COMMENT ON TABLE disease_scans IS 'Crop disease scan results produced by the in-Node ONNX classifier.';

-- -----------------------------------------------------------------------------
-- 5. WEATHER_DATA
-- -----------------------------------------------------------------------------
CREATE TABLE weather_data (
    weather_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    district         varchar(50),
    state            varchar(50),
    recorded_at      timestamptz,
    temp_celsius     numeric(5,2),
    humidity_pct     numeric(5,2),
    rainfall_mm      numeric(7,2),
    wind_speed_kmh   numeric(5,2),
    forecast_json    jsonb,                           -- raw 7-day forecast
    source           varchar(50),                     -- OWM (Open-Meteo) / IMD
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT ck_wd_source   CHECK (source IS NULL OR source IN ('OWM', 'IMD')),
    CONSTRAINT ck_wd_humidity CHECK (humidity_pct IS NULL OR (humidity_pct >= 0 AND humidity_pct <= 100))
);
COMMENT ON TABLE weather_data IS 'District-level weather observations and forecasts (Open-Meteo).';

-- -----------------------------------------------------------------------------
-- 6. MANDI_PRICES
-- -----------------------------------------------------------------------------
CREATE TABLE mandi_prices (
    price_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    crop_id          bigint        NOT NULL REFERENCES crops (crop_id),
    mandi_name       varchar(100),
    district         varchar(50),
    state            varchar(50),
    price_per_qtl    numeric(10,2),
    recorded_date    date,
    source           varchar(50),
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT ck_mp_price CHECK (price_per_qtl IS NULL OR price_per_qtl >= 0)
);
COMMENT ON TABLE mandi_prices IS 'Daily Mandi (market) prices per crop-mandi (Agmarknet / data.gov.in).';

-- -----------------------------------------------------------------------------
-- 7. ALERTS
-- -----------------------------------------------------------------------------
CREATE TABLE alerts (
    alert_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_type       varchar(50),                     -- DISEASE / WEATHER / PEST / PRICE_* / SCHEME
    farmer_id        bigint        REFERENCES farmers (farmer_id),
    message_en       varchar(1000),
    message_hi       varchar(1000),
    severity         varchar(20),
    is_sent          char(1)       DEFAULT 'N',
    sent_at          timestamptz,
    channel          varchar(20),                     -- SMS / EMAIL / APP / WHATSAPP
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT ck_al_type     CHECK (alert_type IN ('DISEASE', 'WEATHER', 'PEST', 'PRICE_DROP', 'PRICE_RISE', 'SCHEME', 'ADMIN')),
    CONSTRAINT ck_al_severity CHECK (severity IS NULL OR severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT ck_al_is_sent  CHECK (is_sent IN ('Y', 'N')),
    CONSTRAINT ck_al_channel  CHECK (channel IS NULL OR channel IN ('SMS', 'EMAIL', 'APP', 'WHATSAPP'))
);
COMMENT ON TABLE alerts IS 'Outbound farmer alerts; dispatched (email + in-app) by the alerts service.';

-- -----------------------------------------------------------------------------
-- 8. GOVERNMENT_SCHEMES
-- -----------------------------------------------------------------------------
CREATE TABLE government_schemes (
    scheme_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scheme_name      varchar(200),
    scheme_name_hi   varchar(200),
    ministry         varchar(100),
    benefit_amount   numeric,
    eligibility_json jsonb,                           -- rules: land size, state, crop, income
    apply_url        varchar(500),
    deadline         date,
    is_active        char(1)       DEFAULT 'Y',
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT uq_gs_scheme_name UNIQUE (scheme_name),
    CONSTRAINT ck_gs_is_active CHECK (is_active IN ('Y', 'N'))
);
COMMENT ON TABLE government_schemes IS 'Government schemes with JSON eligibility rules.';

-- -----------------------------------------------------------------------------
-- 9. SCHEME_MATCHES
-- -----------------------------------------------------------------------------
CREATE TABLE scheme_matches (
    match_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_id        bigint        NOT NULL REFERENCES farmers (farmer_id),
    scheme_id        bigint        NOT NULL REFERENCES government_schemes (scheme_id),
    match_score      numeric(5,2),
    matched_at       timestamptz   DEFAULT now() NOT NULL,
    notified         char(1)       DEFAULT 'N',
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT uq_sm_farmer_scheme UNIQUE (farmer_id, scheme_id),
    CONSTRAINT ck_sm_notified  CHECK (notified IN ('Y', 'N')),
    CONSTRAINT ck_sm_score     CHECK (match_score IS NULL OR (match_score >= 0 AND match_score <= 100))
);
COMMENT ON TABLE scheme_matches IS 'Farmer-to-scheme eligibility matches produced by the scheme matcher.';

-- -----------------------------------------------------------------------------
-- 10. ML_PREDICTIONS
-- -----------------------------------------------------------------------------
CREATE TABLE ml_predictions (
    prediction_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    farmer_crop_id   bigint        REFERENCES farmer_crops (farmer_crop_id),
    model_type       varchar(50),                     -- YIELD / PRICE / SOWING
    predicted_value  numeric(12,2),
    unit             varchar(30),
    confidence_pct   numeric(5,2),
    prediction_date  date,
    model_version    varchar(20),
    created_at       timestamptz   DEFAULT now() NOT NULL,
    updated_at       timestamptz   DEFAULT now() NOT NULL,
    created_by       varchar(100)  DEFAULT current_user,
    CONSTRAINT ck_ml_model_type CHECK (model_type IS NULL OR model_type IN ('YIELD', 'PRICE', 'SOWING')),
    CONSTRAINT ck_ml_confidence CHECK (confidence_pct IS NULL OR (confidence_pct >= 0 AND confidence_pct <= 100))
);
COMMENT ON TABLE ml_predictions IS 'Outputs from the ML models (yield/price/sowing).';
