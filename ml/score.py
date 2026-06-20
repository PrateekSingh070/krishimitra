"""OCI Data Science Model Deployment entry point for the Sowing Recommender.

ADS calls load_model() once at container start and predict() per request.
Deploy with:
    SklearnModel(...).prepare(inference_conda_env='generalml_p38_cpu_v1',
                              score_py='score.py')
"""
import json
import os

import joblib
import pandas as pd

_MODEL = None

CAT_FEATURES = ["district", "soil_type", "crop"]
NUM_FEATURES = [
    "sow_month", "rainfall_5y_mm", "price_trend_30d_pct", "hist_yield_3y",
    "land_acres", "temp_avg_c", "humidity_pct", "irrigation_idx",
]
FEATURES = CAT_FEATURES + NUM_FEATURES


def load_model(model_file_name="sowing_model.joblib"):
    """Load the serialized pipeline from the model artifact directory."""
    global _MODEL
    if _MODEL is None:
        model_dir = os.path.dirname(os.path.realpath(__file__))
        _MODEL = joblib.load(os.path.join(model_dir, model_file_name))
    return _MODEL


def _coerce(data):
    """Accept a dict, a list of dicts, or a {'instances': [...]} envelope."""
    if isinstance(data, str):
        data = json.loads(data)
    if isinstance(data, dict) and "instances" in data:
        data = data["instances"]
    if isinstance(data, dict):
        data = [data]
    return pd.DataFrame(data, columns=FEATURES)


def predict(data, model=load_model()):
    """Return predicted expected yield (qtl/acre) for one or more inputs."""
    df = _coerce(data)
    preds = model.predict(df)
    return {"prediction": [round(float(p), 2) for p in preds], "unit": "qtl/acre"}
