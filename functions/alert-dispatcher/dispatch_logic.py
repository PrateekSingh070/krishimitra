"""Pure logic for the alert dispatcher (unit-testable without OCI/DB)."""
from __future__ import annotations

import json
from typing import Any, Iterable

# Bilingual message templates keyed by alert rule. {var} placeholders are filled
# from the stream event payload.
TEMPLATES: dict[str, dict[str, str]] = {
    "WR-01": {
        "en": "Flood risk in {district}: rainfall over 200mm expected in 48h. Protect your crops.",
        "hi": "{district} में बाढ़ का खतरा: 48 घंटों में 200mm से अधिक वर्षा संभावित। फसल सुरक्षित करें।",
        "severity": "HIGH",
        "type": "WEATHER",
    },
    "WR-02": {
        "en": "Frost risk in {district}: temperatures below 5C for 3+ nights. Cover crops.",
        "hi": "{district} में पाला का खतरा: 3+ रातों तक तापमान 5C से नीचे। फसल ढकें।",
        "severity": "MEDIUM",
        "type": "WEATHER",
    },
    "WR-03": {
        "en": "Drought risk in {district}: no rain for 21+ days. Irrigate your crops.",
        "hi": "{district} में सूखे का खतरा: 21+ दिनों से वर्षा नहीं। फसल की सिंचाई करें।",
        "severity": "HIGH",
        "type": "WEATHER",
    },
    "PR-01": {
        "en": "{crop} price fell over 15% in 3 days at {mandi}. Consider delaying sale.",
        "hi": "{crop} का भाव {mandi} में 3 दिनों में 15% से अधिक गिरा। बिक्री टालने पर विचार करें।",
        "severity": "MEDIUM",
        "type": "PRICE_DROP",
    },
    "PR-02": {
        "en": "{crop} price rose over 20% in 7 days at {mandi}. Good time to sell.",
        "hi": "{crop} का भाव {mandi} में 7 दिनों में 20% से अधिक बढ़ा। बेचने का अच्छा समय।",
        "severity": "LOW",
        "type": "PRICE_RISE",
    },
}


def parse_stream_message(b64_or_dict: Any) -> dict[str, Any]:
    """Decode a stream message value into a dict. Accepts a dict or JSON string."""
    if isinstance(b64_or_dict, dict):
        return b64_or_dict
    if isinstance(b64_or_dict, (bytes, bytearray)):
        b64_or_dict = b64_or_dict.decode("utf-8")
    return json.loads(b64_or_dict)


def render_messages(rule_id: str, params: dict[str, Any]) -> dict[str, str] | None:
    """Return {'en','hi','severity','type'} for a rule, or None if unknown."""
    tmpl = TEMPLATES.get(rule_id)
    if not tmpl:
        return None
    safe = {k: params.get(k, "") for k in ("district", "crop", "mandi")}
    return {
        "en": tmpl["en"].format(**safe),
        "hi": tmpl["hi"].format(**safe),
        "severity": tmpl["severity"],
        "type": tmpl["type"],
    }


def chunk(items: list[Any], size: int) -> Iterable[list[Any]]:
    """Yield consecutive chunks of `size` (Fast2SMS caps bulk recipients)."""
    size = max(1, size)
    for i in range(0, len(items), size):
        yield items[i : i + size]


def build_fast2sms_payload(phones: list[str], message: str, api_key: str) -> dict[str, Any]:
    """[OPTIONAL/PAID] Assemble a Fast2SMS bulk request body (unicode route)."""
    return {
        "route": "q",  # quick transactional route supports unicode
        "message": message,
        "language": "unicode",
        "numbers": ",".join(phones),
        "authorization": api_key,
    }


def build_email(message_en: str, message_hi: str, severity: str) -> dict[str, str]:
    """[FREE PATH] Build the subject + bilingual plain-text body for an alert.

    Hindi first (primary language), English second, so the email is useful to
    farmers regardless of their reader.
    """
    subject = f"KrishiMitra Alert [{severity or 'INFO'}]"
    body = "\n\n".join(part for part in (message_hi, message_en) if part)
    return {"subject": subject, "body": body}
