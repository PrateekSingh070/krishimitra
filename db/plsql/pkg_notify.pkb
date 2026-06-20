-- =============================================================================
-- KrishiMitra :: PKG_NOTIFY (body)  [FREE PATH - email via UTL_SMTP]
--
-- Uses UTL_SMTP against a free SMTP relay (OCI Email Delivery free tier, or any
-- free provider). SMTP host/port/sender are read from APP_CONFIG; the SMTP
-- username/password come from a DBMS_CLOUD credential named by EMAIL_CRED_NAME
-- (never hardcoded). If SMTP is not configured the email is skipped silently so
-- the in-app alert (the ALERTS row) is still the source of truth.
--
-- NOTE: ATP also needs a network ACL for the SMTP host + an Email Delivery
-- approved sender. See db/ddl/04_network_acls.sql (add the SMTP host there).
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_notify AS

    -- SMTP auth user/password are read from APP_CONFIG (populated at deploy,
    -- never committed to source). A DBMS_CLOUD credential cannot be used here
    -- because UTL_SMTP AUTH needs the cleartext password and credential secrets
    -- are never readable back. If unset, send_email skips AUTH (open relay) or
    -- silently no-ops, leaving the alert in-app.
    FUNCTION smtp_user RETURN VARCHAR2 IS
    BEGIN
        RETURN app_cfg('EMAIL_SMTP_USER');
    END smtp_user;

    FUNCTION smtp_pwd RETURN VARCHAR2 IS
    BEGIN
        RETURN app_cfg('EMAIL_SMTP_PASSWORD');
    END smtp_pwd;

    PROCEDURE send_email (
        p_to      IN VARCHAR2,
        p_subject IN VARCHAR2,
        p_body    IN VARCHAR2
    ) IS
        l_conn   UTL_SMTP.connection;
        l_host   VARCHAR2(200) := app_cfg('EMAIL_SMTP_HOST');
        l_port   PLS_INTEGER   := TO_NUMBER(NVL(app_cfg('EMAIL_SMTP_PORT'), '587'));
        l_from   VARCHAR2(200) := app_cfg('EMAIL_SENDER');
        l_user   VARCHAR2(400) := smtp_user;
        l_pwd    VARCHAR2(400) := smtp_pwd;
        l_crlf   VARCHAR2(2)   := UTL_TCP.CRLF;
    BEGIN
        IF p_to IS NULL OR l_host IS NULL OR l_from IS NULL THEN
            RETURN;  -- not configured / no recipient -> rely on in-app alert
        END IF;

        l_conn := UTL_SMTP.open_connection(l_host, l_port);
        UTL_SMTP.ehlo(l_conn, l_host);

        -- STARTTLS + AUTH when credentials are present (OCI Email Delivery).
        IF l_user IS NOT NULL THEN
            BEGIN
                UTL_SMTP.starttls(l_conn);
                UTL_SMTP.ehlo(l_conn, l_host);
            EXCEPTION WHEN OTHERS THEN NULL; END;
            UTL_SMTP.command(l_conn, 'AUTH LOGIN');
            UTL_SMTP.command(l_conn, UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(UTL_RAW.cast_to_raw(l_user))));
            UTL_SMTP.command(l_conn, UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(UTL_RAW.cast_to_raw(l_pwd))));
        END IF;

        UTL_SMTP.mail(l_conn, l_from);
        UTL_SMTP.rcpt(l_conn, p_to);
        UTL_SMTP.open_data(l_conn);
        UTL_SMTP.write_data(l_conn, 'From: ' || l_from || l_crlf);
        UTL_SMTP.write_data(l_conn, 'To: ' || p_to || l_crlf);
        UTL_SMTP.write_data(l_conn, 'Subject: ' || p_subject || l_crlf);
        UTL_SMTP.write_data(l_conn, 'Content-Type: text/plain; charset=UTF-8' || l_crlf);
        UTL_SMTP.write_data(l_conn, l_crlf);
        UTL_SMTP.write_data(l_conn, p_body || l_crlf);
        UTL_SMTP.close_data(l_conn);
        UTL_SMTP.quit(l_conn);
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN UTL_SMTP.quit(l_conn); EXCEPTION WHEN OTHERS THEN NULL; END;
            -- Swallow: alert remains in-app; dispatcher will not mark as sent.
            RAISE;
    END send_email;

    FUNCTION farmer_email (
        p_farmer_id IN farmers.farmer_id%TYPE
    ) RETURN VARCHAR2 IS
        l_email farmers.email%TYPE;
    BEGIN
        SELECT email INTO l_email FROM farmers WHERE farmer_id = p_farmer_id;
        RETURN l_email;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END farmer_email;

END pkg_notify;
/
