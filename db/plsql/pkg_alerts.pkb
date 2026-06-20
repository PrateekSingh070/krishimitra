-- =============================================================================
-- KrishiMitra :: PKG_ALERTS (body)
-- =============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_alerts AS

    -- [FREE PATH] Deliver one alert.
    --   EMAIL -> sends a bilingual email via PKG_NOTIFY (free).
    --   APP   -> in-app only; the ALERTS row is shown on the APEX Alerts page
    --            (no outbound call needed).
    --   SMS   -> optional paid path; left for the optional alert-dispatcher
    --            Function to pick up (this DB-side hook is a no-op for SMS).
    -- Returns TRUE when the alert can be marked sent, FALSE if delivery failed
    -- (so it is retried on the next sweep).
    FUNCTION deliver_alert (
        p_alert_id IN alerts.alert_id%TYPE
    ) RETURN BOOLEAN IS
        l_channel alerts.channel%TYPE;
        l_farmer  alerts.farmer_id%TYPE;
        l_sev     alerts.severity%TYPE;
        l_en      alerts.message_en%TYPE;
        l_hi      alerts.message_hi%TYPE;
        l_email   VARCHAR2(150);
    BEGIN
        SELECT channel, farmer_id, severity, message_en, message_hi
        INTO   l_channel, l_farmer, l_sev, l_en, l_hi
        FROM   alerts
        WHERE  alert_id = p_alert_id;

        IF l_channel = c_chan_email THEN
            l_email := pkg_notify.farmer_email(l_farmer);
            IF l_email IS NULL THEN
                -- No address: fall back to in-app (still counts as delivered).
                RETURN TRUE;
            END IF;
            pkg_notify.send_email(
                p_to      => l_email,
                p_subject => 'KrishiMitra Alert [' || l_sev || ']',
                p_body    => l_hi || UTL_TCP.CRLF || UTL_TCP.CRLF || l_en);
            RETURN TRUE;
        ELSIF l_channel = c_chan_app THEN
            RETURN TRUE;  -- in-app only
        ELSE
            -- SMS (optional/paid): not handled DB-side in the free path.
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;  -- leave unsent for retry
    END deliver_alert;

    FUNCTION generate_alert (
        p_alert_type IN  alerts.alert_type%TYPE,
        p_farmer_id  IN  alerts.farmer_id%TYPE,
        p_message_en IN  alerts.message_en%TYPE,
        p_message_hi IN  alerts.message_hi%TYPE,
        p_severity   IN  alerts.severity%TYPE,
        p_channel    IN  alerts.channel%TYPE DEFAULT 'EMAIL'
    ) RETURN alerts.alert_id%TYPE IS
        l_alert_id alerts.alert_id%TYPE;
    BEGIN
        INSERT INTO alerts (
            alert_type, farmer_id, message_en, message_hi,
            severity, is_sent, channel
        ) VALUES (
            p_alert_type, p_farmer_id, p_message_en, p_message_hi,
            p_severity, 'N', p_channel
        )
        RETURNING alert_id INTO l_alert_id;

        RETURN l_alert_id;
    END generate_alert;

    FUNCTION generate_alert_for_district (
        p_alert_type IN  alerts.alert_type%TYPE,
        p_district   IN  farmers.district%TYPE,
        p_message_en IN  alerts.message_en%TYPE,
        p_message_hi IN  alerts.message_hi%TYPE,
        p_severity   IN  alerts.severity%TYPE,
        p_channel    IN  alerts.channel%TYPE DEFAULT 'EMAIL'
    ) RETURN NUMBER IS
        l_count NUMBER := 0;
    BEGIN
        INSERT INTO alerts (
            alert_type, farmer_id, message_en, message_hi,
            severity, is_sent, channel
        )
        SELECT p_alert_type, f.farmer_id, p_message_en, p_message_hi,
               p_severity, 'N', p_channel
        FROM   farmers f
        WHERE  f.district = p_district
        AND    f.is_active = 'Y';

        l_count := SQL%ROWCOUNT;
        RETURN l_count;
    END generate_alert_for_district;

    FUNCTION send_batch (
        p_channel    IN  alerts.channel%TYPE DEFAULT 'EMAIL',
        p_batch_size IN  PLS_INTEGER DEFAULT 1000
    ) RETURN NUMBER IS
        CURSOR c_pending IS
            SELECT a.alert_id
            FROM   alerts a
            WHERE  a.is_sent = 'N'
            AND    a.channel = p_channel
            ORDER  BY a.severity, a.created_at
            FOR UPDATE OF a.is_sent SKIP LOCKED;

        TYPE t_ids IS TABLE OF alerts.alert_id%TYPE;
        l_ids   t_ids;
        l_total NUMBER := 0;
    BEGIN
        OPEN c_pending;
        LOOP
            FETCH c_pending BULK COLLECT INTO l_ids LIMIT p_batch_size;
            EXIT WHEN l_ids.COUNT = 0;

            -- Deliver each alert (email/in-app) and only mark sent on success,
            -- so a transient SMTP failure is retried on the next sweep.
            FOR i IN 1 .. l_ids.COUNT LOOP
                IF deliver_alert(l_ids(i)) THEN
                    UPDATE alerts
                    SET    is_sent = 'Y',
                           sent_at = SYSTIMESTAMP
                    WHERE  alert_id = l_ids(i);
                    l_total := l_total + 1;
                END IF;
            END LOOP;

            COMMIT;  -- commit each batch so SKIP LOCKED lets workers parallelise
        END LOOP;
        CLOSE c_pending;

        RETURN l_total;
    EXCEPTION
        WHEN OTHERS THEN
            IF c_pending%ISOPEN THEN
                CLOSE c_pending;
            END IF;
            RAISE;
    END send_batch;

END pkg_alerts;
/
