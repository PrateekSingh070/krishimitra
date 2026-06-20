"""OCI Function: alert-dispatcher  [OPTIONAL / PAID PATH — not the default].

This is the original OCI Streaming + Fast2SMS dispatcher. It is kept for the
optional paid path (SMS + Streaming). The FREE default lives in func.py and
emails unsent alerts straight from Oracle ATP (and the DB-side JOB_ALERT_DISPATCH
already does this on a schedule, so this Function is not required at all in the
free path).

Trigger: OCI Streaming consumer (krishimitra-alerts-stream).
Flow:
  1. Consume alert events from the stream (cursor-based consumer group).
  2. Render bilingual messages from the rule template.
  3. Resolve affected farmers (by district) from Oracle ATP.
  4. Batch-INSERT into ALERTS and batch-send SMS via Fast2SMS (<=1000/call).
  5. Mark ALERTS.is_sent = 'Y', sent_at = SYSTIMESTAMP.

DB password and the Fast2SMS API key are read from OCI Vault via the resource
principal. Nothing sensitive is in config or code.
"""
from __future__ import annotations

import json
import logging
import os

import requests

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
    pwd = _secret(signer, os.environ["DB_PASSWORD_SECRET_OCID"])
    return oracledb.connect(
        user=os.environ.get("DB_USER", "krishimitra"),
        password=pwd,
        dsn=os.environ["DB_CONNECT_STRING"],
        config_dir=os.environ.get("TNS_ADMIN"),
        wallet_location=os.environ.get("TNS_ADMIN"),
        wallet_password=_secret(signer, os.environ["WALLET_SECRET_OCID"])
        if os.environ.get("WALLET_SECRET_OCID")
        else None,
    )


def _farmers_in_district(conn, district: str):  # pragma: no cover
    cur = conn.cursor()
    cur.execute(
        "SELECT farmer_id, phone FROM farmers WHERE district = :d AND is_active = 'Y'",
        d=district,
    )
    rows = cur.fetchall()
    cur.close()
    return rows


def _insert_alerts(conn, rows, rendered, channel="SMS"):  # pragma: no cover
    cur = conn.cursor()
    id_var = cur.var(oracledb.NUMBER)
    alert_ids = []
    data = [
        {
            "t": rendered["type"],
            "f": fid,
            "en": rendered["en"],
            "hi": rendered["hi"],
            "s": rendered["severity"],
            "c": channel,
        }
        for (fid, _phone) in rows
    ]
    for d in data:
        cur.execute(
            """INSERT INTO alerts (alert_type, farmer_id, message_en, message_hi,
                                   severity, is_sent, channel)
               VALUES (:t, :f, :en, :hi, :s, 'N', :c)
               RETURNING alert_id INTO :rid""",
            {**d, "rid": id_var},
        )
        alert_ids.append(id_var.getvalue()[0])
    conn.commit()
    cur.close()
    return alert_ids


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


def _send_sms(phones, message, api_key):  # pragma: no cover
    payload = dol.build_fast2sms_payload(phones, message, api_key)
    resp = requests.post(
        "https://www.fast2sms.com/dev/bulkV2",
        data=payload,
        headers={"authorization": api_key},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def _consume(signer):  # pragma: no cover
    client = oci.streaming.StreamClient(
        config={}, service_endpoint=os.environ["STREAM_ENDPOINT"], signer=signer
    )
    stream_id = os.environ["STREAM_OCID"]
    group = os.environ.get("CONSUMER_GROUP", "alert-dispatcher")
    cursor = client.create_group_cursor(
        stream_id,
        oci.streaming.models.CreateGroupCursorDetails(
            group_name=group, type="TRIM_HORIZON", commit_on_get=True
        ),
    ).data.value
    msgs = client.get_messages(stream_id, cursor).data
    out = []
    for m in msgs:
        import base64

        out.append(base64.b64decode(m.value).decode("utf-8"))
    return out


def handler(ctx, data=None):  # pragma: no cover - runtime only
    signer = _signer()
    api_key = _secret(signer, os.environ["FAST2SMS_SECRET_OCID"])
    batch_size = int(os.environ.get("SMS_BATCH_SIZE", "1000"))

    raw_msgs = _consume(signer)
    if not raw_msgs:
        return response.Response(ctx, response_data=json.dumps({"status": "empty"}))

    conn = _db_connect(signer)
    total_sms = 0
    try:
        for raw in raw_msgs:
            event = dol.parse_stream_message(raw)
            rendered = dol.render_messages(event.get("rule_id"), event.get("params", {}))
            if not rendered:
                logger.warning("Unknown rule_id: %s", event.get("rule_id"))
                continue

            district = event.get("params", {}).get("district")
            rows = _farmers_in_district(conn, district)
            if not rows:
                continue

            alert_ids = _insert_alerts(conn, rows, rendered)

            phones = [p for (_f, p) in rows]
            sent_ids_offset = 0
            for batch in dol.chunk(phones, batch_size):
                _send_sms(batch, rendered["hi"], api_key)
                total_sms += len(batch)
                count = len(batch)
                _mark_sent(conn, alert_ids[sent_ids_offset : sent_ids_offset + count])
                sent_ids_offset += count
    finally:
        conn.close()

    logger.info("Dispatched %s SMS across %s events", total_sms, len(raw_msgs))
    return response.Response(
        ctx, response_data=json.dumps({"status": "ok", "sms_sent": total_sms})
    )
