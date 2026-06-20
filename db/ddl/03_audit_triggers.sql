-- =============================================================================
-- KrishiMitra :: Audit triggers
-- File: 03_audit_triggers.sql
-- Run order: 3 of 3
--
-- Keeps updated_at current on every UPDATE. created_at / created_by retain
-- their DEFAULT values on INSERT, but we also defensively stamp created_by /
-- created_at on insert if a caller left them NULL.
-- =============================================================================

-- Generic pattern, repeated per table. Oracle has no multi-table triggers, so
-- one compact BEFORE INSERT OR UPDATE trigger is defined for each table.

CREATE OR REPLACE TRIGGER trg_bi_bu_farmers
BEFORE INSERT OR UPDATE ON farmers
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_crops
BEFORE INSERT OR UPDATE ON crops
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_farmer_crops
BEFORE INSERT OR UPDATE ON farmer_crops
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_disease_scans
BEFORE INSERT OR UPDATE ON disease_scans
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_weather_data
BEFORE INSERT OR UPDATE ON weather_data
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_mandi_prices
BEFORE INSERT OR UPDATE ON mandi_prices
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_alerts
BEFORE INSERT OR UPDATE ON alerts
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_government_schemes
BEFORE INSERT OR UPDATE ON government_schemes
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_scheme_matches
BEFORE INSERT OR UPDATE ON scheme_matches
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER trg_bi_bu_ml_predictions
BEFORE INSERT OR UPDATE ON ml_predictions
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.created_at := COALESCE(:NEW.created_at, SYSTIMESTAMP);
        :NEW.created_by := COALESCE(:NEW.created_by, USER);
    END IF;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/
