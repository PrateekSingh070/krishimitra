-- =============================================================================
-- KrishiMitra :: PKG_ALERTS (specification)
-- Generate alerts, batch-dispatch via email (free) + in-app, mark sent.
-- Default channel is EMAIL (free). 'APP' = in-app only (no outbound). 'SMS' is
-- the optional paid path (handled by the optional alert-dispatcher Function).
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_alerts AS

    -- Severity / type / channel constants (mirror the table CHECK constraints).
    c_sev_low      CONSTANT VARCHAR2(20) := 'LOW';
    c_sev_medium   CONSTANT VARCHAR2(20) := 'MEDIUM';
    c_sev_high     CONSTANT VARCHAR2(20) := 'HIGH';
    c_sev_critical CONSTANT VARCHAR2(20) := 'CRITICAL';

    c_chan_sms     CONSTANT VARCHAR2(20) := 'SMS';
    c_chan_email   CONSTANT VARCHAR2(20) := 'EMAIL';
    c_chan_app     CONSTANT VARCHAR2(20) := 'APP';

    -- Create a single alert row (is_sent defaults to 'N'). Returns the new id.
    FUNCTION generate_alert (
        p_alert_type IN  alerts.alert_type%TYPE,
        p_farmer_id  IN  alerts.farmer_id%TYPE,
        p_message_en IN  alerts.message_en%TYPE,
        p_message_hi IN  alerts.message_hi%TYPE,
        p_severity   IN  alerts.severity%TYPE,
        p_channel    IN  alerts.channel%TYPE DEFAULT 'EMAIL'
    ) RETURN alerts.alert_id%TYPE;

    -- Fan an alert out to every active farmer in a district (used by the
    -- weather/pest early-warning rules). Returns number of alerts inserted.
    FUNCTION generate_alert_for_district (
        p_alert_type IN  alerts.alert_type%TYPE,
        p_district   IN  farmers.district%TYPE,
        p_message_en IN  alerts.message_en%TYPE,
        p_message_hi IN  alerts.message_hi%TYPE,
        p_severity   IN  alerts.severity%TYPE,
        p_channel    IN  alerts.channel%TYPE DEFAULT 'EMAIL'
    ) RETURN NUMBER;

    -- Batch-dispatch all pending (is_sent='N') alerts for a channel. For EMAIL
    -- the message is sent via PKG_NOTIFY (free); for APP it is in-app only.
    -- Rows are marked sent only on successful delivery, in commit-sized batches.
    -- Returns the count of alerts marked sent.
    FUNCTION send_batch (
        p_channel    IN  alerts.channel%TYPE DEFAULT 'EMAIL',
        p_batch_size IN  PLS_INTEGER DEFAULT 1000
    ) RETURN NUMBER;

END pkg_alerts;
/
