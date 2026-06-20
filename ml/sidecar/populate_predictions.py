"""Populate the `ml_predictions` table from trained models (DEFAULT path).

This is the free, all-Node-friendly approach: run this once after training to
write yield/price/sowing predictions into Postgres, then the Node API serves
them directly from `ml_predictions` (no live Python needed at request time).

Usage:
    pip install psycopg2-binary
    export DATABASE_URL=postgresql://...supabase...
    python populate_predictions.py
"""
from __future__ import annotations

import os
from datetime import date

import psycopg2

DATABASE_URL = os.environ["DATABASE_URL"]


def upsert_prediction(cur, farmer_crop_id, model_type, value, unit, conf, version):
    cur.execute(
        """
        INSERT INTO ml_predictions (farmer_crop_id, model_type, predicted_value,
            unit, confidence_pct, prediction_date, model_version)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (farmer_crop_id, model_type, value, unit, conf, date.today(), version),
    )


def main() -> None:
    conn = psycopg2.connect(DATABASE_URL)
    try:
        with conn, conn.cursor() as cur:
            # Example: write a placeholder YIELD prediction for each active crop.
            # Replace the constant with your trained model's output.
            cur.execute(
                "SELECT farmer_crop_id, crop_id FROM farmer_crops WHERE status = 'ACTIVE'"
            )
            for farmer_crop_id, _crop_id in cur.fetchall():
                upsert_prediction(
                    cur, farmer_crop_id, "YIELD", 18.5, "qtl/acre", 72.0, "v1"
                )
        print("ml_predictions populated.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
