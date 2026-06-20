"""OCI Function: alert-dispatcher.  [FREE PATH]

Default behaviour: query Oracle ATP for pending (is_sent='N') EMAIL alerts and
deliver them over SMTP (OCI Email Delivery free tier or any free SMTP relay),
then mark them sent. In-app ('APP') alerts need no outbound call — they are the
ALERTS rows shown on the APEX Alerts page — so this Function only handles EMAIL.

Note: the database job JOB_ALERT_DISPATCH (db/plsql/jobs.sql) already performs
this same email dispatch on a 15-minute schedule, so in the pure free path this
Function is OPTIONAL. It exists for environments that prefer dispatching from a
Function (e.g. on a different cadence or trigger).

The paid OCI Streaming + Fast2SMS variant is preserved in
func_stream_optional.py.

No secrets in code: the DB password / SMTP password come from OCI Vault (via the
resource principal) or Function config injected at deploy time.
"""
from __future__ import annotations

import json
import logging
import os
import smtplib
from email.mime.text import MIMEText

import dispatch_logic as dol

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("alert-dispatcher")

try:  # pragma: no cover - runtime only
    import oci
    import oracledb
    from fdk import response
except Exception:  # pragma: no cover
    oci = None
    oracledb = None
    response = None


def _signer():  # pragma: no cover
    return oci.auth.signers.get_resource_principals_signer()


def _secret(signer, secret_ocid: str) -> str:  # pragma: no cover
    import base64

    client = oci.secrets.SecretsClient(config={}, signer=signer)
    bundle = client.get_secret_bundle(secret_id=secret_ocid).data
    return base64.b64decode(bundle.secret_bundle_content.content).decode("utf-8")


def _db_connect(signer):  # pragma: no cover
    pwd_secret = os.environ.get("DB_PASSWORD_SECRET_OCID")
    pwd = _secret(signer, pwd_secret) if pwd_secret else os.environ["DB_PASSWORD"]
    return oracledb.connect(
        user=os.environ.get("DB_USER", "krishimitra"),
        password=pwd,
        dsn=os.environ["DB_CONNECT_STRING"],
        config_dir=os.environ.get("TNS_ADMIN"),
        wallet_location=os.environ.get("TNS_ADMIN"),
    )


def _fetch_pending_email_alerts(conn, limit: int):  # pragma: no cover
    cur = conn.cursor()
    cur.execute(
        """SELECT a.alert_id, f.email, a.message_en, a.message_hi, a.severity
           FROM   alerts a
           JOIN   farmers f ON f.farmer_id = a.farmer_id
           WHERE  a.is_sent = 'N'
           AND    a.channel = 'EMAIL'
           AND    f.email IS NOT NULL
           FETCH FIRST :lim ROWS ONLY""",
        lim=limit,
    )
    rows = cur.fetchall()
    cur.close()
    return rows


def _mark_sent(conn, alert_ids):  # pragma: no cover
    if not alert_ids:
        return
    cur = conn.cursor()
    cur.executemany(
        "UPDATE alerts SET is_sent='Y', sent_at=SYSTIMESTAMP WHERE alert_id=:1",
        [(aid,) for aid in alert_ids],
    )
    conn.commit()
    cur.close()


def _smtp_send(server, sender, to_addr, subject, body):  # pragma: no cover
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = to_addr
    server.sendmail(sender, [to_addr], msg.as_string())


def handler(ctx, data=None):  # pragma: no cover - runtime only
    signer = _signer()
    limit = int(os.environ.get("EMAIL_BATCH_SIZE", "500"))
    host = os.environ["EMAIL_SMTP_HOST"]
    port = int(os.environ.get("EMAIL_SMTP_PORT", "587"))
    sender = os.environ["EMAIL_SENDER"]
    smtp_user = os.environ.get("EMAIL_SMTP_USER")
    smtp_pwd_secret = os.environ.get("EMAIL_SMTP_PASSWORD_SECRET_OCID")
    smtp_pwd = (
        _secret(signer, smtp_pwd_secret)
        if smtp_pwd_secret
        else os.environ.get("EMAIL_SMTP_PASSWORD")
    )

    conn = _db_connect(signer)
    sent = 0
    try:
        rows = _fetch_pending_email_alerts(conn, limit)
        if not rows:
            return response.Response(ctx, response_data=json.dumps({"status": "empty"}))

        server = smtplib.SMTP(host, port, timeout=30)
        try:
            server.ehlo()
            try:
                server.starttls()
                server.ehlo()
            except Exception:
                pass
            if smtp_user and smtp_pwd:
                server.login(smtp_user, smtp_pwd)

            sent_ids = []
            for alert_id, email, msg_en, msg_hi, severity in rows:
                mail = dol.build_email(msg_en, msg_hi, severity)
                try:
                    _smtp_send(server, sender, email, mail["subject"], mail["body"])
                    sent_ids.append(alert_id)
                    sent += 1
                except Exception as exc:
                    logger.warning("email failed for alert %s: %s", alert_id, exc)
            _mark_sent(conn, sent_ids)
        finally:
            try:
                server.quit()
            except Exception:
                pass
    finally:
        conn.close()

    logger.info("Emailed %s alerts", sent)
    return response.Response(ctx, response_data=json.dumps({"status": "ok", "emailed": sent}))
