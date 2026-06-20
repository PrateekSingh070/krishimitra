"""Make each function's modules importable in tests without packaging."""
import os
import sys

_HERE = os.path.dirname(__file__)
_FUNCTIONS_ROOT = os.path.abspath(os.path.join(_HERE, ".."))

for _fn in ("disease-classifier", "alert-dispatcher", "report-generator", "model-server"):
    sys.path.insert(0, os.path.join(_FUNCTIONS_ROOT, _fn))
