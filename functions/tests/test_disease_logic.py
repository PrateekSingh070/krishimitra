import disease_logic as dl


def test_select_top_label_picks_highest_confidence():
    labels = [
        {"name": "Tomato___healthy", "confidence": 0.10},
        {"name": "Tomato___Late_blight", "confidence": 0.82},
        {"name": "Potato___Early_blight", "confidence": 0.31},
    ]
    top = dl.select_top_label(labels)
    assert top["name"] == "Tomato___Late_blight"


def test_select_top_label_empty():
    assert dl.select_top_label([]) is None


def test_map_known_label():
    rec = dl.map_label_to_disease("Rice___Blast")
    assert rec["disease"] == "Rice Blast"
    assert rec["severity"] == "CRITICAL"
    # Free path: known labels carry a pre-translated Hindi treatment.
    assert rec["treatment_hi"]


def test_softmax_sums_to_one():
    probs = dl.softmax([2.0, 1.0, 0.1])
    assert abs(sum(probs) - 1.0) < 1e-6
    assert probs[0] == max(probs)


def test_softmax_empty():
    assert dl.softmax([]) == []


def test_decode_predictions_sorted_and_named():
    # Highest score is index 4 -> "Rice___Blast".
    scores = [0.1, 0.2, 0.05, 0.05, 5.0, 0.1]
    labels = dl.decode_predictions(scores)
    assert labels[0]["name"] == "Rice___Blast"
    assert labels[0]["confidence"] >= labels[1]["confidence"]
    assert abs(sum(l["confidence"] for l in labels) - 1.0) < 1e-6


def test_decode_predictions_custom_labels():
    labels = dl.decode_predictions([0.0, 9.0], class_labels=["a", "b"])
    assert labels[0]["name"] == "b"


def test_map_unknown_label_is_medium_and_prettified():
    rec = dl.map_label_to_disease("Mango___Some_New_Thing")
    assert rec["severity"] == "MEDIUM"
    assert rec["disease"] == "Mango Some New Thing"


def test_build_scan_payload_scales_fractional_confidence():
    payload = dl.build_scan_payload(
        farmer_id=42,
        image_url="https://x/o.jpg",
        label_name="Tomato___Late_blight",
        confidence=0.82,
        treatment_hindi="HI",  # explicit override still wins
        vision_request_id="req-1",
    )
    assert payload["farmer_id"] == 42
    assert payload["confidence_score"] == 82.0
    assert payload["severity"] == "HIGH"
    assert payload["treatment_hindi"] == "HI"


def test_build_scan_payload_uses_pretranslated_hindi():
    # Free path: with no override, Hindi advice comes from the lookup's
    # pre-translated treatment_hi (NOT a copy of the English text).
    payload = dl.build_scan_payload(
        farmer_id=1,
        image_url="https://x/o.jpg",
        label_name="Tomato___healthy",
        confidence=95.5,
    )
    assert payload["confidence_score"] == 95.5
    assert payload["treatment_hindi"] == dl.DEFAULT_LOOKUP["Tomato___healthy"]["treatment_hi"]
    assert payload["treatment_hindi"] != payload["treatment_advice"]


def test_farmer_id_from_object_name():
    assert dl.farmer_id_from_object_name("disease-scans/1042/abc.jpg") == 1042
    assert dl.farmer_id_from_object_name("disease-scans/no-id.jpg") is None


def test_parse_object_event():
    event = {
        "data": {
            "resourceName": "disease-scans/7/x.jpg",
            "additionalDetails": {"namespace": "ns1", "bucketName": "b1"},
        }
    }
    ref = dl.parse_object_event(event)
    assert ref == {"namespace": "ns1", "bucket": "b1", "object": "disease-scans/7/x.jpg"}
