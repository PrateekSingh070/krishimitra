"""OCI Function: model-server.  [FREE PATH]

Serves ML predictions (sowing yield + market price) WITHOUT a paid OCI Data
Science Model Deployment. Models are trained offline (free: local CPU or Colab),
exported to the free Object Storage bucket, and loaded + cached here per warm
container.

Request (HTTP POST, JSON):
  { "model": "sowing", "instances": [ { ...features... } ] }
  { "model": "price",  "instances": [ { "crop_id": 5, "periods": 30 } ] }

APEX pages 3/4 call this Function (via ORDS/REST) instead of a Model Deployment.

No secrets in code: bucket/namespace come from Function config; the resource
principal authorises Object Storage reads.
"""
from __future__ import annotations

import io
import json
import logging
import os
import pickle

import model_logic as ml

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("model-server")

try:  # pragma: no cover - deployed runtime only
    import joblib
    import pandas as pd

    import oci
    from fdk import response
except Exception:  # pragma: no cover
    joblib = None
    pd = None
    oci = None
    response = None

_SOWING_MODEL = None
_PRICE_MODELS: dict[str, object] = {}


def _signer():  # pragma: no cover
    return oci.auth.signers.get_resource_principals_signer()


def _read_object(signer, namespace, bucket, name) -> bytes:  # pragma: no cover
    client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
    obj = client.get_object(namespace_name=namespace, bucket_name=bucket, object_name=name)
    buf = io.BytesIO()
    for chunk in obj.data.raw.stream(1024 * 1024, decode_content=False):
        buf.write(chunk)
    return buf.getvalue()


def _namespace(signer):  # pragma: no cover
    ns = os.environ.get("OBJECT_NAMESPACE")
    if ns:
        return ns
    client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
    return client.get_namespace().data


def _get_sowing_model(signer):  # pragma: no cover
    global _SOWING_MODEL
    if _SOWING_MODEL is None:
        bucket = os.environ["MODEL_BUCKET"]
        key = os.environ.get("SOWING_MODEL_OBJECT", "sowing_model.joblib")
        raw = _read_object(signer, _namespace(signer), bucket, key)
        _SOWING_MODEL = joblib.load(io.BytesIO(raw))
    return _SOWING_MODEL


def _get_price_model(signer, crop_id: str):  # pragma: no cover
    if crop_id not in _PRICE_MODELS:
        bucket = os.environ["MODEL_BUCKET"]
        key = os.environ.get("PRICE_MODEL_PREFIX", "price_models/") + f"prophet_crop_{crop_id}.pkl"
        raw = _read_object(signer, _namespace(signer), bucket, key)
        _PRICE_MODELS[crop_id] = pickle.loads(raw)
    return _PRICE_MODELS[crop_id]


def _predict_sowing(signer, instances):  # pragma: no cover
    model = _get_sowing_model(signer)
    df = pd.DataFrame(ml.sowing_rows(instances), columns=ml.SOWING_FEATURES)
    preds = model.predict(df)
    return ml.build_sowing_response(list(preds))


def _predict_price(signer, instances):  # pragma: no cover
    crop_id = str(instances[0].get("crop_id", "0"))
    periods = ml.price_periods(instances)
    model = _get_price_model(signer, crop_id)
    future = model.make_future_dataframe(periods=periods)
    fc = model.predict(future).tail(periods)
    dates = [d.strftime("%Y-%m-%d") for d in fc["ds"]]
    return ml.build_price_response(dates, list(fc["yhat"]))


def handler(ctx, data: "io.BytesIO" = None):  # pragma: no cover - runtime only
    try:
        body = data.getvalue() if data else b""
        req = ml.parse_request(body)
    except Exception as exc:
        return response.Response(
            ctx, status_code=400, response_data=json.dumps({"error": str(exc)})
        )

    signer = _signer()
    try:
        if req["model"] == "sowing":
            out = _predict_sowing(signer, req["instances"])
        else:
            out = _predict_price(signer, req["instances"])
    except Exception as exc:
        logger.exception("prediction failed")
        return response.Response(
            ctx, status_code=500, response_data=json.dumps({"error": str(exc)})
        )

    return response.Response(
        ctx, response_data=json.dumps(out), headers={"Content-Type": "application/json"}
    )
