-- =============================================================================
-- KrishiMitra :: Seed - bulk synthetic activity data
-- Generates:
--   * 1,000 farmers across 20 districts of UP / MP / Punjab
--   * 1-2 active farmer_crops per farmer
--   * ~500 disease scans with known outcomes (HIGH/CRITICAL ones fire alerts)
--   * 365 days of Mandi prices for 10 crops across a few mandis
--
-- Run AFTER 01_crops_seed.sql and the DDL/PLSQL. Re-runnable: it first clears
-- previously generated synthetic rows (phones in the 9000000xxx test range).
-- =============================================================================
SET DEFINE OFF;
SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------------------
-- Clean up prior synthetic data (idempotent reseed). Order respects FKs.
-- Test farmers use phone prefix '90000' so we never touch real records.
-- ---------------------------------------------------------------------------
DECLARE
    TYPE t_ids IS TABLE OF NUMBER;
    l_farmers t_ids;
BEGIN
    SELECT farmer_id BULK COLLECT INTO l_farmers
    FROM   farmers WHERE phone LIKE '90000%';

    IF l_farmers.COUNT > 0 THEN
        DELETE FROM alerts          WHERE farmer_id IN (SELECT * FROM TABLE(l_farmers));
        DELETE FROM scheme_matches  WHERE farmer_id IN (SELECT * FROM TABLE(l_farmers));
        DELETE FROM disease_scans   WHERE farmer_id IN (SELECT * FROM TABLE(l_farmers));
        DELETE FROM ml_predictions  WHERE farmer_crop_id IN
            (SELECT farmer_crop_id FROM farmer_crops
             WHERE farmer_id IN (SELECT * FROM TABLE(l_farmers)));
        DELETE FROM farmer_crops    WHERE farmer_id IN (SELECT * FROM TABLE(l_farmers));
        DELETE FROM farmers         WHERE farmer_id IN (SELECT * FROM TABLE(l_farmers));
    END IF;
    -- Synthetic mandi prices use source 'SEED'
    DELETE FROM mandi_prices WHERE source = 'SEED';
    COMMIT;
END;
/

-- ---------------------------------------------------------------------------
-- 1,000 farmers + their crops
-- ---------------------------------------------------------------------------
DECLARE
    TYPE t_str  IS TABLE OF VARCHAR2(50);

    l_states    t_str := t_str('UP','UP','UP','UP','UP','UP','UP',
                                'MP','MP','MP','MP','MP','MP',
                                'Punjab','Punjab','Punjab','Punjab','Punjab','Punjab','Punjab');
    l_districts t_str := t_str('Lucknow','Kanpur','Varanasi','Agra','Meerut','Gorakhpur','Bareilly',
                               'Bhopal','Indore','Jabalpur','Gwalior','Ujjain','Sagar',
                               'Ludhiana','Amritsar','Patiala','Jalandhar','Bathinda','Mohali','Ferozepur');
    l_soils     t_str := t_str('Sandy','Loamy','Clay','Black','Silt');
    l_names     t_str := t_str('Ramesh','Suresh','Lakshmi','Anita','Vijay','Sunita','Mohan',
                               'Gita','Rajesh','Kavita','Arjun','Pooja','Dinesh','Meena',
                               'Harpreet','Gurpreet','Simran','Manjeet','Balwinder','Karan');

    l_crop_ids  SYS.ODCINUMBERLIST;
    l_idx       PLS_INTEGER;
    l_farmer_id farmers.farmer_id%TYPE;
    l_land      NUMBER;
    l_crop_id   NUMBER;
    l_n_crops   PLS_INTEGER;
BEGIN
    SELECT crop_id BULK COLLECT INTO l_crop_ids FROM crops;

    IF l_crop_ids.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20100, 'Run 01_crops_seed.sql before this script.');
    END IF;

    FOR i IN 1 .. 1000 LOOP
        l_idx  := MOD(i, l_districts.COUNT) + 1;
        l_land := ROUND(DBMS_RANDOM.VALUE(0.5, 12), 2);

        INSERT INTO farmers (
            name, phone, aadhaar_hash, state, district, village,
            land_acres, soil_type, preferred_lang, is_active
        ) VALUES (
            l_names(MOD(i, l_names.COUNT) + 1) || ' #' || i,
            '90000' || LPAD(TO_CHAR(i), 5, '0'),
            -- store a SHA-256 hash of a fake aadhaar; never the raw value
            LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
                UTL_I18N.STRING_TO_RAW('AADHAAR-' || i, 'AL32UTF8'),
                DBMS_CRYPTO.HASH_SH256))),
            l_states(l_idx),
            l_districts(l_idx),
            'Village-' || MOD(i, 50),
            l_land,
            l_soils(MOD(i, l_soils.COUNT) + 1),
            CASE WHEN MOD(i, 4) = 0 THEN 'en' ELSE 'hi' END,
            'Y'
        ) RETURNING farmer_id INTO l_farmer_id;

        -- 1-2 active crops per farmer
        l_n_crops := 1 + MOD(i, 2);
        FOR j IN 1 .. l_n_crops LOOP
            l_crop_id := l_crop_ids(MOD(i + j, l_crop_ids.COUNT) + 1);
            INSERT INTO farmer_crops (
                farmer_id, crop_id, sowing_date, expected_harvest,
                plot_acres, season, status
            ) VALUES (
                l_farmer_id, l_crop_id,
                TRUNC(SYSDATE) - DBMS_RANDOM.VALUE(10, 90),
                TRUNC(SYSDATE) + DBMS_RANDOM.VALUE(30, 120),
                ROUND(l_land / l_n_crops, 2),
                CASE WHEN MOD(i, 3) = 0 THEN 'Kharif'
                     WHEN MOD(i, 3) = 1 THEN 'Rabi' ELSE 'Zaid' END,
                'ACTIVE'
            );
        END LOOP;

        IF MOD(i, 200) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Inserted 1000 farmers + crops.');
END;
/

-- ---------------------------------------------------------------------------
-- ~500 disease scans with known outcomes
-- ---------------------------------------------------------------------------
DECLARE
    TYPE t_str IS TABLE OF VARCHAR2(200);
    l_diseases t_str := t_str(
        'Tomato Late Blight','Wheat Leaf Rust','Rice Blast','Potato Early Blight',
        'Cotton Bacterial Blight','Maize Common Rust','Soybean Mosaic Virus','Healthy');
    l_sev      t_str := t_str('LOW','MEDIUM','HIGH','CRITICAL');

    l_farmer_id farmers.farmer_id%TYPE;
    l_fc_id     farmer_crops.farmer_crop_id%TYPE;
    l_d         PLS_INTEGER;
    l_s         PLS_INTEGER;
BEGIN
    FOR i IN 1 .. 500 LOOP
        -- pick a random seeded farmer + one of their crops
        SELECT f.farmer_id, fc.farmer_crop_id
        INTO   l_farmer_id, l_fc_id
        FROM   (SELECT farmer_id FROM farmers WHERE phone LIKE '90000%'
                ORDER BY DBMS_RANDOM.VALUE FETCH FIRST 1 ROW ONLY) f
        JOIN   farmer_crops fc ON fc.farmer_id = f.farmer_id
        FETCH FIRST 1 ROW ONLY;

        l_d := MOD(i, l_diseases.COUNT) + 1;
        l_s := MOD(i, l_sev.COUNT) + 1;

        INSERT INTO disease_scans (
            farmer_id, farmer_crop_id, image_url, disease_detected,
            confidence_score, severity, treatment_advice, treatment_hindi,
            scan_timestamp, oci_vision_req
        ) VALUES (
            l_farmer_id, l_fc_id,
            'https://objectstorage.ap-mumbai-1.oraclecloud.com/n/krishimitra/b/disease-scans/o/scan_' || i || '.jpg',
            l_diseases(l_d),
            ROUND(DBMS_RANDOM.VALUE(70, 99), 2),
            CASE WHEN l_diseases(l_d) = 'Healthy' THEN 'LOW' ELSE l_sev(l_s) END,
            'Apply recommended fungicide; remove affected leaves; ensure proper drainage.',
            'अनुशंसित फफूंदनाशक का छिड़काव करें; प्रभावित पत्तियाँ हटाएँ; जल निकासी सुनिश्चित करें.',
            TRUNC(SYSDATE) - DBMS_RANDOM.VALUE(0, 180),
            'ocid1.visionreq.seed.' || i
        );

        IF MOD(i, 100) = 0 THEN
            COMMIT;  -- trigger may have created alerts; commit periodically
        END IF;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Inserted 500 disease scans (HIGH/CRITICAL fired alerts via trigger).');
END;
/

-- ---------------------------------------------------------------------------
-- 365 days of Mandi prices for 10 crops across 3 mandis
-- Uses a random-walk so PR-01/PR-02 movement rules can trigger realistically.
-- ---------------------------------------------------------------------------
DECLARE
    TYPE t_str IS TABLE OF VARCHAR2(100);
    l_mandis    t_str := t_str('Azadpur Mandi','Indore Mandi','Khanna Mandi');
    l_districts t_str := t_str('Delhi','Indore','Ludhiana');
    l_states    t_str := t_str('Delhi','MP','Punjab');

    l_crop_ids  SYS.ODCINUMBERLIST;
    l_base      NUMBER;
    l_price     NUMBER;
BEGIN
    SELECT crop_id BULK COLLECT INTO l_crop_ids
    FROM   crops FETCH FIRST 10 ROWS ONLY;

    FOR ci IN 1 .. l_crop_ids.COUNT LOOP
        FOR mi IN 1 .. l_mandis.COUNT LOOP
            l_base  := DBMS_RANDOM.VALUE(1500, 6000);   -- per quintal
            l_price := l_base;
            FOR d IN REVERSE 0 .. 364 LOOP
                -- random walk +/- 4% per day, floored
                l_price := GREATEST(300,
                            l_price * (1 + DBMS_RANDOM.VALUE(-0.04, 0.04)));
                INSERT INTO mandi_prices (
                    crop_id, mandi_name, district, state,
                    price_per_qtl, recorded_date, source
                ) VALUES (
                    l_crop_ids(ci), l_mandis(mi), l_districts(mi), l_states(mi),
                    ROUND(l_price, 2), TRUNC(SYSDATE) - d, 'SEED'
                );
            END LOOP;
        END LOOP;
        COMMIT;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Inserted 365 days of Mandi prices for 10 crops x 3 mandis.');
END;
/

-- ---------------------------------------------------------------------------
-- Run an initial scheme match pass so the Scheme Finder has data immediately.
-- ---------------------------------------------------------------------------
BEGIN
    pkg_scheme_matcher.match_all_farmers;
    DBMS_OUTPUT.PUT_LINE('Scheme matching complete.');
END;
/
