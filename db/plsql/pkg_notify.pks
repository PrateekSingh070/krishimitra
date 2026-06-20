-- =============================================================================
-- KrishiMitra :: PKG_NOTIFY (specification)  [FREE PATH]
-- Free notification delivery: email via UTL_SMTP (OCI Email Delivery free tier
-- or any free SMTP). In-app delivery is simply the ALERTS row, surfaced on the
-- APEX Alerts page, so it needs no outbound call.
--
-- Replaces the paid SMS (Fast2SMS) path. SMS remains available behind the
-- 'SMS' channel for callers who opt in (handled by the optional dispatcher).
-- =============================================================================
CREATE OR REPLACE PACKAGE pkg_notify AS

    -- Send one email. SMTP host/port/sender come from APP_CONFIG; credentials
    -- (if the SMTP server requires auth) come from a DBMS_CLOUD credential.
    PROCEDURE send_email (
        p_to      IN VARCHAR2,
        p_subject IN VARCHAR2,
        p_body    IN VARCHAR2
    );

    -- Resolve a farmer's email (placeholder: farmers table has phone, not email;
    -- in the free path the email is derived/stored per farmer. Returns NULL if
    -- none, in which case the alert stays in-app only).
    FUNCTION farmer_email (
        p_farmer_id IN farmers.farmer_id%TYPE
    ) RETURN VARCHAR2;

END pkg_notify;
/
