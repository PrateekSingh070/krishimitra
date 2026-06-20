-- =============================================================================
-- KrishiMitra :: PostgreSQL :: Triggers
-- File: db/postgres/03_triggers.sql   (run order: 3 of 4)
--
-- Replaces:
--   * db/ddl/03_audit_triggers.sql      -> set updated_at on UPDATE
--   * db/plsql/trg_disease_scan_alert.sql -> auto-alert on HIGH/CRITICAL scans
--
-- Note: the disease-scan alert is also created by the Node service when scans
-- are written via the API. This DB trigger guarantees an alert even for direct
-- inserts (e.g. seed data, SQL editor). It is written to avoid duplicates by
-- keying off the scan that triggered it.
-- =============================================================================

-- --- updated_at maintenance ---------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    t text;
    tbls text[] := ARRAY['farmers','crops','farmer_crops','disease_scans',
                         'weather_data','mandi_prices','alerts',
                         'government_schemes','scheme_matches','ml_predictions'];
BEGIN
    FOREACH t IN ARRAY tbls LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
        EXECUTE format(
            'CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
    END LOOP;
END;
$$;

-- --- disease scan -> alert (HIGH / CRITICAL) ----------------------------------
CREATE OR REPLACE FUNCTION trg_disease_scan_alert_fn()
RETURNS trigger AS $$
DECLARE
    v_lang  varchar(10);
    v_en    varchar(1000);
    v_hi    varchar(1000);
BEGIN
    IF NEW.severity IN ('HIGH', 'CRITICAL') THEN
        SELECT preferred_lang INTO v_lang FROM farmers WHERE farmer_id = NEW.farmer_id;

        v_en := 'Disease detected: ' || COALESCE(NEW.disease_detected, 'unknown')
                || ' (' || NEW.severity || '). ' || COALESCE(NEW.treatment_advice, '');
        v_hi := 'रोग पाया गया: ' || COALESCE(NEW.disease_detected, 'अज्ञात')
                || ' (' || NEW.severity || '). ' || COALESCE(NEW.treatment_hindi, '');

        INSERT INTO alerts (alert_type, farmer_id, message_en, message_hi,
                            severity, is_sent, channel)
        VALUES ('DISEASE', NEW.farmer_id, v_en, v_hi, NEW.severity, 'N', 'EMAIL');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_disease_scan_alert ON disease_scans;
CREATE TRIGGER trg_disease_scan_alert
    AFTER INSERT ON disease_scans
    FOR EACH ROW EXECUTE FUNCTION trg_disease_scan_alert_fn();
