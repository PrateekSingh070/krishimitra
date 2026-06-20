"""KrishiMitra ML sidecar (OPTIONAL).

Prophet (price) and scikit-learn (sowing/yield) models can't run inside the
Node API, so live inference is served by this tiny FastAPI app. It is OPTIONAL:
by default the Node API serves predictions straight from the `ml_predictions`
table (populated by the notebooks / the populate script below), and you only
need this sidecar if you want on-demand inference.

Run (free, local or any free Python host):
    pip install -r requirements.txt
    uvicorn main:app --port 8000

Then point the Node API at it with ML_SIDECAR_URL=http://localhost:8000
(wire a fetch in recommendations.js if you enable this path).
"""
from __future__ import annotations

import os
import pickle
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

ARTIFACTS = Path(os.environ.get("ML_ARTIFACTS_DIR", "../../ml-artifacts"))

app = FastAPI(title="KrishiMitra ML sidecar", version="0.1.0")

_models: dict[str, object] = {}


def _load(name: str):
    if name not in _models:
        path = ARTIFACTS / name
        if not path.exists():
            raise HTTPException(503, f"Model {name} not available")
        with open(path, "rb") as fh:
            _models[name] = pickle.load(fh)
    return _models[name]


class PriceRequest(BaseModel):
    crop_id: int
    horizon_days: int = 7


class SowingRequest(BaseModel):
    crop_id: int
    land_acres: float
    soil_type: str | None = None
    state: str | None = None


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/predict/price")
def predict_price(req: PriceRequest) -> dict:
    """Forecast modal price with the per-crop Prophet model (if present)."""
    model = _load(f"price_prophet_{req.crop_id}.pkl")
    # Prophet API: build a future frame and predict. Kept minimal here.
    future = model.make_future_dataframe(periods=req.horizon_days)  # type: ignore[attr-defined]
    forecast = model.predict(future)  # type: ignore[attr-defined]
    tail = forecast.tail(req.horizon_days)[["ds", "yhat"]]
    return {"crop_id": req.crop_id, "forecast": tail.to_dict(orient="records")}


@app.post("/predict/sowing")
def predict_sowing(req: SowingRequest) -> dict:
    """Predict expected yield with the sklearn sowing model (if present)."""
    model = _load("sowing_recommender.pkl")
    features = [[req.crop_id, req.land_acres]]
    value = float(model.predict(features)[0])  # type: ignore[attr-defined]
    return {"crop_id": req.crop_id, "predicted_yield_qtl": round(value, 2)}
