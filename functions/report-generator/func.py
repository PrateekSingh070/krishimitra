"""OCI Function: report-generator.

Invoked by the APEX disease-scanner page ("Share with Agriculture Officer").
Fetches a scan from ORDS, renders a PDF, uploads it to the reports bucket, and
returns a pre-authenticated request (PAR) URL the farmer can share.
"""
from __future__ import annotations

import json
import logging
import os

import requests

import report_logic as rl

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("report-generator")

try:  # pragma: no cover - runtime only
    import oci
    from fdk import response
    from fpdf import FPDF
except Exception:  # pragma: no cover
    oci = None
    response = None
    FPDF = None


def _signer():  # pragma: no cover
    return oci.auth.signers.get_resource_principals_signer()


def _fetch_scan(scan_id: int) -> dict:  # pragma: no cover
    base = os.environ["ORDS_BASE_URL"].rstrip("/")
    resp = requests.get(f"{base}/disease_scans/{scan_id}", timeout=30)
    resp.raise_for_status()
    return resp.json()


def _render_pdf(scan: dict) -> bytes:  # pragma: no cover
    pdf = FPDF()
    pdf.add_page()
    # A Devanagari-capable font should be bundled for Hindi; falls back to core.
    font_path = os.path.join(os.path.dirname(__file__), "NotoSansDevanagari.ttf")
    if os.path.exists(font_path):
        pdf.add_font("Noto", "", font_path)
        pdf.set_font("Noto", size=12)
    else:
        pdf.set_font("Helvetica", size=12)
    for line in rl.build_report_lines(scan):
        pdf.multi_cell(0, 8, line)
    return bytes(pdf.output())


def _upload(signer, namespace: str, bucket: str, name: str, body: bytes) -> str:  # pragma: no cover
    client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
    client.put_object(namespace, bucket, name, body, content_type="application/pdf")
    import datetime

    par = client.create_preauthenticated_request(
        namespace,
        bucket,
        oci.object_storage.models.CreatePreauthenticatedRequestDetails(
            name=f"par-{name}",
            object_name=name,
            access_type="ObjectRead",
            time_expires=datetime.datetime.utcnow() + datetime.timedelta(days=7),
        ),
    ).data
    region = os.environ.get("OCI_REGION", "ap-mumbai-1")
    return f"https://objectstorage.{region}.oraclecloud.com{par.access_uri}"


def handler(ctx, data=None):  # pragma: no cover - runtime only
    body = json.loads(data.getvalue()) if data and data.getvalue() else {}
    scan_id = int(body.get("scan_id", 0))
    if not scan_id:
        return response.Response(
            ctx, status_code=400, response_data=json.dumps({"error": "scan_id required"})
        )

    signer = _signer()
    scan = _fetch_scan(scan_id)
    pdf_bytes = _render_pdf(scan)
    name = rl.report_object_name(scan_id)
    url = _upload(signer, os.environ["OBJECT_NAMESPACE"], os.environ["REPORTS_BUCKET"], name, pdf_bytes)

    logger.info("Generated report for scan %s -> %s", scan_id, name)
    return response.Response(ctx, response_data=json.dumps({"status": "ok", "report_url": url}))
