"""OCI Function: disease-classifier.  [FREE PATH]

Trigger: OCI Object Storage event (new object under the disease-scans/ prefix).
Flow:
  1. Resolve the uploaded image (namespace/bucket/object) from the event.
  2. Run MobileNetV3 inference LOCALLY with onnxruntime (model loaded from
     Object Storage and cached for the life of the container). No paid Vision AI.
  3. Map the top label to a disease record (disease/severity/treatment).
  4. Use the PRE-TRANSLATED Hindi treatment from the lookup. No paid Language AI.
  5. POST the result to the ORDS /disease_scans endpoint.
  6. Log everything to stdout (captured by the platform).

Free-tier notes:
  * onnxruntime + pillow + numpy run inside the Function container (free).
  * The ONNX model + class labels live in the free Object Storage bucket.
  * The paid Vision/Language path is preserved in func_vision_optional.py.

No secrets in code: the ORDS token + OCIDs come from the Function's configured
environment (set from a Vault secret or plain config in the free path).
"""
from __future__ import annotations

import io
import json
import logging
import os

import requests

import disease_logic as dl

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("disease-classifier")

# Imported lazily inside the handler so unit tests of disease_logic don't need
# the heavy/native deps (onnxruntime, pillow, numpy, oci).
try:  # pragma: no cover - exercised only in the deployed runtime
    import numpy as np
    import onnxruntime as ort
    from PIL import Image

    import oci
    from fdk import response
except Exception:  # pragma: no cover
    np = None
    ort = None
    Image = None
    oci = None
    response = None

# Module-level caches so the model + labels are loaded once per warm container.
_SESSION = None
_CLASS_LABELS = None
_LOOKUP = None


def _signer():  # pragma: no cover - runtime only
    return oci.auth.signers.get_resource_principals_signer()


def _read_object(signer, namespace: str, bucket: str, name: str) -> bytes:  # pragma: no cover
    client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
    obj = client.get_object(namespace_name=namespace, bucket_name=bucket, object_name=name)
    buf = io.BytesIO()
    for chunk in obj.data.raw.stream(1024 * 1024, decode_content=False):
        buf.write(chunk)
    return buf.getvalue()


def _get_session(signer, namespace: str):  # pragma: no cover
    """Lazily load + cache the ONNX model from Object Storage."""
    global _SESSION
    if _SESSION is not None:
        return _SESSION
    bucket = os.environ["MODEL_BUCKET"]
    key = os.environ.get("MODEL_OBJECT", "disease_mobilenetv3.onnx")
    raw = _read_object(signer, namespace, bucket, key)
    _SESSION = ort.InferenceSession(raw, providers=["CPUExecutionProvider"])
    return _SESSION


def _get_class_labels(signer, namespace: str):  # pragma: no cover
    global _CLASS_LABELS
    if _CLASS_LABELS is not None:
        return _CLASS_LABELS
    bucket = os.environ.get("MODEL_BUCKET")
    key = os.environ.get("CLASS_LABELS_OBJECT")
    if bucket and key:
        try:
            _CLASS_LABELS = json.loads(_read_object(signer, namespace, bucket, key))
            return _CLASS_LABELS
        except Exception as exc:
            logger.warning("Falling back to built-in class labels: %s", exc)
    _CLASS_LABELS = dl.DEFAULT_CLASS_LABELS
    return _CLASS_LABELS


def _load_lookup(signer, namespace: str):  # pragma: no cover
    global _LOOKUP
    if _LOOKUP is not None:
        return _LOOKUP
    bucket = os.environ.get("DISEASE_LOOKUP_BUCKET")
    obj_name = os.environ.get("DISEASE_LOOKUP_OBJECT")
    if not (bucket and obj_name and namespace):
        _LOOKUP = dl.DEFAULT_LOOKUP
        return _LOOKUP
    try:
        raw = _read_object(signer, namespace, bucket, obj_name)
        _LOOKUP = json.loads(raw)
    except Exception as exc:
        logger.warning("Falling back to built-in lookup: %s", exc)
        _LOOKUP = dl.DEFAULT_LOOKUP
    return _LOOKUP


def _preprocess(image_bytes: bytes, size: int = 224):  # pragma: no cover
    """Decode + resize + normalise an image into a (1,3,H,W) float32 tensor."""
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB").resize((size, size))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    arr = (arr - mean) / std
    arr = np.transpose(arr, (2, 0, 1))  # HWC -> CHW
    return np.expand_dims(arr, axis=0).astype(np.float32)


def _classify_local(session, image_bytes: bytes, class_labels):  # pragma: no cover
    """Run ONNX inference and return (labels, request_id)."""
    tensor = _preprocess(image_bytes)
    input_name = session.get_inputs()[0].name
    outputs = session.run(None, {input_name: tensor})
    scores = np.asarray(outputs[0]).reshape(-1).tolist()
    labels = dl.decode_predictions(scores, class_labels)
    return labels, None


def _post_to_ords(payload: dict) -> int:  # pragma: no cover
    base = os.environ["ORDS_BASE_URL"].rstrip("/")
    url = f"{base}/disease_scans/"
    headers = {"Content-Type": "application/json"}
    token = os.environ.get("ORDS_BEARER_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    resp = requests.post(url, json=payload, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.status_code


def handler(ctx, data: "io.BytesIO" = None):  # pragma: no cover - runtime only
    try:
        event = json.loads(data.getvalue()) if data and data.getvalue() else {}
    except Exception:
        event = {}

    ref = dl.parse_object_event(event)
    image_url = (
        f"https://objectstorage/{ref['namespace']}/b/{ref['bucket']}/o/{ref['object']}"
    )
    farmer_id = dl.farmer_id_from_object_name(ref["object"]) or 0
    logger.info("Processing scan for farmer=%s object=%s", farmer_id, ref["object"])

    signer = _signer()
    namespace = ref["namespace"]

    image_bytes = _read_object(signer, namespace, ref["bucket"], ref["object"])
    session = _get_session(signer, namespace)
    class_labels = _get_class_labels(signer, namespace)
    labels, request_id = _classify_local(session, image_bytes, class_labels)

    top = dl.select_top_label(labels)
    if not top:
        logger.warning("No labels returned for %s", ref["object"])
        return response.Response(ctx, response_data=json.dumps({"status": "no_labels"}))

    lookup = _load_lookup(signer, namespace)
    payload = dl.build_scan_payload(
        farmer_id=farmer_id,
        image_url=image_url,
        label_name=top["name"],
        confidence=top.get("confidence", 0.0),
        vision_request_id=request_id,
        lookup=lookup,
    )

    status = _post_to_ords(payload)
    logger.info("Posted scan to ORDS (status=%s, disease=%s)", status, payload["disease_detected"])
    return response.Response(
        ctx, response_data=json.dumps({"status": "ok", "disease": payload["disease_detected"]})
    )
