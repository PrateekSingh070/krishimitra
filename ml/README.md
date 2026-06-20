# KrishiMitra :: ML models

Three models, one notebook each.

> **Free-tier default.** You do **not** need paid OCI Data Science Model
> Deployments. Train the models for free (local CPU, or a free Colab/Kaggle GPU
> for the disease classifier), export the artifacts, and upload them to the
> **Always Free Object Storage** bucket `krishimitra-model-artifacts`. They are
> then served by the free **`functions/model-server`** Function (sowing + price)
> and the **`functions/disease-classifier`** Function (ONNX). The paid Model
> Deployment / Vision custom-model path below is kept as an optional upgrade.

| Notebook | Model | Framework | Free serving (default) |
|----------|-------|-----------|------------------------|
| `01_disease_classifier.ipynb` | Crop disease classifier | TensorFlow / MobileNetV3 -> **ONNX** | `disease-classifier` Function (onnxruntime) |
| `02_sowing_recommender.ipynb` | Sowing recommender (yield) | scikit-learn + XGBoost (joblib) | `model-server` Function (`model=sowing`) |
| `03_price_forecaster.ipynb` | 30-day price forecaster | Prophet (pickle per crop) | `model-server` Function (`model=price`) |

## Free training + export workflow

1. `pip install -r requirements.txt` and run the notebook (local CPU is fine for
   sowing/price; use a free Colab/Kaggle GPU for the disease classifier).
2. Export artifacts:
   - Disease: `tf2onnx` -> `disease_mobilenetv3.onnx` + `disease_class_labels.json`
     (+ keep `disease_lookup.json` with English **and** pre-translated Hindi).
   - Sowing: `joblib.dump(pipeline, "sowing_model.joblib")`.
   - Price: one pickle per crop, `price_models/prophet_crop_<id>.pkl`.
3. Upload to Object Storage (free):
   ```bash
   oci os object put -bn krishimitra-model-artifacts --file disease_mobilenetv3.onnx
   oci os object put -bn krishimitra-model-artifacts --file sowing_model.joblib
   oci os object put -bn krishimitra-model-artifacts --file price_models/prophet_crop_5.pkl --name price_models/prophet_crop_5.pkl
   ```
4. The Functions load + cache these objects on first request (per warm container).

## Run locally / in a notebook session

```bash
pip install -r requirements.txt
jupyter lab        # then open the notebooks
```

The sowing recommender and price forecaster synthesise representative data so
they run end-to-end without OCI/DB access. Swap the `load_*` functions for the
real Oracle ATP / Object Storage extracts in production (queries are shown in
the notebooks). The disease classifier requires the PlantVillage dataset and a
GPU shape.

## (Optional / paid) Deploy the sowing recommender via ADS Model Deployment

> Not needed for the free path — the `model-server` Function already serves this
> model. Use this only if you intentionally enable paid Data Science.

```python
from ads.model.framework.sklearn_model import SklearnModel
m = SklearnModel(estimator=model, artifact_dir='model-artifact')
m.prepare(inference_conda_env='generalml_p38_cpu_v1', score_py='score.py',
          X_sample=X_test.head())
m.verify(X_test.head().to_dict(orient='records'))
model_id = m.save(display_name='krishimitra-sowing-recommender')
m.deploy(display_name='krishimitra-sowing-md',
         deployment_instance_shape='VM.Standard.E4.Flex')
```

`score.py` is the deployment entry point (`load_model` + `predict`).
