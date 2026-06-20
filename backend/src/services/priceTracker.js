import { rows, one } from '../db/pool.js';
import { generateAlertForDistrict, SEVERITY } from './alerts.js';

// Port of db/plsql/pkg_price_tracker.pkb.
//   PR-01: price drops > 15% over 3 days -> MEDIUM "delay selling"
//   PR-02: price rises > 20% over 7 days -> LOW    "opportunity to sell"

export const DROP_PCT = 15;
export const RISE_PCT = 20;

// Latest price for a crop+mandi at or before (current_date - daysAgo).
export async function latestPrice(cropId, mandiName, daysAgo = 0) {
  const row = await one(
    `SELECT price_per_qtl
     FROM mandi_prices
     WHERE crop_id = $1 AND mandi_name = $2
       AND recorded_date <= current_date - ($3::int)
       AND price_per_qtl IS NOT NULL
     ORDER BY recorded_date DESC
     LIMIT 1`,
    [cropId, mandiName, daysAgo],
  );
  return row ? Number(row.price_per_qtl) : null;
}

async function cropNames(cropId) {
  const row = await one(
    `SELECT crop_name, COALESCE(crop_name_hindi, crop_name) AS crop_name_hi
     FROM crops WHERE crop_id = $1`,
    [cropId],
  );
  return { en: row ? row.crop_name : 'crop', hi: row ? row.crop_name_hi : 'फसल' };
}

// Evaluate drop/rise rules for one crop+mandi; fan alerts to the district.
// Returns the number of alerts generated.
export async function evaluatePriceMovement(cropId, mandiName, district) {
  const today = await latestPrice(cropId, mandiName, 0);
  if (today === null) return 0;

  const d3 = await latestPrice(cropId, mandiName, 3);
  const d7 = await latestPrice(cropId, mandiName, 7);
  const names = await cropNames(cropId);
  let alerts = 0;

  if (d3 !== null && d3 > 0) {
    const change = ((today - d3) / d3) * 100;
    if (change <= -DROP_PCT) {
      const pct = Math.round(Math.abs(change));
      alerts += await generateAlertForDistrict({
        alertType: 'PRICE_DROP',
        district,
        messageEn: `${names.en} price fell ${pct}% in 3 days at ${mandiName}. Consider delaying sale.`,
        messageHi: `${names.hi} का भाव ${mandiName} में 3 दिनों में ${pct}% गिरा. बिक्री टालने पर विचार करें.`,
        severity: SEVERITY.MEDIUM,
      });
    }
  }

  if (d7 !== null && d7 > 0) {
    const change = ((today - d7) / d7) * 100;
    if (change >= RISE_PCT) {
      const pct = Math.round(change);
      alerts += await generateAlertForDistrict({
        alertType: 'PRICE_RISE',
        district,
        messageEn: `${names.en} price rose ${pct}% in 7 days at ${mandiName}. Good time to sell.`,
        messageHi: `${names.hi} का भाव ${mandiName} में 7 दिनों में ${pct}% बढ़ा. बेचने का अच्छा समय.`,
        severity: SEVERITY.LOW,
      });
    }
  }
  return alerts;
}

// Insert a price observation, then evaluate movement (best-effort).
export async function recordPrice({
  cropId,
  mandiName,
  district,
  state,
  pricePerQtl,
  recordedDate = null,
  source = 'Agmarknet',
}) {
  const row = await one(
    `INSERT INTO mandi_prices (crop_id, mandi_name, district, state, price_per_qtl, recorded_date, source)
     VALUES ($1, $2, $3, $4, $5, COALESCE($6::date, current_date), $7)
     RETURNING price_id`,
    [cropId, mandiName, district, state, pricePerQtl, recordedDate, source],
  );
  try {
    await evaluatePriceMovement(cropId, mandiName, district);
  } catch {
    // never fail an ingest because alerting errored
  }
  return row.price_id;
}

// Latest price per crop+mandi (for GET /mandi-prices).
export async function latestPrices(cropId = null, mandi = null) {
  return rows(
    `SELECT mp.price_id, mp.crop_id, c.crop_name, c.crop_name_hindi,
            mp.mandi_name, mp.district, mp.state, mp.price_per_qtl, mp.recorded_date
     FROM mandi_prices mp
     JOIN crops c ON c.crop_id = mp.crop_id
     WHERE mp.recorded_date = (
       SELECT MAX(mp2.recorded_date) FROM mandi_prices mp2
       WHERE mp2.crop_id = mp.crop_id AND mp2.mandi_name = mp.mandi_name)
       AND ($1::bigint IS NULL OR mp.crop_id = $1)
       AND ($2::text IS NULL OR mp.mandi_name = $2)
     ORDER BY c.crop_name, mp.mandi_name`,
    [cropId, mandi],
  );
}

// Price history time series (for GET /mandi-prices/history).
export async function priceHistory(cropId = null, mandi = null, days = 90) {
  return rows(
    `SELECT crop_id, mandi_name, price_per_qtl, recorded_date
     FROM mandi_prices
     WHERE ($1::bigint IS NULL OR crop_id = $1)
       AND ($2::text IS NULL OR mandi_name = $2)
       AND recorded_date >= current_date - ($3::int)
     ORDER BY recorded_date`,
    [cropId, mandi, days],
  );
}

// Sweep all crop+mandi pairs and evaluate movement (price sweep job).
export async function sweepAllMovements() {
  const pairs = await rows(
    `SELECT DISTINCT crop_id, mandi_name, district FROM mandi_prices`,
  );
  let alerts = 0;
  for (const p of pairs) {
    // eslint-disable-next-line no-await-in-loop
    alerts += await evaluatePriceMovement(p.crop_id, p.mandi_name, p.district);
  }
  return alerts;
}
