-- =============================================================================
-- KrishiMitra :: PKG_MANDI_SYNC (specification)  [FREE PATH]
-- Replaces OIC INT-02. Pulls Mandi prices from Agmarknet (data.gov.in, free
-- key) via APEX_WEB_SERVICE and feeds PKG_PRICE_TRACKER. Invoked by JOB_MANDI_SYNC.
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_mandi_sync AS

    -- Fetch a page of Agmarknet records and insert matched crops into
    -- MANDI_PRICES via PKG_PRICE_TRACKER.record_price. Returns rows inserted.
    FUNCTION sync_page (
        p_offset IN PLS_INTEGER DEFAULT 0,
        p_limit  IN PLS_INTEGER DEFAULT 100
    ) RETURN NUMBER;

    -- Pull up to p_max_records (paged) for the latest available date.
    PROCEDURE run (
        p_max_records IN PLS_INTEGER DEFAULT 1000
    );

END pkg_mandi_sync;
/
