-- =============================================================================
-- KrishiMitra :: master DB deploy script
-- Run with SQLcl / SQL*Plus as the KRISHIMITRA schema owner:
--   sql krishimitra/<pwd>@<atp_tns> @db/deploy.sql
--
-- Order matters: tables -> indexes -> audit triggers -> PL/SQL (alerts first,
-- since other packages depend on it) -> business trigger -> jobs -> ORDS -> seed.
-- =============================================================================
WHENEVER SQLERROR CONTINUE
SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT === DDL: tables ===
@@ddl/01_tables.sql
PROMPT === DDL: indexes ===
@@ddl/02_indexes.sql
PROMPT === DDL: audit triggers ===
@@ddl/03_audit_triggers.sql
PROMPT === DDL: app_config + app_cfg (free path) ===
@@ddl/05_app_config.sql
-- NOTE: ddl/04_network_acls.sql must be run ONCE as ADMIN to allow ATP egress
-- to Open-Meteo + data.gov.in (free ingestion). It is intentionally NOT run
-- here because the app schema cannot grant its own ACEs.

PROMPT === PL/SQL: PKG_NOTIFY (free email) ===
@@plsql/pkg_notify.pks
@@plsql/pkg_notify.pkb
PROMPT === PL/SQL: PKG_ALERTS ===
@@plsql/pkg_alerts.pks
@@plsql/pkg_alerts.pkb
PROMPT === PL/SQL: PKG_FARMER ===
@@plsql/pkg_farmer.pks
@@plsql/pkg_farmer.pkb
PROMPT === PL/SQL: PKG_SCHEME_MATCHER ===
@@plsql/pkg_scheme_matcher.pks
@@plsql/pkg_scheme_matcher.pkb
PROMPT === PL/SQL: PKG_PRICE_TRACKER ===
@@plsql/pkg_price_tracker.pks
@@plsql/pkg_price_tracker.pkb
PROMPT === PL/SQL: free ingestion (weather / mandi / scheme) ===
@@plsql/pkg_weather_sync.pks
@@plsql/pkg_weather_sync.pkb
@@plsql/pkg_mandi_sync.pks
@@plsql/pkg_mandi_sync.pkb
@@plsql/pkg_scheme_sync.pks
@@plsql/pkg_scheme_sync.pkb

PROMPT === Trigger: TRG_DISEASE_SCAN_ALERT ===
@@plsql/trg_disease_scan_alert.sql
PROMPT === Scheduler jobs ===
@@plsql/jobs.sql

PROMPT === Recompile to clear any dependency order issues ===
BEGIN
    DBMS_UTILITY.COMPILE_SCHEMA(schema => SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),
                                compile_all => FALSE);
END;
/

PROMPT === ORDS module ===
@@ords/ords_setup.sql

PROMPT === Seed: crops ===
@@seed/01_crops_seed.sql
PROMPT === Seed: schemes ===
@@seed/02_schemes_seed.sql
PROMPT === Seed: farmers + activity ===
@@seed/03_farmers_and_activity_seed.sql

PROMPT === Done. ===
