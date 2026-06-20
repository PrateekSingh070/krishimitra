-- =============================================================================
-- KrishiMitra :: TRG_DISEASE_SCAN_ALERT
-- After a disease scan is recorded, auto-generate a farmer alert when the
-- detected severity is HIGH or CRITICAL (rule DS-01). The alert is created in
-- an autonomous transaction so the scan insert is never blocked or rolled back
-- by alert-side issues, and to avoid mutating-table concerns.
-- Depends on: PKG_ALERTS.
-- =============================================================================
CREATE OR REPLACE TRIGGER trg_disease_scan_alert
AFTER INSERT ON disease_scans
FOR EACH ROW
WHEN (NEW.severity IN ('HIGH', 'CRITICAL'))
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_alert_id  alerts.alert_id%TYPE;
    l_severity  alerts.severity%TYPE;
    l_disease   VARCHAR2(200);
BEGIN
    l_disease  := NVL(:NEW.disease_detected, 'a crop disease');
    l_severity := CASE :NEW.severity
                      WHEN 'CRITICAL' THEN pkg_alerts.c_sev_critical
                      ELSE pkg_alerts.c_sev_high
                  END;

    l_alert_id := pkg_alerts.generate_alert(
        p_alert_type => 'DISEASE',
        p_farmer_id  => :NEW.farmer_id,
        p_message_en => 'Disease detected: ' || l_disease
                        || ' (severity ' || :NEW.severity
                        || '). Consult your agriculture officer immediately.',
        p_message_hi => 'रोग पाया गया: ' || l_disease
                        || ' (गंभीरता ' || :NEW.severity
                        || '). तुरंत कृषि अधिकारी से संपर्क करें.',
        p_severity   => l_severity,
        p_channel    => pkg_alerts.c_chan_email
    );

    COMMIT;  -- autonomous transaction commit
END;
/
