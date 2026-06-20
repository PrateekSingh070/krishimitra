-- =============================================================================
-- KrishiMitra :: utPLSQL test suite for PKG_SCHEME_MATCHER
-- Requires utPLSQL v3 installed in the database (https://utplsql.org).
-- Run with:  ut.run('test_pkg_scheme_matcher');
--
-- The suite seeds an isolated farmer + scheme, asserts scoring behaviour, and
-- rolls back via the utPLSQL --%rollback(manual) + explicit cleanup pattern.
-- =============================================================================
CREATE OR REPLACE PACKAGE test_pkg_scheme_matcher AS
    --%suite(PKG_SCHEME_MATCHER eligibility scoring)

    --%context(score_match)

    --%test(Full match on land + state returns 100)
    PROCEDURE full_match_scores_100;

    --%test(Out-of-range land lowers the score)
    PROCEDURE partial_match_lowers_score;

    --%test(Null eligibility json scores 0)
    PROCEDURE null_json_scores_zero;

    --%endcontext

    --%afterall
    PROCEDURE cleanup;
END test_pkg_scheme_matcher;
/

CREATE OR REPLACE PACKAGE BODY test_pkg_scheme_matcher AS

    g_farmer_id farmers.farmer_id%TYPE;

    FUNCTION ensure_farmer RETURN farmers.farmer_id%TYPE IS
    BEGIN
        IF g_farmer_id IS NULL THEN
            g_farmer_id := pkg_farmer.register_farmer(
                p_name       => 'UT Tester',
                p_phone      => '99999000001',
                p_state      => 'UP',
                p_land_acres => 3
            );
        END IF;
        RETURN g_farmer_id;
    END ensure_farmer;

    PROCEDURE full_match_scores_100 IS
        l_score NUMBER;
    BEGIN
        l_score := pkg_scheme_matcher.score_match(
            p_farmer_id        => ensure_farmer,
            p_eligibility_json => '{"min_land": 1, "max_land": 5, "states": ["UP","MP"]}'
        );
        ut.expect(l_score).to_equal(100);
    END full_match_scores_100;

    PROCEDURE partial_match_lowers_score IS
        l_score NUMBER;
    BEGIN
        -- farmer has 3 acres + UP. max_land:2 fails, so 2 of 3 criteria met.
        l_score := pkg_scheme_matcher.score_match(
            p_farmer_id        => ensure_farmer,
            p_eligibility_json => '{"min_land": 1, "max_land": 2, "states": ["UP"]}'
        );
        ut.expect(l_score).to_be_less_than(100);
        ut.expect(l_score).to_be_greater_than(0);
    END partial_match_lowers_score;

    PROCEDURE null_json_scores_zero IS
        l_score NUMBER;
    BEGIN
        l_score := pkg_scheme_matcher.score_match(ensure_farmer, NULL);
        ut.expect(l_score).to_equal(0);
    END null_json_scores_zero;

    PROCEDURE cleanup IS
    BEGIN
        IF g_farmer_id IS NOT NULL THEN
            DELETE FROM scheme_matches WHERE farmer_id = g_farmer_id;
            DELETE FROM alerts         WHERE farmer_id = g_farmer_id;
            DELETE FROM farmers        WHERE farmer_id = g_farmer_id;
            COMMIT;
        END IF;
    END cleanup;

END test_pkg_scheme_matcher;
/
