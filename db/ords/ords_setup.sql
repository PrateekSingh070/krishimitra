-- =============================================================================
-- KrishiMitra :: ORDS REST enablement + module definition
-- File: ords_setup.sql
-- Run as the KRISHIMITRA schema owner (the schema that owns the tables).
--
-- Defines the "krishimitra" REST module (base path /krishimitra/) with:
--   POST/GET  disease_scans/        - target of the OCI Vision "disease-classifier"
--                                      Function and the APEX disease-scanner page
--   GET       disease_scans/:id
--   GET       mandi_prices/         - current prices feed for the Market page
--   GET       schemes/:farmer_id    - personalised, ranked scheme list
--
-- All handlers run with the schema's privileges. Public exposure is gated by
-- OCI API Gateway (OAuth2/JWT) per the security requirements; ORDS itself can
-- additionally be protected with a privilege (see the commented OAUTH block).
-- =============================================================================

-- 1. Enable ORDS for this schema (idempotent).
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'krishimitra',
        p_auto_rest_auth      => TRUE
    );
    COMMIT;
END;
/

-- 2. Define the module + templates + handlers.
BEGIN
    -- Clean slate so the script is re-runnable.
    BEGIN
        ORDS.DELETE_MODULE(p_module_name => 'krishimitra.api');
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    ORDS.DEFINE_MODULE(
        p_module_name    => 'krishimitra.api',
        p_base_path      => '/api/v1/',
        p_items_per_page => 50,
        p_status         => 'PUBLISHED',
        p_comments       => 'KrishiMitra core REST module.'
    );

    ---------------------------------------------------------------------------
    -- disease_scans collection: POST (create from Function) + GET (list)
    ---------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'disease_scans/'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'disease_scans/',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
            DECLARE
                l_scan_id disease_scans.scan_id%TYPE;
            BEGIN
                INSERT INTO disease_scans (
                    farmer_id, farmer_crop_id, image_url, disease_detected,
                    confidence_score, severity, treatment_advice, treatment_hindi,
                    oci_vision_req
                ) VALUES (
                    :farmer_id, :farmer_crop_id, :image_url, :disease_detected,
                    :confidence_score, :severity, :treatment_advice, :treatment_hindi,
                    :oci_vision_req
                ) RETURNING scan_id INTO l_scan_id;

                COMMIT;
                :status   := 201;
                :scan_id  := l_scan_id;
            END;
        ]'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'disease_scans/',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
            SELECT scan_id, farmer_id, farmer_crop_id, image_url,
                   disease_detected, confidence_score, severity,
                   scan_timestamp
            FROM   disease_scans
            ORDER  BY scan_timestamp DESC
        ]'
    );

    ---------------------------------------------------------------------------
    -- disease_scans/:id  -> single scan with full (CLOB) treatment text
    ---------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'disease_scans/:id'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'disease_scans/:id',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_query_one_row,
        p_source      => q'[
            SELECT scan_id, farmer_id, farmer_crop_id, image_url,
                   disease_detected, confidence_score, severity,
                   treatment_advice, treatment_hindi, scan_timestamp,
                   oci_vision_req
            FROM   disease_scans
            WHERE  scan_id = :id
        ]'
    );

    ---------------------------------------------------------------------------
    -- mandi_prices/  -> latest price per crop+mandi (Market page)
    ---------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'mandi_prices/'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'mandi_prices/',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
            SELECT mp.price_id, c.crop_name, c.crop_name_hindi,
                   mp.mandi_name, mp.district, mp.state,
                   mp.price_per_qtl, mp.recorded_date
            FROM   mandi_prices mp
            JOIN   crops c ON c.crop_id = mp.crop_id
            WHERE  mp.recorded_date = (
                       SELECT MAX(mp2.recorded_date)
                       FROM   mandi_prices mp2
                       WHERE  mp2.crop_id = mp.crop_id
                       AND    mp2.mandi_name = mp.mandi_name
                   )
            ORDER  BY c.crop_name, mp.mandi_name
        ]'
    );

    ---------------------------------------------------------------------------
    -- schemes/:farmer_id  -> personalised ranked scheme list (Scheme Finder)
    ---------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'schemes/:farmer_id'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name => 'krishimitra.api',
        p_pattern     => 'schemes/:farmer_id',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
            SELECT gs.scheme_id, gs.scheme_name, gs.scheme_name_hi,
                   gs.ministry, gs.benefit_amount, gs.apply_url, gs.deadline,
                   sm.match_score
            FROM   scheme_matches sm
            JOIN   government_schemes gs ON gs.scheme_id = sm.scheme_id
            WHERE  sm.farmer_id = :farmer_id
            AND    gs.is_active = 'Y'
            ORDER  BY sm.match_score DESC
        ]'
    );

    COMMIT;
END;
/

-- 3. (Optional) Protect the module with an OAuth2 privilege. Enable in PROD;
-- API Gateway already enforces JWT, so this is defence-in-depth.
--
-- BEGIN
--     ORDS.DEFINE_PRIVILEGE(
--         p_privilege_name => 'krishimitra.api.priv',
--         p_roles          => ORDS_TYPES.T_ORDS_NAMES('krishimitra_api_role'),
--         p_patterns       => ORDS_TYPES.T_ORDS_NAMES('/api/v1/*'),
--         p_modules        => ORDS_TYPES.T_ORDS_NAMES('krishimitra.api'),
--         p_label          => 'KrishiMitra API',
--         p_description     => 'Protects all KrishiMitra REST endpoints.'
--     );
--     COMMIT;
-- END;
-- /
