-- =============================================================================
-- KrishiMitra :: PKG_SCHEME_MATCHER (body)
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_scheme_matcher AS

    -- Upsert one match row and, if it newly crosses the alert threshold,
    -- generate a SCHEME alert for the farmer.
    PROCEDURE upsert_match (
        p_farmer_id  IN farmers.farmer_id%TYPE,
        p_scheme_id  IN government_schemes.scheme_id%TYPE,
        p_score      IN NUMBER
    ) IS
        l_prev_score scheme_matches.match_score%TYPE;
        l_exists     BOOLEAN := FALSE;
        l_scheme_en  government_schemes.scheme_name%TYPE;
        l_scheme_hi  government_schemes.scheme_name_hi%TYPE;
    BEGIN
        BEGIN
            SELECT match_score
            INTO   l_prev_score
            FROM   scheme_matches
            WHERE  farmer_id = p_farmer_id
            AND    scheme_id = p_scheme_id
            FOR UPDATE;
            l_exists := TRUE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_exists := FALSE;
        END;

        IF l_exists THEN
            UPDATE scheme_matches
            SET    match_score = p_score,
                   matched_at  = SYSTIMESTAMP
            WHERE  farmer_id = p_farmer_id
            AND    scheme_id = p_scheme_id;
        ELSE
            INSERT INTO scheme_matches (farmer_id, scheme_id, match_score, notified)
            VALUES (p_farmer_id, p_scheme_id, p_score, 'N');
        END IF;

        -- Alert only when a match newly crosses the threshold (avoid re-alerting).
        IF p_score > c_alert_threshold
           AND (NOT l_exists OR NVL(l_prev_score, 0) <= c_alert_threshold) THEN

            SELECT scheme_name, scheme_name_hi
            INTO   l_scheme_en, l_scheme_hi
            FROM   government_schemes
            WHERE  scheme_id = p_scheme_id;

            DECLARE
                l_alert_id alerts.alert_id%TYPE;
            BEGIN
                l_alert_id := pkg_alerts.generate_alert(
                    p_alert_type => 'SCHEME',
                    p_farmer_id  => p_farmer_id,
                    p_message_en => 'You may be eligible for: ' || l_scheme_en
                                    || '. Apply via KrishiMitra.',
                    p_message_hi => 'आप इस योजना के पात्र हो सकते हैं: '
                                    || NVL(l_scheme_hi, l_scheme_en)
                                    || '. कृषिमित्र पर आवेदन करें.',
                    p_severity   => pkg_alerts.c_sev_low,
                    p_channel    => pkg_alerts.c_chan_email
                );

                UPDATE scheme_matches
                SET    notified = 'Y'
                WHERE  farmer_id = p_farmer_id
                AND    scheme_id = p_scheme_id;
            END;
        END IF;
    END upsert_match;

    FUNCTION score_match (
        p_farmer_id        IN farmers.farmer_id%TYPE,
        p_eligibility_json IN CLOB
    ) RETURN NUMBER IS
        l_min_land   NUMBER;
        l_max_land   NUMBER;
        l_max_income NUMBER;

        l_land       farmers.land_acres%TYPE;
        l_state      farmers.state%TYPE;

        l_criteria   PLS_INTEGER := 0;   -- number of criteria present
        l_met        PLS_INTEGER := 0;   -- number the farmer satisfies

        l_has_states  BOOLEAN;
        l_has_crops   BOOLEAN;
        l_state_ok    PLS_INTEGER;
        l_crop_ok     PLS_INTEGER;
    BEGIN
        IF p_eligibility_json IS NULL THEN
            RETURN 0;
        END IF;

        SELECT land_acres, state
        INTO   l_land, l_state
        FROM   farmers
        WHERE  farmer_id = p_farmer_id;

        l_min_land   := JSON_VALUE(p_eligibility_json, '$.min_land'   RETURNING NUMBER);
        l_max_land   := JSON_VALUE(p_eligibility_json, '$.max_land'   RETURNING NUMBER);
        l_max_income := JSON_VALUE(p_eligibility_json, '$.max_income' RETURNING NUMBER);
        l_has_states := JSON_EXISTS(p_eligibility_json, '$.states');
        l_has_crops  := JSON_EXISTS(p_eligibility_json, '$.crops');

        -- min_land
        IF l_min_land IS NOT NULL THEN
            l_criteria := l_criteria + 1;
            IF l_land IS NOT NULL AND l_land >= l_min_land THEN
                l_met := l_met + 1;
            END IF;
        END IF;

        -- max_land
        IF l_max_land IS NOT NULL THEN
            l_criteria := l_criteria + 1;
            IF l_land IS NOT NULL AND l_land <= l_max_land THEN
                l_met := l_met + 1;
            END IF;
        END IF;

        -- states array membership
        IF l_has_states THEN
            l_criteria := l_criteria + 1;
            SELECT COUNT(*)
            INTO   l_state_ok
            FROM   JSON_TABLE(p_eligibility_json, '$.states[*]'
                       COLUMNS (st VARCHAR2(50) PATH '$')) j
            WHERE  UPPER(j.st) = UPPER(l_state);
            IF l_state_ok > 0 THEN
                l_met := l_met + 1;
            END IF;
        END IF;

        -- crops array: farmer grows at least one eligible crop
        IF l_has_crops THEN
            l_criteria := l_criteria + 1;
            SELECT COUNT(*)
            INTO   l_crop_ok
            FROM   JSON_TABLE(p_eligibility_json, '$.crops[*]'
                       COLUMNS (cn VARCHAR2(100) PATH '$')) j
            JOIN   farmer_crops fc ON fc.farmer_id = p_farmer_id
                                  AND fc.status = 'ACTIVE'
            JOIN   crops c ON c.crop_id = fc.crop_id
            WHERE  UPPER(c.crop_name) = UPPER(j.cn);
            IF l_crop_ok > 0 THEN
                l_met := l_met + 1;
            END IF;
        END IF;

        -- max_income: no income column in schema; treat as informational only
        -- (counts as a criterion the farmer cannot fail on available data).
        IF l_max_income IS NOT NULL THEN
            l_criteria := l_criteria + 1;
            l_met := l_met + 1;
        END IF;

        IF l_criteria = 0 THEN
            RETURN 0;
        END IF;

        RETURN ROUND((l_met / l_criteria) * 100, 2);
    END score_match;

    FUNCTION match_farmer (
        p_farmer_id IN farmers.farmer_id%TYPE
    ) RETURN NUMBER IS
        l_count NUMBER := 0;
        l_score NUMBER;
    BEGIN
        FOR s IN (
            SELECT scheme_id, eligibility_json
            FROM   government_schemes
            WHERE  is_active = 'Y'
            AND    (deadline IS NULL OR deadline >= TRUNC(SYSDATE))
        ) LOOP
            l_score := score_match(p_farmer_id, s.eligibility_json);
            IF l_score > 0 THEN
                upsert_match(p_farmer_id, s.scheme_id, l_score);
                l_count := l_count + 1;
            END IF;
        END LOOP;
        RETURN l_count;
    END match_farmer;

    PROCEDURE match_all_farmers IS
        l_total NUMBER := 0;
    BEGIN
        FOR f IN (
            SELECT farmer_id
            FROM   farmers
            WHERE  is_active = 'Y'
        ) LOOP
            l_total := l_total + match_farmer(f.farmer_id);
        END LOOP;

        COMMIT;
    END match_all_farmers;

END pkg_scheme_matcher;
/
