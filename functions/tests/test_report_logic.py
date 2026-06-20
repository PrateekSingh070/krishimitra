import report_logic as rl


def test_report_object_name():
    assert rl.report_object_name(15) == "reports/scan_15.pdf"


def test_build_report_lines_lowercase_keys():
    scan = {
        "scan_id": 9,
        "farmer_id": 42,
        "disease_detected": "Rice Blast",
        "severity": "CRITICAL",
        "confidence_score": 91.2,
        "treatment_advice": "Apply tricyclazole.",
        "treatment_hindi": "ट्राईसाइक्लाजोल लगाएं।",
    }
    lines = rl.build_report_lines(scan)
    assert "KrishiMitra - Crop Disease Report" in lines[0]
    assert any("Rice Blast" in l for l in lines)
    assert any("Critical" in l for l in lines)
    assert "ट्राईसाइक्लाजोल लगाएं।" in lines


def test_build_report_lines_uppercase_keys_from_ords():
    scan = {
        "SCAN_ID": 9,
        "FARMER_ID": 42,
        "DISEASE_DETECTED": "Wheat Leaf Rust",
        "SEVERITY": "HIGH",
        "CONFIDENCE_SCORE": 88,
        "TREATMENT_ADVICE": "Spray propiconazole.",
        "TREATMENT_HINDI": "-",
    }
    lines = rl.build_report_lines(scan)
    assert any("Wheat Leaf Rust" in l for l in lines)
    assert any("High" in l for l in lines)
