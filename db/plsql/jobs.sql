-- =============================================================================
-- KrishiMitra :: DBMS_SCHEDULER jobs   [FREE PATH]
-- File: jobs.sql
--
-- These jobs run the free, ATP-native ingestion + dispatch packages (no OIC,
-- no Streaming, no paid services). Time zone pinned to Asia/Kolkata.
--
-- JOB_WEATHER_SYNC        - every 6h  -> PKG_WEATHER_SYNC.RUN   (Open-Meteo, free)
-- JOB_MANDI_SYNC          - 06:00 IST -> PKG_MANDI_SYNC.RUN     (Agmarknet, free)
-- JOB_SCHEME_SYNC         - Sun 02:00 -> PKG_SCHEME_SYNC.RUN    (data.gov.in, free)
-- JOB_SCHEME_MATCH_DAILY  - 01:00 IST -> PKG_SCHEME_MATCHER.MATCH_ALL_FARMERS
-- JOB_PRICE_ALERT_SWEEP   - 06:30 IST -> re-evaluate price movement rules
-- JOB_ALERT_DISPATCH      - every 15m -> PKG_ALERTS.SEND_BATCH (email/in-app)
--
-- Idempotent: each job is dropped (force) before (re)creation.
-- =============================================================================

BEGIN
    BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_WEATHER_SYNC', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_WEATHER_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN pkg_weather_sync.run; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=HOURLY; INTERVAL=6',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'KrishiMitra: free weather sync via Open-Meteo every 6h.');
END;
/

BEGIN
    BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_MANDI_SYNC', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_MANDI_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN pkg_mandi_sync.run; END;',
        start_date      => TO_TIMESTAMP_TZ('2025-01-01 06:00:00 Asia/Kolkata','YYYY-MM-DD HH24:MI:SS TZR'),
        repeat_interval => 'FREQ=DAILY; BYHOUR=6; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'KrishiMitra: free Mandi price sync via Agmarknet (data.gov.in) daily 06:00 IST.');
END;
/

BEGIN
    BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_SCHEME_SYNC', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_SCHEME_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN pkg_scheme_sync.run; END;',
        start_date      => TO_TIMESTAMP_TZ('2025-01-01 02:00:00 Asia/Kolkata','YYYY-MM-DD HH24:MI:SS TZR'),
        repeat_interval => 'FREQ=WEEKLY; BYDAY=SUN; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'KrishiMitra: free scheme data sync via data.gov.in weekly Sun 02:00 IST.');
END;
/

BEGIN
    BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_SCHEME_MATCH_DAILY', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_SCHEME_MATCH_DAILY',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN pkg_scheme_matcher.match_all_farmers; END;',
        start_date      => TO_TIMESTAMP_TZ('2025-01-01 01:00:00 Asia/Kolkata','YYYY-MM-DD HH24:MI:SS TZR'),
        repeat_interval => 'FREQ=DAILY; BYHOUR=1; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'KrishiMitra: nightly scheme eligibility matching at 01:00 IST.');
END;
/

BEGIN
    BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_PRICE_ALERT_SWEEP', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_PRICE_ALERT_SWEEP',
        job_type        => 'PLSQL_BLOCK',
        job_action      => q'[DECLARE
                                l_n NUMBER;
                              BEGIN
                                FOR r IN (
                                    SELECT DISTINCT crop_id, mandi_name, district
                                    FROM   mandi_prices
                                    WHERE  recorded_date >= TRUNC(SYSDATE) - 7
                                ) LOOP
                                    l_n := pkg_price_tracker.evaluate_price_movement(
                                               r.crop_id, r.mandi_name, r.district);
                                END LOOP;
                                COMMIT;
                              END;]',
        start_date      => TO_TIMESTAMP_TZ('2025-01-01 06:30:00 Asia/Kolkata','YYYY-MM-DD HH24:MI:SS TZR'),
        repeat_interval => 'FREQ=DAILY; BYHOUR=6; BYMINUTE=30; BYSECOND=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'KrishiMitra: daily price-movement sweep after Mandi sync.');
END;
/

BEGIN
    BEGIN DBMS_SCHEDULER.DROP_JOB('JOB_ALERT_DISPATCH', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_ALERT_DISPATCH',
        job_type        => 'PLSQL_BLOCK',
        -- Free dispatch: email (DBMS_CLOUD_NOTIFICATION) + in-app. Replaces the
        -- OCI Streaming -> Function -> SMS pipeline. Processes EMAIL then APP.
        job_action      => q'[DECLARE n NUMBER;
                              BEGIN
                                n := pkg_alerts.send_batch('EMAIL', 1000);
                                n := pkg_alerts.send_batch('APP', 1000);
                              END;]',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY; INTERVAL=15',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'KrishiMitra: free alert dispatch (email + in-app) every 15 minutes.');
END;
/
