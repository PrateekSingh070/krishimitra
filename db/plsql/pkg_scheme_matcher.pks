-- =============================================================================
-- KrishiMitra :: PKG_SCHEME_MATCHER (specification)
-- Evaluate each active scheme's eligibility_json against every farmer,
-- compute a 0-100 match_score, upsert SCHEME_MATCHES, and raise alerts for
-- new high-confidence matches (score > 80).
--
-- eligibility_json shape (all keys optional):
--   {
--     "min_land": 1, "max_land": 5,
--     "states":  ["UP","MP"],
--     "crops":   ["wheat","rice"],
--     "max_income": 200000
--   }
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_scheme_matcher AS

    -- High-confidence threshold above which a farmer is alerted automatically.
    c_alert_threshold CONSTANT NUMBER := 80;

    -- Score one farmer against one scheme's eligibility JSON (0-100).
    FUNCTION score_match (
        p_farmer_id       IN farmers.farmer_id%TYPE,
        p_eligibility_json IN CLOB
    ) RETURN NUMBER;

    -- Match a single farmer against all active schemes (used on profile update).
    -- Returns number of matches upserted.
    FUNCTION match_farmer (
        p_farmer_id IN farmers.farmer_id%TYPE
    ) RETURN NUMBER;

    -- Match every active farmer against every active, non-expired scheme.
    -- Invoked nightly by JOB_SCHEME_MATCH_DAILY.
    PROCEDURE match_all_farmers;

END pkg_scheme_matcher;
/
