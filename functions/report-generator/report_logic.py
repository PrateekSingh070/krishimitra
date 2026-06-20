"""Pure helpers for the disease-scan PDF report generator."""
from __future__ import annotations

from typing import Any

SEVERITY_LABEL = {
    "LOW": "Low",
    "MEDIUM": "Medium",
    "HIGH": "High",
    "CRITICAL": "Critical",
}


def report_object_name(scan_id: int) -> str:
    """Deterministic Object Storage key for a scan's report."""
    return f"reports/scan_{int(scan_id)}.pdf"


def build_report_lines(scan: dict[str, Any]) -> list[str]:
    """Flatten a scan record into ordered, printable report lines."""
    severity = scan.get("severity") or scan.get("SEVERITY") or ""
    return [
        "KrishiMitra - Crop Disease Report",
        "",
        f"Scan ID: {scan.get('scan_id', scan.get('SCAN_ID', ''))}",
        f"Farmer ID: {scan.get('farmer_id', scan.get('FARMER_ID', ''))}",
        f"Disease: {scan.get('disease_detected', scan.get('DISEASE_DETECTED', ''))}",
        f"Severity: {SEVERITY_LABEL.get(severity, severity)}",
        f"Confidence: {scan.get('confidence_score', scan.get('CONFIDENCE_SCORE', ''))}%",
        "",
        "Treatment (English):",
        scan.get("treatment_advice", scan.get("TREATMENT_ADVICE", "")) or "-",
        "",
        "Treatment (Hindi):",
        scan.get("treatment_hindi", scan.get("TREATMENT_HINDI", "")) or "-",
    ]
