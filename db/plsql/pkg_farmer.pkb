-- =============================================================================
-- KrishiMitra :: PKG_FARMER (body)
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_farmer AS

    FUNCTION hash_aadhaar (
        p_aadhaar_raw IN VARCHAR2
    ) RETURN VARCHAR2 IS
        l_hash_raw RAW(32);
    BEGIN
        IF p_aadhaar_raw IS NULL THEN
            RETURN NULL;
        END IF;

        l_hash_raw := DBMS_CRYPTO.HASH(
            src => UTL_I18N.STRING_TO_RAW(p_aadhaar_raw, 'AL32UTF8'),
            typ => DBMS_CRYPTO.HASH_SH256
        );

        RETURN LOWER(RAWTOHEX(l_hash_raw));
    END hash_aadhaar;

    FUNCTION register_farmer (
        p_name           IN farmers.name%TYPE,
        p_phone          IN farmers.phone%TYPE,
        p_aadhaar_raw    IN VARCHAR2 DEFAULT NULL,
        p_state          IN farmers.state%TYPE DEFAULT NULL,
        p_district       IN farmers.district%TYPE DEFAULT NULL,
        p_village        IN farmers.village%TYPE DEFAULT NULL,
        p_land_acres     IN farmers.land_acres%TYPE DEFAULT NULL,
        p_soil_type      IN farmers.soil_type%TYPE DEFAULT NULL,
        p_preferred_lang IN farmers.preferred_lang%TYPE DEFAULT 'hi'
    ) RETURN farmers.farmer_id%TYPE IS
        l_farmer_id farmers.farmer_id%TYPE;
    BEGIN
        INSERT INTO farmers (
            name, phone, aadhaar_hash, state, district, village,
            land_acres, soil_type, preferred_lang, is_active
        ) VALUES (
            p_name, p_phone, hash_aadhaar(p_aadhaar_raw), p_state, p_district,
            p_village, p_land_acres, p_soil_type, NVL(p_preferred_lang, 'hi'), 'Y'
        )
        RETURNING farmer_id INTO l_farmer_id;

        RETURN l_farmer_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20001,
                'A farmer with phone ' || p_phone || ' already exists.');
    END register_farmer;

    PROCEDURE update_farmer (
        p_farmer_id      IN farmers.farmer_id%TYPE,
        p_name           IN farmers.name%TYPE DEFAULT NULL,
        p_state          IN farmers.state%TYPE DEFAULT NULL,
        p_district       IN farmers.district%TYPE DEFAULT NULL,
        p_village        IN farmers.village%TYPE DEFAULT NULL,
        p_land_acres     IN farmers.land_acres%TYPE DEFAULT NULL,
        p_soil_type      IN farmers.soil_type%TYPE DEFAULT NULL,
        p_preferred_lang IN farmers.preferred_lang%TYPE DEFAULT NULL
    ) IS
    BEGIN
        UPDATE farmers
        SET    name           = NVL(p_name, name),
               state          = NVL(p_state, state),
               district       = NVL(p_district, district),
               village        = NVL(p_village, village),
               land_acres     = NVL(p_land_acres, land_acres),
               soil_type      = NVL(p_soil_type, soil_type),
               preferred_lang = NVL(p_preferred_lang, preferred_lang)
        WHERE  farmer_id = p_farmer_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Farmer ' || p_farmer_id || ' not found.');
        END IF;
    END update_farmer;

    FUNCTION get_farmer (
        p_farmer_id IN farmers.farmer_id%TYPE
    ) RETURN SYS_REFCURSOR IS
        l_rc SYS_REFCURSOR;
    BEGIN
        OPEN l_rc FOR
            SELECT farmer_id, name, phone, state, district, village,
                   land_acres, soil_type, preferred_lang, is_active,
                   created_at, updated_at
            FROM   farmers
            WHERE  farmer_id = p_farmer_id;
        RETURN l_rc;
    END get_farmer;

    PROCEDURE deactivate_farmer (
        p_farmer_id IN farmers.farmer_id%TYPE
    ) IS
    BEGIN
        UPDATE farmers
        SET    is_active = 'N'
        WHERE  farmer_id = p_farmer_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Farmer ' || p_farmer_id || ' not found.');
        END IF;
    END deactivate_farmer;

END pkg_farmer;
/
