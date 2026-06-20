-- =============================================================================
-- KrishiMitra :: PKG_MANDI_SYNC (body)  [FREE PATH - Agmarknet/data.gov.in]
-- The data.gov.in API key is supplied as the password of a DBMS_CLOUD
-- credential (name in app_config 'DATAGOV_CRED_NAME'); never stored in source.
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_mandi_sync AS

    -- Resolve crop_id by (English) commodity name; NULL if unknown.
    FUNCTION crop_id_for (p_commodity IN VARCHAR2) RETURN NUMBER IS
        l_id crops.crop_id%TYPE;
    BEGIN
        SELECT crop_id INTO l_id
        FROM   crops
        WHERE  UPPER(crop_name) = UPPER(TRIM(p_commodity))
        FETCH FIRST 1 ROW ONLY;
        RETURN l_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END crop_id_for;

    FUNCTION api_key RETURN VARCHAR2 IS
    BEGIN
        -- The free data.gov.in key is read from APP_CONFIG('DATAGOV_API_KEY'),
        -- which is populated at deploy time (NOT committed to source). It is a
        -- query-param key, so it cannot use a DBMS_CLOUD credential (whose secret
        -- is never readable back).
        RETURN app_cfg('DATAGOV_API_KEY');
    END api_key;

    FUNCTION sync_page (
        p_offset IN PLS_INTEGER DEFAULT 0,
        p_limit  IN PLS_INTEGER DEFAULT 100
    ) RETURN NUMBER IS
        l_url   VARCHAR2(1000);
        l_resp  CLOB;
        l_cnt   NUMBER := 0;
        l_cid   NUMBER;
        l_dummy mandi_prices.price_id%TYPE;
    BEGIN
        l_url := app_cfg('DATAGOV_BASE_URL') || '/' || app_cfg('AGMARKNET_RESOURCE_ID')
                 || '?api-key=' || api_key()
                 || '&format=json&offset=' || p_offset || '&limit=' || p_limit;

        l_resp := APEX_WEB_SERVICE.MAKE_REST_REQUEST(p_url => l_url, p_http_method => 'GET');

        FOR rec IN (
            SELECT commodity, market, district, state, modal_price, arrival_date
            FROM   JSON_TABLE(l_resp, '$.records[*]'
                       COLUMNS (
                           commodity    VARCHAR2(100) PATH '$.commodity',
                           market       VARCHAR2(100) PATH '$.market',
                           district     VARCHAR2(50)  PATH '$.district',
                           state        VARCHAR2(50)  PATH '$.state',
                           modal_price  VARCHAR2(20)  PATH '$.modal_price',
                           arrival_date VARCHAR2(20)  PATH '$.arrival_date'))
        ) LOOP
            l_cid := crop_id_for(rec.commodity);
            CONTINUE WHEN l_cid IS NULL;  -- skip commodities we don't track

            l_dummy := pkg_price_tracker.record_price(
                p_crop_id       => l_cid,
                p_mandi_name    => rec.market,
                p_district      => rec.district,
                p_state         => rec.state,
                p_price_per_qtl => TO_NUMBER(rec.modal_price DEFAULT NULL ON CONVERSION ERROR),
                p_recorded_date => TO_DATE(rec.arrival_date DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY'),
                p_source        => 'Agmarknet');
            l_cnt := l_cnt + 1;
        END LOOP;

        RETURN l_cnt;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN l_cnt;
    END sync_page;

    PROCEDURE run (
        p_max_records IN PLS_INTEGER DEFAULT 1000
    ) IS
        l_off  PLS_INTEGER := 0;
        l_lim  PLS_INTEGER := 100;
        l_got  NUMBER;
        l_tot  NUMBER := 0;
    BEGIN
        WHILE l_off < p_max_records LOOP
            l_got := sync_page(l_off, l_lim);
            l_tot := l_tot + l_got;
            EXIT WHEN l_got = 0;
            l_off := l_off + l_lim;
        END LOOP;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Mandi sync inserted ' || l_tot || ' price rows.');
    END run;

END pkg_mandi_sync;
/
