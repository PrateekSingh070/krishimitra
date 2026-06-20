-- =============================================================================
-- KrishiMitra :: PKG_FARMER (specification)
-- CRUD for farmer registration & profile management.
-- Aadhaar is only ever stored as a SHA-256 hash (security req #5).
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_farmer AS

    e_duplicate_phone EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_duplicate_phone, -20001);

    e_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_not_found, -20002);

    -- Hash a raw Aadhaar number to its hex SHA-256 digest. Exposed so the API
    -- layer can hash before transmitting, but also used internally.
    FUNCTION hash_aadhaar (
        p_aadhaar_raw IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Register a new farmer. p_aadhaar_raw is hashed; the raw value is discarded.
    -- Raises e_duplicate_phone (-20001) if the phone already exists.
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
    ) RETURN farmers.farmer_id%TYPE;

    -- Update mutable profile fields. NULL arguments leave the column unchanged.
    -- Raises e_not_found (-20002) if the farmer does not exist.
    PROCEDURE update_farmer (
        p_farmer_id      IN farmers.farmer_id%TYPE,
        p_name           IN farmers.name%TYPE DEFAULT NULL,
        p_state          IN farmers.state%TYPE DEFAULT NULL,
        p_district       IN farmers.district%TYPE DEFAULT NULL,
        p_village        IN farmers.village%TYPE DEFAULT NULL,
        p_land_acres     IN farmers.land_acres%TYPE DEFAULT NULL,
        p_soil_type      IN farmers.soil_type%TYPE DEFAULT NULL,
        p_preferred_lang IN farmers.preferred_lang%TYPE DEFAULT NULL
    );

    -- Return a single farmer row as a REF CURSOR for the API / ORDS layer.
    FUNCTION get_farmer (
        p_farmer_id IN farmers.farmer_id%TYPE
    ) RETURN SYS_REFCURSOR;

    -- Soft-deactivate (is_active = 'N'). Raises e_not_found if missing.
    PROCEDURE deactivate_farmer (
        p_farmer_id IN farmers.farmer_id%TYPE
    );

END pkg_farmer;
/
