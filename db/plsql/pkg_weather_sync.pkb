-- =============================================================================
-- KrishiMitra :: PKG_WEATHER_SYNC (body)  [FREE PATH - Open-Meteo, keyless]
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_weather_sync AS

    PROCEDURE geocode (
        p_district IN  VARCHAR2,
        p_lat      OUT NUMBER,
        p_lon      OUT NUMBER
    ) IS
        l_resp CLOB;
        l_url  VARCHAR2(500);
    BEGIN
        l_url := app_cfg('OPEN_METEO_GEOCODE_URL')
                 || '?name=' || APEX_UTIL.URL_ENCODE(p_district)
                 || '&count=1&country=IN&language=en&format=json';

        l_resp := APEX_WEB_SERVICE.MAKE_REST_REQUEST(p_url => l_url, p_http_method => 'GET');

        p_lat := TO_NUMBER(JSON_VALUE(l_resp, '$.results[0].latitude'));
        p_lon := TO_NUMBER(JSON_VALUE(l_resp, '$.results[0].longitude'));
    EXCEPTION
        WHEN OTHERS THEN
            p_lat := NULL; p_lon := NULL;
    END geocode;

    FUNCTION sync_district (
        p_district IN VARCHAR2,
        p_state    IN VARCHAR2
    ) RETURN NUMBER IS
        l_lat   NUMBER;
        l_lon   NUMBER;
        l_resp  CLOB;
        l_url   VARCHAR2(1000);
    BEGIN
        geocode(p_district, l_lat, l_lon);
        IF l_lat IS NULL OR l_lon IS NULL THEN
            RETURN 0;
        END IF;

        -- Current conditions + 7-day daily forecast (rainfall sum, temp range).
        l_url := app_cfg('OPEN_METEO_FORECAST_URL')
                 || '?latitude='  || l_lat
                 || '&longitude=' || l_lon
                 || '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation'
                 || '&daily=precipitation_sum,temperature_2m_max,temperature_2m_min'
                 || '&forecast_days=7&timezone=Asia%2FKolkata';

        l_resp := APEX_WEB_SERVICE.MAKE_REST_REQUEST(p_url => l_url, p_http_method => 'GET');

        INSERT INTO weather_data (
            district, state, recorded_at, temp_celsius, humidity_pct,
            rainfall_mm, wind_speed_kmh, forecast_json, source
        ) VALUES (
            p_district, p_state, SYSTIMESTAMP,
            TO_NUMBER(JSON_VALUE(l_resp, '$.current.temperature_2m')),
            TO_NUMBER(JSON_VALUE(l_resp, '$.current.relative_humidity_2m')),
            TO_NUMBER(JSON_VALUE(l_resp, '$.current.precipitation')),
            TO_NUMBER(JSON_VALUE(l_resp, '$.current.wind_speed_10m')),
            JSON_QUERY(l_resp, '$.daily'),
            'OWM'   -- Open-Meteo; stored under the existing source domain value
        );

        RETURN 1;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END sync_district;

    PROCEDURE run IS
        l_ok NUMBER := 0;
    BEGIN
        FOR d IN (
            SELECT DISTINCT district, MAX(state) AS state
            FROM   farmers
            WHERE  is_active = 'Y' AND district IS NOT NULL
            GROUP  BY district
        ) LOOP
            l_ok := l_ok + sync_district(d.district, d.state);
        END LOOP;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Weather sync complete for ' || l_ok || ' districts.');
    END run;

END pkg_weather_sync;
/
