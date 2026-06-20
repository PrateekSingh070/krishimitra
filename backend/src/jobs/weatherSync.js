import { config } from '../config/index.js';
import { logger } from '../config/logger.js';
import { rows, query } from '../db/pool.js';

// Port of db/plsql/pkg_weather_sync.pkb. Open-Meteo is keyless and free.

async function geocode(district) {
  const url =
    `${config.ingest.openMeteoGeocodeUrl}?name=${encodeURIComponent(district)}` +
    '&count=1&country=IN&language=en&format=json';
  const resp = await fetch(url);
  if (!resp.ok) return null;
  const json = await resp.json();
  const hit = json.results && json.results[0];
  return hit ? { lat: hit.latitude, lon: hit.longitude } : null;
}

async function syncDistrict(district, state) {
  const geo = await geocode(district);
  if (!geo) return 0;

  const url =
    `${config.ingest.openMeteoForecastUrl}?latitude=${geo.lat}&longitude=${geo.lon}` +
    '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation' +
    '&daily=precipitation_sum,temperature_2m_max,temperature_2m_min' +
    '&forecast_days=7&timezone=Asia%2FKolkata';
  const resp = await fetch(url);
  if (!resp.ok) return 0;
  const json = await resp.json();
  const cur = json.current || {};

  await query(
    `INSERT INTO weather_data (district, state, recorded_at, temp_celsius,
        humidity_pct, rainfall_mm, wind_speed_kmh, forecast_json, source)
     VALUES ($1, $2, now(), $3, $4, $5, $6, $7, 'OWM')`,
    [
      district,
      state,
      cur.temperature_2m ?? null,
      cur.relative_humidity_2m ?? null,
      cur.precipitation ?? null,
      cur.wind_speed_10m ?? null,
      json.daily ? JSON.stringify(json.daily) : null,
    ],
  );
  return 1;
}

export async function runWeatherSync() {
  const districts = await rows(
    `SELECT district, MAX(state) AS state
     FROM farmers
     WHERE is_active = 'Y' AND district IS NOT NULL
     GROUP BY district`,
  );
  let ok = 0;
  for (const d of districts) {
    try {
      // eslint-disable-next-line no-await-in-loop
      ok += await syncDistrict(d.district, d.state);
    } catch (err) {
      logger.warn({ err, district: d.district }, 'weatherSync district failed');
    }
  }
  logger.info({ districts: ok }, 'Weather sync complete');
  return ok;
}
