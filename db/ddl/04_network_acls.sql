-- =============================================================================
-- KrishiMitra :: Network ACLs for outbound REST calls from ATP (free path)
-- File: 04_network_acls.sql  (run as ADMIN, or grant the schema first)
--
-- The free ingestion packages (PKG_WEATHER_SYNC / PKG_MANDI_SYNC /
-- PKG_SCHEME_SYNC) call external REST APIs from inside Autonomous DB using
-- APEX_WEB_SERVICE. ATP requires an explicit ACE per host for the schema.
--
-- All hosts below are free / keyless or use a free data.gov.in key:
--   * open-meteo.com           - weather forecast (keyless, free)
--   * geocoding-api.open-meteo.com - district -> lat/lon (keyless, free)
--   * api.data.gov.in          - Agmarknet prices + scheme data (free key)
-- =============================================================================

BEGIN
    -- Grant HTTP egress for the application schema (replace KRISHIMITRA if needed).
    FOR h IN (
        SELECT 'api.open-meteo.com'           AS host FROM dual UNION ALL
        SELECT 'geocoding-api.open-meteo.com'        FROM dual UNION ALL
        SELECT 'api.data.gov.in'                     FROM dual
    ) LOOP
        BEGIN
            DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
                host => h.host,
                ace  => xs$ace_type(
                            privilege_list => xs$name_list('http', 'http_proxy'),
                            principal_name => 'KRISHIMITRA',
                            principal_type => xs_acl.ptype_db));
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('ACE skip for ' || h.host || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/
