-- =============================================================================
-- KrishiMitra :: PKG_WEATHER_SYNC (specification)  [FREE PATH]
-- Replaces OIC INT-01. Pulls weather from Open-Meteo (keyless, free) via
-- APEX_WEB_SERVICE and loads WEATHER_DATA. Invoked by JOB_WEATHER_SYNC.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_weather_sync AS

    -- Geocode a district name to latitude/longitude (Open-Meteo geocoding, free).
    PROCEDURE geocode (
        p_district IN  VARCHAR2,
        p_lat      OUT NUMBER,
        p_lon      OUT NUMBER
    );

    -- Fetch + store the current/forecast weather for one district.
    -- Returns 1 if a row was inserted, 0 otherwise.
    FUNCTION sync_district (
        p_district IN VARCHAR2,
        p_state    IN VARCHAR2
    ) RETURN NUMBER;

    -- Refresh weather for every distinct active-farmer district. Returns the
    -- number of districts successfully synced.
    PROCEDURE run;

END pkg_weather_sync;
/
