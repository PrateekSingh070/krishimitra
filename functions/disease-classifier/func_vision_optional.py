"""OPTIONAL / PAID path for disease-classifier (kept for upgrade, not default).

These helpers use OCI Vision AI for image classification and OCI Language AI for
runtime translation. They are NOT used by the free default (func.py runs ONNX
inference locally and uses the pre-translated Hindi lookup). Wire these back in
only if you intentionally enable the paid services.

Both require: pip install oci, and a custom Vision model + Language AI access.
"""
from __future__ import annotations

# pragma: no cover - this whole module is the optional paid path
try:  # pragma: no cover
    import oci
except Exception:  # pragma: no cover
    oci = None


def classify_image_vision(signer, image_bytes: bytes, model_ocid: str, compartment: str):  # pragma: no cover
    """Classify with OCI Vision AI (paid). Returns (labels, request_id)."""
    client = oci.ai_vision.AIServiceVisionClient(config={}, signer=signer)
    details = oci.ai_vision.models.AnalyzeImageDetails(
        features=[
            oci.ai_vision.models.ImageClassificationFeature(
                feature_type="IMAGE_CLASSIFICATION",
                model_id=model_ocid,
                max_results=5,
            )
        ],
        image=oci.ai_vision.models.InlineImageDetails(
            source="INLINE", data=oci.util.to_base64(image_bytes)
        ),
        compartment_id=compartment,
    )
    resp = client.analyze_image(analyze_image_details=details)
    labels = [{"name": l.name, "confidence": l.confidence} for l in resp.data.labels or []]
    return labels, resp.request_id


def translate_language(signer, text: str, target_lang: str, compartment: str) -> str:  # pragma: no cover
    """Translate with OCI Language AI (paid)."""
    if not text:
        return text
    client = oci.ai_language.AIServiceLanguageClient(config={}, signer=signer)
    details = oci.ai_language.models.BatchLanguageTranslationDetails(
        documents=[oci.ai_language.models.TextDocument(key="1", text=text, language_code="en")],
        compartment_id=compartment,
        target_language_code=target_lang,
    )
    resp = client.batch_language_translation(batch_language_translation_details=details)
    docs = resp.data.documents or []
    return docs[0].translated_text if docs else text
