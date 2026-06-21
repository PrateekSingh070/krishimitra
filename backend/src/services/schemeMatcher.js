import { rows, one, withTransaction } from '../db/pool.js';
import { generateAlert, SEVERITY, CHANNEL } from './alerts.js';

// Port of db/plsql/pkg_scheme_matcher.pkb.
// eligibility_json (jsonb) shape, all keys optional:
//   { "min_land":1, "max_land":5, "states":["UP"], "crops":["Wheat"], "max_income":200000 }

export const ALERT_THRESHOLD = 80; // score above which a farmer is auto-alerted

const STATE_ALIASES = {
  'UTTAR PRADESH': 'UP',
  UP: 'UP',
  'MADHYA PRADESH': 'MP',
  MP: 'MP',
  MAHARASHTRA: 'MAHARASHTRA',
  PUNJAB: 'PUNJAB',
  BIHAR: 'BIHAR',
  RAJASTHAN: 'RAJASTHAN',
};

function normalizeState(value) {
  const state = String(value || '').trim().toUpperCase();
  return STATE_ALIASES[state] || state;
}

// Score one farmer against one scheme's eligibility object (0-100).
// `farmer` = { land_acres, state }; `cropNames` = array of UPPER crop names.
export function scoreMatch(farmer, cropNames, eligibility) {
  if (!eligibility) return 0;

  let criteria = 0;
  let met = 0;
  const land = farmer.land_acres == null ? null : Number(farmer.land_acres);
  const state = normalizeState(farmer.state);

  if (eligibility.min_land != null) {
    criteria += 1;
    if (land != null && land >= Number(eligibility.min_land)) met += 1;
  }
  if (eligibility.max_land != null) {
    criteria += 1;
    if (land != null && land <= Number(eligibility.max_land)) met += 1;
  }
  if (Array.isArray(eligibility.states)) {
    criteria += 1;
    if (eligibility.states.some((s) => normalizeState(s) === state)) met += 1;
  }
  if (Array.isArray(eligibility.crops)) {
    criteria += 1;
    const want = eligibility.crops.map((c) => String(c).toUpperCase());
    if (cropNames.some((c) => want.includes(c))) met += 1;
  }
  // max_income: no income column; treat as an always-satisfied criterion
  // (parity with the original PL/SQL behaviour).
  if (eligibility.max_income != null) {
    criteria += 1;
    met += 1;
  }

  if (criteria === 0) return 0;
  return Math.round((met / criteria) * 100 * 100) / 100;
}

// Upsert a match row and, if it newly crosses the threshold, raise a SCHEME
// alert. Runs in a transaction so the alert + notified flag are atomic.
async function upsertMatch(client, farmerId, scheme, score) {
  const prev = await client.query(
    `SELECT match_score FROM scheme_matches
     WHERE farmer_id = $1 AND scheme_id = $2 FOR UPDATE`,
    [farmerId, scheme.scheme_id],
  );
  const existed = prev.rows.length > 0;
  const prevScore = existed ? Number(prev.rows[0].match_score) : 0;

  await client.query(
    `INSERT INTO scheme_matches (farmer_id, scheme_id, match_score, matched_at, notified)
     VALUES ($1, $2, $3, now(), 'N')
     ON CONFLICT (farmer_id, scheme_id)
     DO UPDATE SET match_score = EXCLUDED.match_score, matched_at = now()`,
    [farmerId, scheme.scheme_id, score],
  );

  // Alert only when the match newly crosses the threshold (avoid re-alerting).
  if (score > ALERT_THRESHOLD && (!existed || prevScore <= ALERT_THRESHOLD)) {
    await generateAlert({
      alertType: 'SCHEME',
      farmerId,
      messageEn: `You may be eligible for: ${scheme.scheme_name}. Apply via KrishiMitra.`,
      messageHi: `आप इस योजना के पात्र हो सकते हैं: ${scheme.scheme_name_hi || scheme.scheme_name}. कृषिमित्र पर आवेदन करें.`,
      severity: SEVERITY.LOW,
      channel: CHANNEL.EMAIL,
      client,
    });
    await client.query(
      `UPDATE scheme_matches SET notified = 'Y' WHERE farmer_id = $1 AND scheme_id = $2`,
      [farmerId, scheme.scheme_id],
    );
  }
}

// Match a single farmer against all active, non-expired schemes.
// Returns the number of matches upserted (score > 0).
export async function matchFarmer(farmerId) {
  const farmer = await one(
    `SELECT farmer_id, land_acres, state FROM farmers WHERE farmer_id = $1`,
    [farmerId],
  );
  if (!farmer) return 0;

  const cropRows = await rows(
    `SELECT UPPER(c.crop_name) AS name
     FROM farmer_crops fc JOIN crops c ON c.crop_id = fc.crop_id
     WHERE fc.farmer_id = $1 AND fc.status = 'ACTIVE'`,
    [farmerId],
  );
  const cropNames = cropRows.map((r) => r.name);

  const schemes = await rows(
    `SELECT scheme_id, scheme_name, scheme_name_hi, eligibility_json
     FROM government_schemes
     WHERE is_active = 'Y' AND (deadline IS NULL OR deadline >= current_date)`,
  );

  let count = 0;
  await withTransaction(async (client) => {
    for (const scheme of schemes) {
      const score = scoreMatch(farmer, cropNames, scheme.eligibility_json);
      if (score > 0) {
        // eslint-disable-next-line no-await-in-loop
        await upsertMatch(client, farmerId, scheme, score);
        count += 1;
      }
    }
  });
  return count;
}

// Match every active farmer (nightly job).
export async function matchAllFarmers() {
  const farmers = await rows(`SELECT farmer_id FROM farmers WHERE is_active = 'Y'`);
  let total = 0;
  for (const f of farmers) {
    // eslint-disable-next-line no-await-in-loop
    total += await matchFarmer(f.farmer_id);
  }
  return total;
}

// Active schemes (for GET /schemes).
export async function listActiveSchemes() {
  return rows(
    `SELECT scheme_id, scheme_name, scheme_name_hi, ministry,
            benefit_amount, apply_url, deadline
     FROM government_schemes WHERE is_active = 'Y'
     ORDER BY scheme_name`,
  );
}

// Ranked personalised matches for a farmer (for GET /schemes/farmer/:id).
export async function listFarmerMatches(farmerId) {
  return rows(
    `SELECT gs.scheme_id, gs.scheme_name, gs.scheme_name_hi, gs.ministry,
            gs.benefit_amount, gs.apply_url, gs.deadline,
            COALESCE(sm.match_score, 0) AS match_score
     FROM government_schemes gs
     LEFT JOIN scheme_matches sm
       ON sm.scheme_id = gs.scheme_id AND sm.farmer_id = $1
     WHERE gs.is_active = 'Y' AND (gs.deadline IS NULL OR gs.deadline >= current_date)
     ORDER BY COALESCE(sm.match_score, 0) DESC, gs.scheme_name`,
    [farmerId],
  );
}
