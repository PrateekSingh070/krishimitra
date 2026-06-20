-- =============================================================================
-- KrishiMitra :: APP_CONFIG (non-secret runtime config) + credential guidance
-- File: 05_app_config.sql
--
-- Holds runtime config read by the free ingestion + email packages (endpoint
-- base URLs, resource ids, email sender/host, and the data.gov.in API key +
-- SMTP credentials).
--
-- IMPORTANT: the secret-ish values (DATAGOV_API_KEY, EMAIL_SMTP_USER,
-- EMAIL_SMTP_PASSWORD) are intentionally NOT seeded by this committed script.
-- Set them at deploy time from a separate, un-committed script, e.g.:
--
--   -- deploy-secrets.sql  (DO NOT COMMIT)
--   MERGE INTO app_config t USING (
--     SELECT 'DATAGOV_API_KEY'     k, '<free data.gov.in key>' v FROM dual UNION ALL
--     SELECT 'EMAIL_SMTP_USER',       '<ocid-smtp-user>'         FROM dual UNION ALL
--     SELECT 'EMAIL_SMTP_PASSWORD',   '<smtp-password>'          FROM dual
--   ) s ON (t.cfg_key = s.k)
--   WHEN MATCHED THEN UPDATE SET t.cfg_value = s.v
--   WHEN NOT MATCHED THEN INSERT (cfg_key, cfg_value) VALUES (s.k, s.v);
--
-- They are query-param / SMTP-AUTH values that cannot use a DBMS_CLOUD
-- credential (whose secret is never readable back). Keeping them out of source
-- preserves the "zero hardcoded secrets" guarantee.
-- =============================================================================

BEGIN
    EXECUTE IMMEDIATE q'[
        CREATE TABLE app_config (
            cfg_key    VARCHAR2(100) PRIMARY KEY,
            cfg_value  VARCHAR2(1000) NOT NULL,
            updated_at TIMESTAMP DEFAULT SYSTIMESTAMP
        )]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN RAISE; END IF;  -- ignore "already exists"
END;
/

MERGE INTO app_config t
USING (
    SELECT 'OPEN_METEO_FORECAST_URL' k, 'https://api.open-meteo.com/v1/forecast' v FROM dual UNION ALL
    SELECT 'OPEN_METEO_GEOCODE_URL',     'https://geocoding-api.open-meteo.com/v1/search' FROM dual UNION ALL
    SELECT 'DATAGOV_BASE_URL',           'https://api.data.gov.in/resource' FROM dual UNION ALL
    SELECT 'AGMARKNET_RESOURCE_ID',      '9ef84268-d588-465a-a308-a864a43d0070' FROM dual UNION ALL
    SELECT 'SCHEME_RESOURCE_ID',         '00000000-0000-0000-0000-000000000000' FROM dual UNION ALL
    SELECT 'EMAIL_SENDER',               'krishimitra@example.com' FROM dual UNION ALL
    SELECT 'EMAIL_SMTP_HOST',            'smtp.email.ap-mumbai-1.oci.oraclecloud.com' FROM dual UNION ALL
    SELECT 'EMAIL_SMTP_PORT',            '587' FROM dual
    -- NOTE: DATAGOV_API_KEY, EMAIL_SMTP_USER, EMAIL_SMTP_PASSWORD are set at
    -- deploy time from an un-committed script (see header), never seeded here.
) s
ON (t.cfg_key = s.k)
WHEN MATCHED THEN UPDATE SET t.cfg_value = s.v, t.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (cfg_key, cfg_value) VALUES (s.k, s.v);
COMMIT;

-- Idempotent migration: ensure FARMERS.EMAIL exists for already-deployed schemas
-- (new deployments already get it from ddl/01_tables.sql).
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE farmers ADD (email VARCHAR2(150))';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1430 THEN RAISE; END IF;  -- ORA-01430: column already exists
END;
/

CREATE OR REPLACE FUNCTION app_cfg (p_key IN VARCHAR2) RETURN VARCHAR2 IS
    l_val app_config.cfg_value%TYPE;
BEGIN
    SELECT cfg_value INTO l_val FROM app_config WHERE cfg_key = p_key;
    RETURN l_val;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END;
/
