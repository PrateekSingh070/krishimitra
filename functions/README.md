# KrishiMitra :: OCI Functions

Serverless Python functions (Fn Project / OCI Functions). **Free path by default.**

| Function | Trigger | Purpose (free default) |
|----------|---------|------------------------|
| `disease-classifier` | Object Storage event (`disease-scans/` prefix) | **ONNX** inference in-Function + **pre-translated Hindi** lookup -> POST to ORDS (no paid Vision/Language AI) |
| `model-server` | HTTP (called by APEX pages 3/4 via REST) | Serve sowing (joblib) + price (Prophet) predictions from models in Object Storage (no paid Model Deployment) |
| `alert-dispatcher` | HTTP / scheduled (optional) | Email unsent ATP alerts via SMTP. *Optional* — the DB job `JOB_ALERT_DISPATCH` already does this |
| `report-generator` | Invoked by APEX ("Share with Agriculture Officer") | Fetch scan -> render PDF -> upload to reports bucket -> return PAR URL |

Each function separates **pure logic** (`*_logic.py`) from OCI/IO calls in
`func.py`, so the logic is unit-tested without the OCI SDK or Fn runtime.

### Optional / paid variants (kept, not default)
- `disease-classifier/func_vision_optional.py` — OCI Vision + Language AI.
- `alert-dispatcher/func_stream_optional.py` — OCI Streaming consumer + Fast2SMS SMS.

## Secrets

No secrets in source. On the free path, the ORDS token / DB password / SMTP
password come from **Function config** (or optionally **OCI Vault** via the
resource principal). `func.yaml` holds only non-secret config.

## Local test

```bash
cd functions
python -m pip install -r requirements-dev.txt
python -m pytest tests -q
```

## Deploy

```bash
fn create context oci-krishimitra --provider oracle
fn use context oci-krishimitra
fn create app krishimitra-fn-app --annotation oracle.com/oci/subnetIds='["<subnet-ocid>"]'

cd disease-classifier && fn -v deploy --app krishimitra-fn-app && cd ..
cd model-server      && fn -v deploy --app krishimitra-fn-app && cd ..
cd report-generator  && fn -v deploy --app krishimitra-fn-app && cd ..
# optional (paid SMS/streaming): cd alert-dispatcher && fn -v deploy ...
```

Wire `disease-classifier` to the Object Storage "Object - Create" event rule.
Upload the model artifacts (`disease_mobilenetv3.onnx`, `disease_class_labels.json`,
`disease_lookup.json`, `sowing_model.joblib`, `price_models/*.pkl`) to the
`krishimitra-model-artifacts` bucket — the Functions load them on first call.
