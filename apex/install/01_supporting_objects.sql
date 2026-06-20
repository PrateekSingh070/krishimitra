-- =============================================================================
-- KrishiMitra :: APEX supporting database objects
-- Views, LOVs, and a bilingual messages table that the APEX pages bind to.
-- Run as the KRISHIMITRA schema owner AFTER db/deploy.sql.
-- Keeping page SQL in views (rather than inline in the app export) makes the
-- app portable and the SQL reviewable in source control.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Bilingual UI messages (Hindi/English toggle reads from here via APEX_LANG or
-- a simple lookup). Page labels also live here so non-developers can edit them.
-- ---------------------------------------------------------------------------
-- Portable "create if absent": ignore ORA-00955 (name already used).
BEGIN
    EXECUTE IMMEDIATE q'[
        CREATE TABLE ui_messages (
            msg_key   VARCHAR2(100) PRIMARY KEY,
            text_en   VARCHAR2(400) NOT NULL,
            text_hi   VARCHAR2(400) NOT NULL
        )]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN RAISE; END IF;
END;
/

MERGE INTO ui_messages t
USING (
    SELECT 'NAV_HOME'      k, 'Home'              en, 'होम'              hi FROM dual UNION ALL
    SELECT 'NAV_DISEASE',     'Disease Scanner',     'फसल रोग जांच'      FROM dual UNION ALL
    SELECT 'NAV_SOWING',      'Sowing Advisor',      'बुवाई सलाहकार'     FROM dual UNION ALL
    SELECT 'NAV_PRICES',      'Market Prices',       'बाजार भाव'         FROM dual UNION ALL
    SELECT 'NAV_MYCROPS',     'My Crops',            'मेरी फसलें'        FROM dual UNION ALL
    SELECT 'NAV_ALERTS',      'Alerts',              'सतर्कता'           FROM dual UNION ALL
    SELECT 'NAV_SCHEMES',     'Govt Schemes',        'सरकारी योजनाएँ'    FROM dual UNION ALL
    SELECT 'NAV_PROFILE',     'My Profile',          'मेरी प्रोफ़ाइल'    FROM dual UNION ALL
    SELECT 'BTN_SCAN',        'Scan',                'जांच करें'         FROM dual UNION ALL
    SELECT 'BTN_SHARE',       'Share with Officer',  'अधिकारी को भेजें'  FROM dual UNION ALL
    SELECT 'LBL_CONFIDENCE',  'Confidence',          'विश्वास'           FROM dual UNION ALL
    SELECT 'LBL_SEVERITY',    'Severity',            'गंभीरता'           FROM dual
) s
ON (t.msg_key = s.k)
WHEN MATCHED THEN UPDATE SET t.text_en = s.en, t.text_hi = s.hi
WHEN NOT MATCHED THEN INSERT (msg_key, text_en, text_hi) VALUES (s.k, s.en, s.hi);
COMMIT;

-- ---------------------------------------------------------------------------
-- Page 1 (Home): dashboard widgets
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_home_active_alerts AS
SELECT a.alert_id, a.farmer_id, a.alert_type, a.severity,
       a.message_en, a.message_hi, a.created_at
FROM   alerts a
WHERE  a.created_at >= SYSTIMESTAMP - INTERVAL '7' DAY
ORDER  BY CASE a.severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                          WHEN 'MEDIUM' THEN 3 ELSE 4 END,
          a.created_at DESC;

CREATE OR REPLACE VIEW vw_home_weather AS
SELECT w.district, w.state, w.temp_celsius, w.humidity_pct, w.rainfall_mm,
       w.wind_speed_kmh, w.recorded_at
FROM   weather_data w
WHERE  w.recorded_at = (SELECT MAX(w2.recorded_at) FROM weather_data w2
                        WHERE w2.district = w.district);

-- ---------------------------------------------------------------------------
-- Page 2 (Disease Scanner): scan history per farmer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_disease_scans AS
SELECT ds.scan_id, ds.farmer_id, ds.farmer_crop_id, ds.image_url,
       ds.disease_detected, ds.confidence_score, ds.severity,
       ds.treatment_advice, ds.treatment_hindi, ds.scan_timestamp,
       c.crop_name, c.crop_name_hindi
FROM   disease_scans ds
LEFT   JOIN farmer_crops fc ON fc.farmer_crop_id = ds.farmer_crop_id
LEFT   JOIN crops c ON c.crop_id = fc.crop_id;

-- ---------------------------------------------------------------------------
-- Page 4 (Market Prices): latest + history (chart source)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_latest_mandi_prices AS
SELECT mp.price_id, mp.crop_id, c.crop_name, c.crop_name_hindi,
       mp.mandi_name, mp.district, mp.state, mp.price_per_qtl, mp.recorded_date
FROM   mandi_prices mp
JOIN   crops c ON c.crop_id = mp.crop_id
WHERE  mp.recorded_date = (SELECT MAX(mp2.recorded_date) FROM mandi_prices mp2
                           WHERE mp2.crop_id = mp.crop_id
                           AND   mp2.mandi_name = mp.mandi_name);

CREATE OR REPLACE VIEW vw_mandi_price_forecast AS
SELECT p.farmer_crop_id, p.predicted_value AS price_per_qtl, p.unit,
       p.confidence_pct, p.prediction_date, p.model_version
FROM   ml_predictions p
WHERE  p.model_type = 'PRICE';

-- ---------------------------------------------------------------------------
-- Page 5 (My Crops): farmer crop records with crop names
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_my_crops AS
SELECT fc.farmer_crop_id, fc.farmer_id, fc.crop_id, c.crop_name, c.crop_name_hindi,
       fc.sowing_date, fc.expected_harvest, fc.plot_acres, fc.season, fc.status
FROM   farmer_crops fc
JOIN   crops c ON c.crop_id = fc.crop_id;

-- ---------------------------------------------------------------------------
-- Page 7 (Govt Schemes): personalised, ranked matches
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_scheme_matches AS
SELECT sm.farmer_id, gs.scheme_id, gs.scheme_name, gs.scheme_name_hi, gs.ministry,
       gs.benefit_amount, gs.apply_url, gs.deadline, sm.match_score
FROM   scheme_matches sm
JOIN   government_schemes gs ON gs.scheme_id = sm.scheme_id
WHERE  gs.is_active = 'Y';

-- ---------------------------------------------------------------------------
-- Page 100 (Admin Dashboard): analytics views [FREE PATH]
-- These replace the paid Oracle Analytics Cloud (OAC) iframe. APEX charts and
-- Interactive Reports bind directly to these views — no external BI service.
-- ---------------------------------------------------------------------------

-- Scans per day (last 30 days) for a line/bar chart.
CREATE OR REPLACE VIEW vw_admin_scans_per_day AS
SELECT TRUNC(ds.scan_timestamp)              AS scan_day,
       COUNT(*)                              AS scan_count,
       SUM(CASE WHEN ds.severity IN ('HIGH','CRITICAL') THEN 1 ELSE 0 END) AS severe_count
FROM   disease_scans ds
WHERE  ds.scan_timestamp >= TRUNC(SYSDATE) - 30
GROUP  BY TRUNC(ds.scan_timestamp)
ORDER  BY scan_day;

-- Alerts grouped by type + severity for a stacked bar / pie chart.
CREATE OR REPLACE VIEW vw_admin_alerts_by_type AS
SELECT a.alert_type,
       a.severity,
       COUNT(*)                                            AS alert_count,
       SUM(CASE WHEN a.is_sent = 'Y' THEN 1 ELSE 0 END)    AS sent_count
FROM   alerts a
GROUP  BY a.alert_type, a.severity;

-- Top detected diseases (last 90 days) for a ranked bar chart.
CREATE OR REPLACE VIEW vw_admin_top_diseases AS
SELECT ds.disease_detected,
       COUNT(*)                  AS detections,
       ROUND(AVG(ds.confidence_score), 1) AS avg_confidence
FROM   disease_scans ds
WHERE  ds.disease_detected IS NOT NULL
AND    ds.scan_timestamp >= TRUNC(SYSDATE) - 90
GROUP  BY ds.disease_detected
ORDER  BY detections DESC
FETCH FIRST 10 ROWS ONLY;

-- Mandi price trend (avg modal price per crop per day, last 90 days) for a
-- multi-series line chart.
CREATE OR REPLACE VIEW vw_admin_price_trends AS
SELECT mp.recorded_date,
       c.crop_name,
       ROUND(AVG(mp.price_per_qtl), 2) AS avg_price_per_qtl
FROM   mandi_prices mp
JOIN   crops c ON c.crop_id = mp.crop_id
WHERE  mp.recorded_date >= TRUNC(SYSDATE) - 90
GROUP  BY mp.recorded_date, c.crop_name
ORDER  BY mp.recorded_date;

-- Single-row KPI tiles (farmers, scans, active alerts, schemes matched).
CREATE OR REPLACE VIEW vw_admin_stats AS
SELECT
    (SELECT COUNT(*) FROM farmers WHERE is_active = 'Y')                       AS active_farmers,
    (SELECT COUNT(*) FROM disease_scans
      WHERE scan_timestamp >= TRUNC(SYSDATE) - 30)                            AS scans_30d,
    (SELECT COUNT(*) FROM alerts
      WHERE is_sent = 'N')                                                     AS pending_alerts,
    (SELECT COUNT(*) FROM alerts
      WHERE created_at >= SYSTIMESTAMP - INTERVAL '7' DAY)                     AS alerts_7d,
    (SELECT COUNT(DISTINCT farmer_id) FROM scheme_matches)                     AS farmers_with_matches,
    (SELECT COUNT(*) FROM government_schemes WHERE is_active = 'Y')            AS active_schemes
FROM dual;

-- ---------------------------------------------------------------------------
-- Shared LOVs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_lov_districts AS
SELECT DISTINCT district AS d, district AS r FROM farmers WHERE district IS NOT NULL;

CREATE OR REPLACE VIEW vw_lov_crops AS
SELECT crop_name || ' / ' || crop_name_hindi AS d, crop_id AS r FROM crops ORDER BY crop_name;
