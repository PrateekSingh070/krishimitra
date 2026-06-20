-- =============================================================================
-- KrishiMitra :: PKG_PRICE_TRACKER (body)
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_price_tracker AS

    -- Latest price for a crop+mandi on/at-or-before a reference date.
    FUNCTION latest_price (
        p_crop_id    IN mandi_prices.crop_id%TYPE,
        p_mandi_name IN mandi_prices.mandi_name%TYPE,
        p_on_or_before IN DATE
    ) RETURN NUMBER IS
        l_price mandi_prices.price_per_qtl%TYPE;
    BEGIN
        SELECT price_per_qtl
        INTO   l_price
        FROM   (
            SELECT price_per_qtl
            FROM   mandi_prices
            WHERE  crop_id = p_crop_id
            AND    mandi_name = p_mandi_name
            AND    recorded_date <= p_on_or_before
            AND    price_per_qtl IS NOT NULL
            ORDER  BY recorded_date DESC
        )
        WHERE ROWNUM = 1;
        RETURN l_price;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END latest_price;

    FUNCTION crop_name (p_crop_id IN crops.crop_id%TYPE) RETURN VARCHAR2 IS
        l_name crops.crop_name%TYPE;
    BEGIN
        SELECT crop_name INTO l_name FROM crops WHERE crop_id = p_crop_id;
        RETURN l_name;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'crop';
    END crop_name;

    FUNCTION crop_name_hi (p_crop_id IN crops.crop_id%TYPE) RETURN VARCHAR2 IS
        l_name crops.crop_name_hindi%TYPE;
    BEGIN
        SELECT NVL(crop_name_hindi, crop_name) INTO l_name
        FROM crops WHERE crop_id = p_crop_id;
        RETURN l_name;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'फसल';
    END crop_name_hi;

    FUNCTION record_price (
        p_crop_id       IN mandi_prices.crop_id%TYPE,
        p_mandi_name    IN mandi_prices.mandi_name%TYPE,
        p_district      IN mandi_prices.district%TYPE,
        p_state         IN mandi_prices.state%TYPE,
        p_price_per_qtl IN mandi_prices.price_per_qtl%TYPE,
        p_recorded_date IN mandi_prices.recorded_date%TYPE DEFAULT TRUNC(SYSDATE),
        p_source        IN mandi_prices.source%TYPE DEFAULT 'Agmarknet'
    ) RETURN mandi_prices.price_id%TYPE IS
        l_price_id mandi_prices.price_id%TYPE;
    BEGIN
        INSERT INTO mandi_prices (
            crop_id, mandi_name, district, state,
            price_per_qtl, recorded_date, source
        ) VALUES (
            p_crop_id, p_mandi_name, p_district, p_state,
            p_price_per_qtl, p_recorded_date, p_source
        )
        RETURNING price_id INTO l_price_id;

        -- Movement evaluation is best-effort: never fail an ingest because the
        -- alerting path errored.
        BEGIN
            IF evaluate_price_movement(p_crop_id, p_mandi_name, p_district) IS NULL THEN
                NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

        RETURN l_price_id;
    END record_price;

    FUNCTION evaluate_price_movement (
        p_crop_id    IN mandi_prices.crop_id%TYPE,
        p_mandi_name IN mandi_prices.mandi_name%TYPE,
        p_district   IN mandi_prices.district%TYPE
    ) RETURN NUMBER IS
        l_today     NUMBER;
        l_3days_ago NUMBER;
        l_7days_ago NUMBER;
        l_change    NUMBER;
        l_alerts    NUMBER := 0;
    BEGIN
        l_today     := latest_price(p_crop_id, p_mandi_name, TRUNC(SYSDATE));
        l_3days_ago := latest_price(p_crop_id, p_mandi_name, TRUNC(SYSDATE) - 3);
        l_7days_ago := latest_price(p_crop_id, p_mandi_name, TRUNC(SYSDATE) - 7);

        IF l_today IS NULL THEN
            RETURN 0;
        END IF;

        -- PR-01: drop > 15% over 3 days
        IF l_3days_ago IS NOT NULL AND l_3days_ago > 0 THEN
            l_change := ((l_today - l_3days_ago) / l_3days_ago) * 100;
            IF l_change <= -c_drop_pct THEN
                l_alerts := l_alerts + pkg_alerts.generate_alert_for_district(
                    p_alert_type => 'PRICE_DROP',
                    p_district   => p_district,
                    p_message_en => crop_name(p_crop_id) || ' price fell '
                                    || ROUND(ABS(l_change)) || '% in 3 days at '
                                    || p_mandi_name || '. Consider delaying sale.',
                    p_message_hi => crop_name_hi(p_crop_id) || ' का भाव '
                                    || p_mandi_name || ' में 3 दिनों में '
                                    || ROUND(ABS(l_change)) || '% गिरा. बिक्री टालने पर विचार करें.',
                    p_severity   => pkg_alerts.c_sev_medium
                );
            END IF;
        END IF;

        -- PR-02: rise > 20% over 7 days
        IF l_7days_ago IS NOT NULL AND l_7days_ago > 0 THEN
            l_change := ((l_today - l_7days_ago) / l_7days_ago) * 100;
            IF l_change >= c_rise_pct THEN
                l_alerts := l_alerts + pkg_alerts.generate_alert_for_district(
                    p_alert_type => 'PRICE_RISE',
                    p_district   => p_district,
                    p_message_en => crop_name(p_crop_id) || ' price rose '
                                    || ROUND(l_change) || '% in 7 days at '
                                    || p_mandi_name || '. Good time to sell.',
                    p_message_hi => crop_name_hi(p_crop_id) || ' का भाव '
                                    || p_mandi_name || ' में 7 दिनों में '
                                    || ROUND(l_change) || '% बढ़ा. बेचने का अच्छा समय.',
                    p_severity   => pkg_alerts.c_sev_low
                );
            END IF;
        END IF;

        RETURN l_alerts;
    END evaluate_price_movement;

END pkg_price_tracker;
/
