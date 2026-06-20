-- =============================================================================
-- KrishiMitra :: PKG_SCHEME_SYNC (body)  [FREE PATH - data.gov.in]
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_scheme_sync AS

    FUNCTION json_arr (p_csv IN VARCHAR2) RETURN VARCHAR2 IS
        l_out VARCHAR2(1000);
    BEGIN
        IF p_csv IS NULL OR TRIM(p_csv) IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT '[' || LISTAGG('"' || TRIM(token) || '"', ',') || ']'
        INTO   l_out
        FROM (
            SELECT REGEXP_SUBSTR(p_csv, '[^,]+', 1, LEVEL) AS token
            FROM   dual
            CONNECT BY REGEXP_SUBSTR(p_csv, '[^,]+', 1, LEVEL) IS NOT NULL
        );
        RETURN l_out;
    END json_arr;

    FUNCTION build_eligibility_json (
        p_min_land   IN NUMBER,
        p_max_land   IN NUMBER,
        p_states_csv IN VARCHAR2,
        p_crops_csv  IN VARCHAR2,
        p_max_income IN NUMBER
    ) RETURN VARCHAR2 IS
        l_parts APEX_T_VARCHAR2 := APEX_T_VARCHAR2();
        l_states VARCHAR2(1000) := json_arr(p_states_csv);
        l_crops  VARCHAR2(1000) := json_arr(p_crops_csv);
    BEGIN
        IF p_min_land   IS NOT NULL THEN apex_string.push(l_parts, '"min_land":' || p_min_land); END IF;
        IF p_max_land   IS NOT NULL THEN apex_string.push(l_parts, '"max_land":' || p_max_land); END IF;
        IF l_states     IS NOT NULL THEN apex_string.push(l_parts, '"states":'  || l_states); END IF;
        IF l_crops      IS NOT NULL THEN apex_string.push(l_parts, '"crops":'   || l_crops); END IF;
        IF p_max_income IS NOT NULL THEN apex_string.push(l_parts, '"max_income":' || p_max_income); END IF;
        RETURN '{' || apex_string.join(l_parts, ',') || '}';
    END build_eligibility_json;

    FUNCTION api_key RETURN VARCHAR2 IS
    BEGIN
        -- Free data.gov.in key from APP_CONFIG (set at deploy, not in source).
        RETURN app_cfg('DATAGOV_API_KEY');
    END api_key;

    PROCEDURE run IS
        l_url  VARCHAR2(1000);
        l_resp CLOB;
        l_n    NUMBER := 0;
    BEGIN
        l_url := app_cfg('DATAGOV_BASE_URL') || '/' || app_cfg('SCHEME_RESOURCE_ID')
                 || '?api-key=' || api_key() || '&format=json&limit=500';

        l_resp := APEX_WEB_SERVICE.MAKE_REST_REQUEST(p_url => l_url, p_http_method => 'GET');

        FOR rec IN (
            SELECT *
            FROM   JSON_TABLE(l_resp, '$.records[*]'
                       COLUMNS (
                           scheme_name    VARCHAR2(200) PATH '$.scheme_name',
                           scheme_name_hi VARCHAR2(200) PATH '$.scheme_name_hi',
                           ministry       VARCHAR2(100) PATH '$.ministry',
                           benefit_amount VARCHAR2(20)  PATH '$.benefit_amount',
                           min_land       VARCHAR2(20)  PATH '$.min_land_acres',
                           max_land       VARCHAR2(20)  PATH '$.max_land_acres',
                           states         VARCHAR2(500) PATH '$.states',
                           crops          VARCHAR2(500) PATH '$.crops',
                           max_income     VARCHAR2(20)  PATH '$.max_income',
                           apply_url      VARCHAR2(500) PATH '$.apply_url',
                           deadline       VARCHAR2(20)  PATH '$.deadline',
                           status         VARCHAR2(20)  PATH '$.status'))
        ) LOOP
            CONTINUE WHEN rec.status IS NOT NULL AND UPPER(rec.status) != 'ACTIVE';

            MERGE INTO government_schemes t
            USING (SELECT rec.scheme_name AS nm FROM dual) s
            ON (t.scheme_name = s.nm)
            WHEN MATCHED THEN UPDATE SET
                scheme_name_hi   = rec.scheme_name_hi,
                ministry         = rec.ministry,
                benefit_amount   = TO_NUMBER(rec.benefit_amount DEFAULT NULL ON CONVERSION ERROR),
                eligibility_json = build_eligibility_json(
                                       TO_NUMBER(rec.min_land DEFAULT NULL ON CONVERSION ERROR),
                                       TO_NUMBER(rec.max_land DEFAULT NULL ON CONVERSION ERROR),
                                       rec.states, rec.crops,
                                       TO_NUMBER(rec.max_income DEFAULT NULL ON CONVERSION ERROR)),
                apply_url        = rec.apply_url,
                deadline         = TO_DATE(rec.deadline DEFAULT NULL ON CONVERSION ERROR, 'YYYY-MM-DD'),
                is_active        = 'Y'
            WHEN NOT MATCHED THEN INSERT (
                scheme_name, scheme_name_hi, ministry, benefit_amount,
                eligibility_json, apply_url, deadline, is_active
            ) VALUES (
                rec.scheme_name, rec.scheme_name_hi, rec.ministry,
                TO_NUMBER(rec.benefit_amount DEFAULT NULL ON CONVERSION ERROR),
                build_eligibility_json(
                    TO_NUMBER(rec.min_land DEFAULT NULL ON CONVERSION ERROR),
                    TO_NUMBER(rec.max_land DEFAULT NULL ON CONVERSION ERROR),
                    rec.states, rec.crops,
                    TO_NUMBER(rec.max_income DEFAULT NULL ON CONVERSION ERROR)),
                rec.apply_url,
                TO_DATE(rec.deadline DEFAULT NULL ON CONVERSION ERROR, 'YYYY-MM-DD'),
                'Y');
            l_n := l_n + 1;
        END LOOP;

        -- Auto-deactivate expired schemes.
        UPDATE government_schemes
        SET    is_active = 'N'
        WHERE  deadline IS NOT NULL AND deadline < TRUNC(SYSDATE) AND is_active = 'Y';

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Scheme sync upserted ' || l_n || ' schemes.');
    END run;

END pkg_scheme_sync;
/
