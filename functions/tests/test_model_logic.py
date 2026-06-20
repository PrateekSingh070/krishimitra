import pytest

import model_logic as ml


def test_parse_request_full_envelope():
    req = ml.parse_request({"model": "sowing", "instances": [{"crop": "Wheat"}]})
    assert req["model"] == "sowing"
    assert req["instances"] == [{"crop": "Wheat"}]


def test_parse_request_defaults_to_sowing_and_wraps_single():
    req = ml.parse_request({"crop": "Rice", "district": "Pune"})
    assert req["model"] == "sowing"
    assert req["instances"] == [{"crop": "Rice", "district": "Pune"}]


def test_parse_request_accepts_json_string():
    req = ml.parse_request('{"model": "price", "instances": [{"crop_id": 5}]}')
    assert req["model"] == "price"
    assert req["instances"][0]["crop_id"] == 5


def test_parse_request_rejects_unknown_model():
    with pytest.raises(ValueError):
        ml.parse_request({"model": "weather", "instances": [{}]})


def test_parse_request_rejects_empty_instances():
    with pytest.raises(ValueError):
        ml.parse_request({"model": "sowing", "instances": []})


def test_sowing_rows_orders_features_and_fills_missing():
    rows = ml.sowing_rows([{"crop": "Wheat", "district": "Pune", "sow_month": 11}])
    assert len(rows) == 1
    assert len(rows[0]) == len(ml.SOWING_FEATURES)
    assert rows[0][ml.SOWING_FEATURES.index("crop")] == "Wheat"
    assert rows[0][ml.SOWING_FEATURES.index("soil_type")] is None


def test_build_sowing_response_rounds():
    out = ml.build_sowing_response([12.3456, 9.0])
    assert out["prediction"] == [12.35, 9.0]
    assert out["unit"] == "qtl/acre"


def test_price_periods_default_and_clamp():
    assert ml.price_periods([{}]) == 30
    assert ml.price_periods([{"periods": 1000}]) == 365
    assert ml.price_periods([{"periods": 0}]) == 1
    assert ml.price_periods([{"periods": "bad"}]) == 30


def test_build_price_response_pairs_dates():
    out = ml.build_price_response(["2026-01-01", "2026-01-02"], [1000.5, 1010.25])
    assert out["model"] == "price"
    assert out["forecast"][0] == {"date": "2026-01-01", "price_per_qtl": 1000.5}
    assert out["unit"] == "INR/qtl"
