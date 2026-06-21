import { Router } from 'express';
import { asyncHandler, ApiError } from '../middleware/error.js';
import { one } from '../db/pool.js';
import { config } from '../config/index.js';

const router = Router();

function norm(value) {
  return String(value || '').trim().toLowerCase();
}

function parseDaily(value) {
  if (!value) return null;
  return typeof value === 'string' ? JSON.parse(value) : value;
}

async function geocodeDistrict(district, state) {
  const geoUrl =
    `${config.ingest.openMeteoGeocodeUrl}?name=${encodeURIComponent(district)}` +
    '&count=10&country=IN&language=en&format=json';
  const geoResp = await fetch(geoUrl);
  if (!geoResp.ok) return null;

  const geoJson = await geoResp.json();
  const hits = (geoJson.results || []).filter((hit) => hit.country_code === 'IN');
  if (hits.length === 0) return null;

  const stateNorm = norm(state);
  if (stateNorm) {
    const exactStateHit = hits.find((hit) => norm(hit.admin1) === stateNorm);
    if (exactStateHit) return exactStateHit;
    return null;
  }

  return hits[0];
}

async function fetchForecast(hit) {
  const fcUrl =
    `${config.ingest.openMeteoForecastUrl}?latitude=${hit.latitude}&longitude=${hit.longitude}` +
    '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,weather_code' +
    '&daily=precipitation_sum,temperature_2m_max,temperature_2m_min,weather_code' +
    '&forecast_days=7&timezone=Asia%2FKolkata';
  const fcResp = await fetch(fcUrl);
  if (!fcResp.ok) throw new ApiError(502, 'Weather provider is temporarily unavailable');

  const fcJson = await fcResp.json();
  const cur = fcJson.current || {};
  const daily = fcJson.daily || null;
  if (daily?.weather_code && !daily.weathercode) {
    daily.weathercode = daily.weather_code;
  }

  return {
    current: {
      temp_celsius: cur.temperature_2m ?? null,
      humidity_pct: cur.relative_humidity_2m ?? null,
      rainfall_mm: cur.precipitation ?? null,
      wind_speed_kmh: cur.wind_speed_10m ?? null,
      weather_code: cur.weather_code ?? null,
    },
    daily,
  };
}

// GET /weather?district=Pune&state=Maharashtra
// Returns latest weather + 7-day forecast for a district.
// Falls back to live Open-Meteo fetch if no DB record exists.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const district = String(req.query.district || '').trim();
    const state = String(req.query.state || '').trim();
    if (!district) throw new ApiError(400, 'district query param is required');

    // Try DB first (populated by cron job).
    const row = await one(
      `SELECT temp_celsius, humidity_pct, rainfall_mm, wind_speed_kmh,
              forecast_json, recorded_at
       FROM weather_data
       WHERE lower(district) = lower($1)
         AND ($2 = '' OR state IS NULL OR lower(state) = lower($2))
       ORDER BY recorded_at DESC
       LIMIT 1`,
      [district, state],
    );

    const cachedDaily = parseDaily(row?.forecast_json);
    // Old cached rows may not include weathercode, which makes the UI show
    // incorrect sunny/default icons. Fetch live in that case.
    if (row && cachedDaily?.weathercode) {
      return res.json({
        source: 'cache',
        district,
        state: state || null,
        recorded_at: row.recorded_at,
        current: {
          temp_celsius: row.temp_celsius,
          humidity_pct: row.humidity_pct,
          rainfall_mm: row.rainfall_mm,
          wind_speed_kmh: row.wind_speed_kmh,
        },
        daily: cachedDaily,
      });
    }

    // Live fetch from Open-Meteo (keyless, free).
    const hit = await geocodeDistrict(district, state);
    if (!hit) throw new ApiError(404, `District "${district}" not found in geocoding database`);
    const forecast = await fetchForecast(hit);

    res.json({
      source: 'live',
      district: hit.name || district,
      state: hit.admin1 || state || null,
      recorded_at: new Date().toISOString(),
      current: forecast.current,
      daily: forecast.daily,
    });
  }),
);

export default router;
