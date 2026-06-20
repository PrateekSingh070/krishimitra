import { config } from '../config/index.js';
import { logger } from '../config/logger.js';
import { one } from '../db/pool.js';
import { recordPrice } from '../services/priceTracker.js';

// Port of db/plsql/pkg_mandi_sync.pkb. Agmarknet via data.gov.in (free key).

async function cropIdFor(commodity) {
  const row = await one(
    `SELECT crop_id FROM crops WHERE UPPER(crop_name) = UPPER(TRIM($1)) LIMIT 1`,
    [commodity],
  );
  return row ? row.crop_id : null;
}

function parseDate(str) {
  // Agmarknet uses DD/MM/YYYY.
  if (!str) return null;
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(str.trim());
  return m ? `${m[3]}-${m[2]}-${m[1]}` : null;
}

async function syncPage(offset, limit) {
  const url =
    `${config.ingest.dataGovBaseUrl}/${config.ingest.agmarknetResourceId}` +
    `?api-key=${config.ingest.dataGovApiKey}&format=json&offset=${offset}&limit=${limit}`;
  const resp = await fetch(url);
  if (!resp.ok) return 0;
  const json = await resp.json();
  const records = json.records || [];

  let count = 0;
  for (const rec of records) {
    // eslint-disable-next-line no-await-in-loop
    const cid = await cropIdFor(rec.commodity);
    if (!cid) continue;
    const price = Number(rec.modal_price);
    if (Number.isNaN(price)) continue;
    // eslint-disable-next-line no-await-in-loop
    await recordPrice({
      cropId: cid,
      mandiName: rec.market,
      district: rec.district,
      state: rec.state,
      pricePerQtl: price,
      recordedDate: parseDate(rec.arrival_date),
      source: 'Agmarknet',
    });
    count += 1;
  }
  return count;
}

export async function runMandiSync(maxRecords = 1000) {
  if (!config.ingest.dataGovApiKey) {
    logger.warn('DATAGOV_API_KEY not set; skipping mandi sync');
    return 0;
  }
  const limit = 100;
  let offset = 0;
  let total = 0;
  while (offset < maxRecords) {
    // eslint-disable-next-line no-await-in-loop
    const got = await syncPage(offset, limit).catch((err) => {
      logger.warn({ err, offset }, 'mandiSync page failed');
      return 0;
    });
    total += got;
    if (got === 0) break;
    offset += limit;
  }
  logger.info({ rows: total }, 'Mandi sync complete');
  return total;
}
