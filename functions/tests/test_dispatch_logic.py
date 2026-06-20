import dispatch_logic as dol


def test_render_known_rule_fills_placeholders():
    r = dol.render_messages("WR-01", {"district": "Lucknow"})
    assert "Lucknow" in r["en"]
    assert "Lucknow" in r["hi"]
    assert r["severity"] == "HIGH"
    assert r["type"] == "WEATHER"


def test_render_price_rule():
    r = dol.render_messages("PR-01", {"crop": "Wheat", "mandi": "Azadpur"})
    assert "Wheat" in r["en"] and "Azadpur" in r["en"]
    assert r["type"] == "PRICE_DROP"


def test_render_unknown_rule_returns_none():
    assert dol.render_messages("ZZ-99", {}) is None


def test_chunk_respects_batch_size():
    items = list(range(0, 2500))
    batches = list(dol.chunk(items, 1000))
    assert [len(b) for b in batches] == [1000, 1000, 500]


def test_chunk_min_size_one():
    assert list(dol.chunk([1, 2], 0)) == [[1], [2]]


def test_parse_stream_message_accepts_json_and_dict():
    assert dol.parse_stream_message('{"a": 1}') == {"a": 1}
    assert dol.parse_stream_message({"a": 1}) == {"a": 1}
    assert dol.parse_stream_message(b'{"a": 2}') == {"a": 2}


def test_build_fast2sms_payload():
    p = dol.build_fast2sms_payload(["9111111111", "9222222222"], "नमस्ते", "KEY")
    assert p["numbers"] == "9111111111,9222222222"
    assert p["language"] == "unicode"
    assert p["authorization"] == "KEY"


def test_build_email_hindi_first_with_severity():
    mail = dol.build_email("English text", "हिंदी पाठ", "HIGH")
    assert mail["subject"] == "KrishiMitra Alert [HIGH]"
    # Hindi (primary) appears before English in the body.
    assert mail["body"].index("हिंदी पाठ") < mail["body"].index("English text")


def test_build_email_skips_empty_parts_and_defaults_severity():
    mail = dol.build_email("Only English", "", None)
    assert mail["subject"] == "KrishiMitra Alert [INFO]"
    assert mail["body"] == "Only English"
