"""Pure, side-effect-free logic for the disease classifier.

Kept separate from func.py so it can be unit-tested with pytest without the
OCI SDK or the Fn runtime.

[FREE PATH] Classification runs locally inside the Function with onnxruntime
(MobileNetV3 exported to ONNX, loaded from Object Storage), and treatment advice
is served from a pre-translated Hindi lookup. No paid OCI Vision/Language AI.
"""
from __future__ import annotations

import math
from typing import Any

# Fallback severity by disease family when the lookup table has no explicit map.
SEVERITY_ORDER = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]

# Class index order the ONNX model was trained on. Must match training
# (ml/01_disease_classifier.ipynb). Loaded from Object Storage alongside the
# model in production (CLASS_LABELS_OBJECT); this is the built-in fallback.
DEFAULT_CLASS_LABELS: list[str] = [
    "Tomato___Late_blight",
    "Tomato___healthy",
    "Potato___Early_blight",
    "Wheat___Leaf_rust",
    "Rice___Blast",
    "Corn___Common_rust",
]

# Minimal built-in lookup. In production this is loaded from Object Storage
# (DISEASE_LOOKUP_OBJECT) so it can be updated without redeploying the function.
# treatment_hi is PRE-TRANSLATED (no runtime translation in the free path).
DEFAULT_LOOKUP: dict[str, dict[str, Any]] = {
    "Tomato___Late_blight": {
        "disease": "Tomato Late Blight",
        "severity": "HIGH",
        "treatment": "Remove and destroy infected foliage. Apply a copper-based "
        "or chlorothalonil fungicide. Avoid overhead irrigation.",
        "treatment_hi": "\u0938\u0902\u0915\u094d\u0930\u092e\u093f\u0924 \u092a\u0924\u094d\u0924\u093f\u092f\u094b\u0902 \u0915\u094b \u0939\u091f\u093e\u0915\u0930 \u0928\u0937\u094d\u091f \u0915\u0930\u0947\u0902\u0964 "
        "\u0915\u0949\u092a\u0930 \u092f\u093e \u0915\u094d\u0932\u094b\u0930\u094b\u0925\u0948\u0932\u094b\u0928\u093f\u0932 \u092b\u092b\u0942\u0902\u0926\u0928\u093e\u0936\u0915 \u091b\u093f\u0921\u093c\u0915\u0947\u0902\u0964 \u090a\u092a\u0930 \u0938\u0947 \u0938\u093f\u0902\u091a\u093e\u0908 \u0938\u0947 \u092c\u091a\u0947\u0902\u0964",
    },
    "Tomato___healthy": {
        "disease": "Healthy",
        "severity": "LOW",
        "treatment": "No action needed.",
        "treatment_hi": "\u0915\u093f\u0938\u0940 \u0915\u093e\u0930\u094d\u0930\u0935\u093e\u0908 \u0915\u0940 \u0906\u0935\u0936\u094d\u092f\u0915\u0924\u093e \u0928\u0939\u0940\u0902\u0964",
    },
    "Potato___Early_blight": {
        "disease": "Potato Early Blight",
        "severity": "MEDIUM",
        "treatment": "Apply mancozeb or chlorothalonil. Rotate crops and remove debris.",
        "treatment_hi": "\u092e\u0948\u0902\u0915\u094b\u091c\u093c\u0947\u092c \u092f\u093e \u0915\u094d\u0932\u094b\u0930\u094b\u0925\u0948\u0932\u094b\u0928\u093f\u0932 \u091b\u093f\u0921\u093c\u0915\u0947\u0902\u0964 \u092b\u0938\u0932 \u091a\u0915\u094d\u0930 \u0905\u092a\u0928\u093e\u090f\u0902 \u0914\u0930 \u0905\u0935\u0936\u0947\u0937 \u0939\u091f\u093e\u090f\u0902\u0964",
    },
    "Wheat___Leaf_rust": {
        "disease": "Wheat Leaf Rust",
        "severity": "HIGH",
        "treatment": "Spray propiconazole at first sign. Use resistant varieties next season.",
        "treatment_hi": "\u0932\u0915\u094d\u0937\u0923 \u0926\u093f\u0916\u0924\u0947 \u0939\u0940 \u092a\u094d\u0930\u094b\u092a\u093f\u0915\u094b\u0928\u093e\u091c\u093c\u094b\u0932 \u091b\u093f\u0921\u093c\u0915\u0947\u0902\u0964 \u0905\u0917\u0932\u0947 \u0938\u0940\u091c\u093c\u0928 \u092a\u094d\u0930\u0924\u093f\u0930\u094b\u0927\u0940 \u0915\u093f\u0938\u094d\u092e\u0947\u0902 \u092c\u094b\u090f\u0902\u0964",
    },
    "Rice___Blast": {
        "disease": "Rice Blast",
        "severity": "CRITICAL",
        "treatment": "Apply tricyclazole immediately. Drain field; reduce nitrogen. "
        "Consult your agriculture officer.",
        "treatment_hi": "\u0924\u0941\u0930\u0902\u0924 \u091f\u094d\u0930\u093e\u0907\u0938\u093e\u0907\u0915\u094d\u0932\u093e\u091c\u093c\u094b\u0932 \u091b\u093f\u0921\u093c\u0915\u0947\u0902\u0964 \u0916\u0947\u0924 \u0915\u093e \u092a\u093e\u0928\u0940 \u0928\u093f\u0915\u093e\u0932\u0947\u0902; \u0928\u093e\u0907\u091f\u094d\u0930\u094b\u091c\u0928 \u0915\u092e \u0915\u0930\u0947\u0902\u0964 "
        "\u0915\u0943\u0937\u093f \u0905\u0927\u093f\u0915\u093e\u0930\u0940 \u0938\u0947 \u0938\u0932\u093e\u0939 \u0932\u0947\u0902\u0964",
    },
    "Corn___Common_rust": {
        "disease": "Maize Common Rust",
        "severity": "MEDIUM",
        "treatment": "Apply a foliar fungicide if severe. Plant resistant hybrids.",
        "treatment_hi": "\u0917\u0902\u092d\u0940\u0930 \u0939\u094b\u0928\u0947 \u092a\u0930 \u092a\u0924\u094d\u0924\u093f\u092f\u094b\u0902 \u092a\u0930 \u092b\u092b\u0942\u0902\u0926\u0928\u093e\u0936\u0915 \u091b\u093f\u0921\u093c\u0915\u0947\u0902\u0964 \u092a\u094d\u0930\u0924\u093f\u0930\u094b\u0927\u0940 \u0938\u0902\u0915\u0930 \u0915\u093f\u0938\u094d\u092e\u0947\u0902 \u0932\u0917\u093e\u090f\u0902\u0964",
    },
}


def softmax(scores: list[float]) -> list[float]:
    """Numerically-stable softmax for a 1-D list of logits."""
    if not scores:
        return []
    m = max(scores)
    exps = [math.exp(s - m) for s in scores]
    total = sum(exps) or 1.0
    return [e / total for e in exps]


def decode_predictions(
    scores: list[float], class_labels: list[str] | None = None
) -> list[dict[str, Any]]:
    """Turn raw model output scores into a sorted label list.

    Mirrors the shape produced by the (legacy) Vision AI path so the rest of the
    pipeline is unchanged: [{"name": str, "confidence": float}, ...].
    """
    labels = class_labels or DEFAULT_CLASS_LABELS
    probs = softmax(list(scores)) if scores else []
    out = [
        {"name": labels[i], "confidence": float(probs[i])}
        for i in range(min(len(labels), len(probs)))
    ]
    out.sort(key=lambda l: l["confidence"], reverse=True)
    return out


def select_top_label(labels: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Return the highest-confidence label from a Vision AI label list.

    Each label is expected to look like {"name": str, "confidence": float}.
    """
    if not labels:
        return None
    return max(labels, key=lambda l: l.get("confidence", 0.0))


def map_label_to_disease(
    label_name: str, lookup: dict[str, dict[str, Any]] | None = None
) -> dict[str, Any]:
    """Map a raw Vision label to a disease record (disease, severity, treatment)."""
    table = lookup or DEFAULT_LOOKUP
    if label_name in table:
        return dict(table[label_name])
    # Unknown label: surface it but flag for human review at MEDIUM severity.
    pretty = label_name.replace("___", " ").replace("_", " ").strip()
    return {
        "disease": pretty or "Unknown condition",
        "severity": "MEDIUM",
        "treatment": "Condition not in knowledge base. Please consult your "
        "agriculture officer for diagnosis.",
        "treatment_hi": "\u092f\u0939 \u0938\u094d\u0925\u093f\u0924\u093f \u091c\u094d\u091e\u093e\u0928\u0915\u094b\u0936 \u092e\u0947\u0902 \u0928\u0939\u0940\u0902 \u0939\u0948\u0964 "
        "\u0915\u0943\u092a\u092f\u093e \u0928\u093f\u0926\u093e\u0928 \u0915\u0947 \u0932\u093f\u090f \u0905\u092a\u0928\u0947 \u0915\u0943\u0937\u093f \u0905\u0927\u093f\u0915\u093e\u0930\u0940 \u0938\u0947 \u0938\u0902\u092a\u0930\u094d\u0915 \u0915\u0930\u0947\u0902\u0964",
    }


def build_scan_payload(
    *,
    farmer_id: int,
    image_url: str,
    label_name: str,
    confidence: float,
    treatment_hindi: str | None = None,
    vision_request_id: str | None = None,
    farmer_crop_id: int | None = None,
    lookup: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Assemble the JSON body POSTed to the ORDS disease_scans endpoint.

    In the free path the Hindi advice comes from the pre-translated lookup
    (record["treatment_hi"]); treatment_hindi may still be passed to override.
    """
    record = map_label_to_disease(label_name, lookup)
    return {
        "farmer_id": farmer_id,
        "farmer_crop_id": farmer_crop_id,
        "image_url": image_url,
        "disease_detected": record["disease"],
        "confidence_score": round(float(confidence) * 100, 2)
        if confidence <= 1
        else round(float(confidence), 2),
        "severity": record["severity"],
        "treatment_advice": record["treatment"],
        "treatment_hindi": treatment_hindi
        or record.get("treatment_hi")
        or record["treatment"],
        "oci_vision_req": vision_request_id,
    }


def parse_object_event(event: dict[str, Any]) -> dict[str, str]:
    """Extract namespace/bucket/object from an OCI Object Storage event."""
    data = event.get("data", {})
    res = data.get("resourceName") or data.get("resourceId") or ""
    return {
        "namespace": data.get("additionalDetails", {}).get("namespace", ""),
        "bucket": data.get("additionalDetails", {}).get("bucketName", ""),
        "object": res,
    }


def farmer_id_from_object_name(object_name: str) -> int | None:
    """Object key convention: disease-scans/<farmer_id>/<uuid>.jpg."""
    parts = [p for p in object_name.split("/") if p]
    for p in parts:
        if p.isdigit():
            return int(p)
    return None
