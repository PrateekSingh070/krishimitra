"""Pure, side-effect-free logic for the model-server Function.  [FREE PATH]

Replaces the paid OCI Data Science Model Deployment. The Function loads the
sowing (joblib sklearn pipeline) and price (Prophet pickle) models from Object
Storage and serves predictions over HTTP. This module holds only the framing /
validation logic so it can be unit-tested without joblib, pandas, prophet or oci.
"""
from __future__ import annotations

import json
from typing import Any

# Must match ml/score.py / the training notebooks.
SOWING_CAT_FEATURES = ["district", "soil_type", "crop"]
SOWING_NUM_FEATURES = [
    "sow_month", "rainfall_5y_mm", "price_trend_30d_pct", "hist_yield_3y",
    "land_acres", "temp_avg_c", "humidity_pct", "irrigation_idx",
]
SOWING_FEATURES = SOWING_CAT_FEATURES + SOWING_NUM_FEATURES

VALID_MODELS = {"sowing", "price"}


def parse_request(data: Any) -> dict[str, Any]:
    """Normalise the incoming body to {'model': str, 'instances': [dict, ...]}.

    Accepts:
      * {"model": "sowing", "instances": [ {...}, ... ]}
      * {"model": "price", "instances": [ {"periods": 30, "crop_id": 5}, ... ]}
      * a bare dict (single instance) -> wrapped into instances
    Defaults model to 'sowing' when omitted.
    """
    if isinstance(data, (bytes, bytearray)):
        data = data.decode("utf-8")
    if isinstance(data, str):
        data = json.loads(data) if data.strip() else {}
    if not isinstance(data, dict):
        raise ValueError("request body must be a JSON object")

    model = (data.get("model") or "sowing").lower()
    if model not in VALID_MODELS:
        raise ValueError(f"unknown model '{model}'; expected one of {sorted(VALID_MODELS)}")

    instances = data.get("instances")
    if instances is None:
        # treat any non-control keys as a single instance
        instances = [{k: v for k, v in data.items() if k != "model"}]
    if isinstance(instances, dict):
        instances = [instances]
    if not isinstance(instances, list) or not instances:
        raise ValueError("'instances' must be a non-empty list")

    return {"model": model, "instances": instances}


def sowing_rows(instances: list[dict[str, Any]]) -> list[list[Any]]:
    """Project instances onto the ordered SOWING_FEATURES (missing -> None)."""
    return [[inst.get(f) for f in SOWING_FEATURES] for inst in instances]


def build_sowing_response(preds: list[float]) -> dict[str, Any]:
    return {
        "model": "sowing",
        "prediction": [round(float(p), 2) for p in preds],
        "unit": "qtl/acre",
    }


def price_periods(instances: list[dict[str, Any]]) -> int:
    """How many future days to forecast (clamped to a sane range)."""
    p = instances[0].get("periods", 30)
    try:
        p = int(p)
    except (TypeError, ValueError):
        p = 30
    return max(1, min(p, 365))


def build_price_response(dates: list[str], yhat: list[float]) -> dict[str, Any]:
    points = [
        {"date": d, "price_per_qtl": round(float(v), 2)}
        for d, v in zip(dates, yhat)
    ]
    return {"model": "price", "forecast": points, "unit": "INR/qtl"}
