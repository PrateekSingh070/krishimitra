-- =============================================================================
-- KrishiMitra :: Indexes
-- File: 02_indexes.sql
-- Run order: 2 of 3
--
-- Identity PKs and UNIQUE constraints already create supporting indexes.
-- The indexes below cover foreign keys (to avoid locking / full scans on
-- parent DML) and the hot query paths used by the API, PL/SQL packages,
-- and APEX pages.
-- =============================================================================

-- FARMER_CROPS foreign keys
CREATE INDEX ix_fc_farmer        ON farmer_crops (farmer_id);
CREATE INDEX ix_fc_crop          ON farmer_crops (crop_id);
CREATE INDEX ix_fc_status        ON farmer_crops (status);

-- DISEASE_SCANS foreign keys + recency lookups
CREATE INDEX ix_ds_farmer        ON disease_scans (farmer_id);
CREATE INDEX ix_ds_farmer_crop   ON disease_scans (farmer_crop_id);
CREATE INDEX ix_ds_severity_ts   ON disease_scans (severity, scan_timestamp);

-- WEATHER_DATA: alert rule lookups by district + recency
CREATE INDEX ix_wd_district_time ON weather_data (district, recorded_at);

-- MANDI_PRICES: price-tracker window queries (>15% drop in 3 days, etc.)
CREATE INDEX ix_mp_crop_date     ON mandi_prices (crop_id, recorded_date);
CREATE INDEX ix_mp_mandi_date    ON mandi_prices (mandi_name, recorded_date);

-- ALERTS: dispatch worker scans for unsent rows; farmer history lookups
CREATE INDEX ix_al_is_sent       ON alerts (is_sent);
CREATE INDEX ix_al_farmer        ON alerts (farmer_id);
CREATE INDEX ix_al_type_sev      ON alerts (alert_type, severity);

-- FARMERS: alert dispatcher resolves affected farmers by district
CREATE INDEX ix_farmers_district ON farmers (district, is_active);
CREATE INDEX ix_farmers_state    ON farmers (state);

-- SCHEME_MATCHES foreign keys + ranked listing
CREATE INDEX ix_sm_farmer_score  ON scheme_matches (farmer_id, match_score);
CREATE INDEX ix_sm_scheme        ON scheme_matches (scheme_id);

-- ML_PREDICTIONS
CREATE INDEX ix_ml_farmer_crop   ON ml_predictions (farmer_crop_id);
CREATE INDEX ix_ml_type_date     ON ml_predictions (model_type, prediction_date);

-- GOVERNMENT_SCHEMES: matcher reads active, non-expired schemes
CREATE INDEX ix_gs_active_deadline ON government_schemes (is_active, deadline);
