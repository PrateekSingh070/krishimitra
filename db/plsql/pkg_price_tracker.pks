-- =============================================================================
-- KrishiMitra :: PKG_PRICE_TRACKER (specification)
-- Ingest Mandi prices and detect price movements that warrant farmer alerts:
--   PR-01: price drops > 15% over 3 days  -> MEDIUM "delay selling"
--   PR-02: price rises > 20% over 7 days  -> LOW    "opportunity to sell"
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_price_tracker AS

    c_drop_pct CONSTANT NUMBER := 15;   -- % drop over 3 days
    c_rise_pct CONSTANT NUMBER := 20;   -- % rise over 7 days

    -- Insert a single Mandi price observation, then evaluate movement rules
    -- for that crop+mandi. Returns the new price_id.
    FUNCTION record_price (
        p_crop_id       IN mandi_prices.crop_id%TYPE,
        p_mandi_name    IN mandi_prices.mandi_name%TYPE,
        p_district      IN mandi_prices.district%TYPE,
        p_state         IN mandi_prices.state%TYPE,
        p_price_per_qtl IN mandi_prices.price_per_qtl%TYPE,
        p_recorded_date IN mandi_prices.recorded_date%TYPE DEFAULT TRUNC(SYSDATE),
        p_source        IN mandi_prices.source%TYPE DEFAULT 'Agmarknet'
    ) RETURN mandi_prices.price_id%TYPE;

    -- Evaluate drop/rise rules for one crop+mandi using recent history and,
    -- if triggered, fan an alert out to affected farmers (district match).
    -- Returns number of alerts generated.
    FUNCTION evaluate_price_movement (
        p_crop_id    IN mandi_prices.crop_id%TYPE,
        p_mandi_name IN mandi_prices.mandi_name%TYPE,
        p_district   IN mandi_prices.district%TYPE
    ) RETURN NUMBER;

END pkg_price_tracker;
/
