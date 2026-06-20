import { config } from '../config/index.js';
import { logger } from '../config/logger.js';
import { query } from '../db/pool.js';

// Port of db/plsql/pkg_scheme_sync.pkb. data.gov.in scheme resource (free key).
// The resource id is deployment-specific; if unset the job no-ops (the seeded
// schemes remain). Builds eligibility as jsonb from CSV/number columns.

function csvToArray(csv) {
  if (!csv) return null;
  const arr = String(csv)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return arr.length ? arr : null;
}

function buildEligibility(rec) {
  const e = {};
  const minLand = Number(rec.min_land_acres);
  const maxLand = Number(rec.max_land_acres);
  const maxIncome = Number(rec.max_income);
  const states = csvToArray(rec.states);
  const crops = csvToArray(rec.crops);
  if (!Number.isNaN(minLand) && rec.min_land_acres != null) e.min_land = minLand;
  if (!Number.isNaN(maxLand) && rec.max_land_acres != null) e.max_land = maxLand;
  if (states) e.states = states;
  if (crops) e.crops = crops;
  if (!Number.isNaN(maxIncome) && rec.max_income != null) e.max_income = maxIncome;
  return e;
}

export async function runSchemeSync() {
  if (!config.ingest.dataGovApiKey || !config.ingest.schemeResourceId) {
    logger.warn('DATAGOV_API_KEY / SCHEME_RESOURCE_ID not set; skipping scheme sync');
    return 0;
  }
  const url =
    `${config.ingest.dataGovBaseUrl}/${config.ingest.schemeResourceId}` +
    `?api-key=${config.ingest.dataGovApiKey}&format=json&limit=500`;
  const resp = await fetch(url);
  if (!resp.ok) {
    logger.warn({ status: resp.status }, 'scheme sync request failed');
    return 0;
  }
  const json = await resp.json();
  const records = json.records || [];

  let n = 0;
  for (const rec of records) {
    if (rec.status && String(rec.status).toUpperCase() !== 'ACTIVE') continue;
    const benefit = Number(rec.benefit_amount);
    const deadline = rec.deadline || null;
    // eslint-disable-next-line no-await-in-loop
    await query(
      `INSERT INTO government_schemes (scheme_name, scheme_name_hi, ministry,
          benefit_amount, eligibility_json, apply_url, deadline, is_active)
       VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7::date, 'Y')
       ON CONFLICT (scheme_name) DO UPDATE SET
          scheme_name_hi = EXCLUDED.scheme_name_hi,
          ministry = EXCLUDED.ministry,
          benefit_amount = EXCLUDED.benefit_amount,
          eligibility_json = EXCLUDED.eligibility_json,
          apply_url = EXCLUDED.apply_url,
          deadline = EXCLUDED.deadline,
          is_active = 'Y'`,
      [
        rec.scheme_name,
        rec.scheme_name_hi ?? null,
        rec.ministry ?? null,
        Number.isNaN(benefit) ? null : benefit,
        JSON.stringify(buildEligibility(rec)),
        rec.apply_url ?? null,
        deadline,
      ],
    );
    n += 1;
  }

  // Auto-deactivate expired schemes.
  await query(
    `UPDATE government_schemes SET is_active = 'N'
     WHERE deadline IS NOT NULL AND deadline < current_date AND is_active = 'Y'`,
  );

  logger.info({ schemes: n }, 'Scheme sync complete');
  return n;
}
