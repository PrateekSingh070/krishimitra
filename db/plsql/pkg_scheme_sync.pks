-- =============================================================================
-- KrishiMitra :: PKG_SCHEME_SYNC (specification)  [FREE PATH]
-- Replaces OIC INT-03. Pulls government scheme data from data.gov.in (free key)
-- via APEX_WEB_SERVICE, upserts GOVERNMENT_SCHEMES, deactivates expired schemes.
-- Invoked by JOB_SCHEME_SYNC.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_scheme_sync AS

    -- Build the eligibility_json string from discrete source fields.
    FUNCTION build_eligibility_json (
        p_min_land   IN NUMBER,
        p_max_land   IN NUMBER,
        p_states_csv IN VARCHAR2,
        p_crops_csv  IN VARCHAR2,
        p_max_income IN NUMBER
    ) RETURN VARCHAR2;

    -- Fetch + upsert schemes; deactivate past-deadline ones. Returns upserts.
    PROCEDURE run;

END pkg_scheme_sync;
/
